"""Módulo de propuestas: envíos con media y moderación administrativa.

Las propuestas no se publican hasta que las apruebe un administrador.
Los archivos no se exponen directamente mediante Flask; se sirven con autorización.
"""
from __future__ import annotations

import os
from pathlib import Path
from uuid import uuid4

import mysql.connector
from flask import Blueprint, current_app, g, jsonify, request, send_file

from database import DatabaseManager
from errors import ApiError
from security import token_requerido

propuestas_bp = Blueprint('propuestas', __name__)
BASE_UPLOADS = Path(__file__).resolve().parent / 'uploads' / 'propuestas'
MAX_MEDIA = 25 * 1024 * 1024
EXTENSIONES = {'.jpg': 'imagen', '.jpeg': 'imagen', '.png': 'imagen',
               '.webp': 'imagen', '.mp4': 'video', '.webm': 'video'}
MIMES = {'.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png',
         '.webp': 'image/webp', '.mp4': 'video/mp4', '.webm': 'video/webm'}


def _valida_cabecera(extension, inicio):
    if extension in ('.jpg', '.jpeg'):
        return inicio.startswith(b'\xff\xd8\xff')
    if extension == '.png':
        return inicio.startswith(b'\x89PNG\r\n\x1a\n')
    if extension == '.webp':
        return inicio[:4] == b'RIFF' and inicio[8:12] == b'WEBP'
    if extension == '.mp4':
        return b'ftyp' in inicio[4:16]
    if extension == '.webm':
        return inicio.startswith(b'\x1a\x45\xdf\xa3')
    return False


def _db():
    return DatabaseManager.get_instance().get_connection()


def _publica(registro):
    if registro is None:
        return None
    if hasattr(registro.get('fecha_envio'), 'isoformat'):
        registro['fecha_envio'] = registro['fecha_envio'].isoformat()
    if hasattr(registro.get('fecha_revision'), 'isoformat'):
        registro['fecha_revision'] = registro['fecha_revision'].isoformat()
    registro.pop('nombre_archivo', None)
    return registro


def _consulta_propuestas(condicion, params):
    conn = _db()
    cur = conn.cursor(dictionary=True)
    try:
        cur.execute('''
          SELECT p.id_propuesta, p.id_usuario, p.id_grupo, p.nombre,
                 p.descripcion, p.tipo_media, p.estado, p.id_ejercicio,
                 p.fecha_envio, p.fecha_revision,
                 g.nombre AS grupo_muscular,
                 CONCAT(u.nombre, ' ', u.apellido) AS autor
          FROM propuestas_ejercicios p
          JOIN usuarios u ON p.id_usuario = u.id_usuario
          JOIN grupos_musculares g ON g.id_grupo = p.id_grupo
          WHERE ''' + condicion + ''' ORDER BY p.fecha_envio DESC
          LIMIT 100''', params)
        return [_publica(r) for r in cur.fetchall()]
    finally:
        cur.close()
        conn.close()


def _leer_propuesta(id_propuesta):
    conn = _db()
    cur = conn.cursor(dictionary=True)
    try:
        cur.execute('SELECT * FROM propuestas_ejercicios WHERE id_propuesta=%s', (id_propuesta,))
        return cur.fetchone()
    finally:
        cur.close()
        conn.close()


@propuestas_bp.route('/api/propuestas', methods=['POST'])
@token_requerido
def enviar_propuesta():
    nombre = (request.form.get('nombre') or '').strip()
    descripcion = (request.form.get('descripcion') or '').strip()
    try:
        grupo = int(request.form.get('id_grupo') or 0)
    except ValueError:
        grupo = 0
    if not 3 <= len(nombre) <= 100:
        raise ApiError('Escribe un nombre de entre 3 y 100 caracteres.', 400)
    if not 15 <= len(descripcion) <= 1500:
        raise ApiError('La descripción debe tener de 15 a 1500 caracteres.', 400)
    if grupo not in range(1, 10):
        raise ApiError('Selecciona un grupo muscular válido.', 400)
    archivo = request.files.get('archivo')
    if not archivo or not archivo.filename:
        raise ApiError('Adjunta una fotografía o un video del ejercicio.', 400)
    extension = Path(archivo.filename).suffix.lower()
    if extension not in EXTENSIONES:
        raise ApiError('Formato no admitido. Usa JPG, PNG, WEBP, MP4 o WEBM.', 400)
    # Leer hasta max + 1 evita guardar archivos de tamaño no permitido.
    contenido = archivo.stream.read(MAX_MEDIA + 1)
    if not contenido or len(contenido) > MAX_MEDIA:
        raise ApiError('El archivo debe pesar como máximo 25 MB.', 413)
    if not _valida_cabecera(extension, contenido[:24]):
        raise ApiError('El contenido del archivo no coincide con su formato.', 400)

    conn = _db()
    cur = conn.cursor()
    ruta = None
    try:
        cur.execute('''SELECT COUNT(*) FROM propuestas_ejercicios
                       WHERE id_usuario=%s AND estado='PENDIENTE' ''', (g.id_usuario,))
        if cur.fetchone()[0] >= 5:
            raise ApiError('Tienes cinco propuestas pendientes. Espera su revisión.', 409)
        cur.execute('SELECT COUNT(*) FROM ejercicios WHERE LOWER(nombre)=LOWER(%s)', (nombre,))
        if cur.fetchone()[0]:
            raise ApiError('Ese ejercicio ya existe en el catálogo.', 409)
        BASE_UPLOADS.mkdir(parents=True, exist_ok=True)
        nombre_archivo = uuid4().hex + extension
        ruta = BASE_UPLOADS / nombre_archivo
        # Escritura exclusiva en directorio controlado, sin nombres de usuario.
        with ruta.open('xb') as salida:
            salida.write(contenido)
        cur.execute('''INSERT INTO propuestas_ejercicios
                       (id_usuario, id_grupo, nombre, descripcion, nombre_archivo, tipo_media)
                       VALUES (%s,%s,%s,%s,%s,%s)''',
                    (g.id_usuario, grupo, nombre, descripcion, nombre_archivo,
                     EXTENSIONES[extension]))
        nuevo_id = cur.lastrowid
        conn.commit()
        return jsonify({'id_propuesta': nuevo_id, 'mensaje': 'Propuesta enviada. Está pendiente de revisión.'}), 201
    except Exception:
        conn.rollback()
        if ruta is not None:
            ruta.unlink(missing_ok=True)
        raise
    finally:
        cur.close()
        conn.close()


@propuestas_bp.route('/api/propuestas/mias', methods=['GET'])
@token_requerido
def mis_propuestas():
    return jsonify({'propuestas': _consulta_propuestas('p.id_usuario=%s', (g.id_usuario,))})


@propuestas_bp.route('/api/propuestas/pendientes', methods=['GET'])
@token_requerido
def pendientes():
    if g.id_rol != 1:
        raise ApiError('Solo los administradores pueden revisar propuestas.', 403)
    return jsonify({'propuestas': _consulta_propuestas("p.estado='PENDIENTE'", ())})


@propuestas_bp.route('/api/propuestas/<int:id_propuesta>/archivo', methods=['GET'])
@token_requerido
def ver_archivo(id_propuesta):
    propuesta = _leer_propuesta(id_propuesta)
    if not propuesta:
        raise ApiError('Propuesta no encontrada.', 404)
    if g.id_rol != 1 and g.id_usuario != propuesta['id_usuario'] and propuesta['estado'] != 'APROBADA':
        raise ApiError('No tienes permiso para ver este archivo.', 403)
    path = BASE_UPLOADS / Path(propuesta['nombre_archivo']).name
    if not path.is_file():
        raise ApiError('El archivo ya no está disponible.', 404)
    return send_file(path, mimetype=MIMES.get(path.suffix.lower(), 'application/octet-stream'),
                     as_attachment=False, conditional=True)


@propuestas_bp.route('/api/propuestas/<int:id_propuesta>/archivo-publico', methods=['GET'])
def ver_archivo_publico(id_propuesta):
    propuesta = _leer_propuesta(id_propuesta)
    if not propuesta or propuesta['estado'] != 'APROBADA':
        raise ApiError('No hay un archivo público para este ejercicio.', 404)
    path = BASE_UPLOADS / Path(propuesta['nombre_archivo']).name
    if not path.is_file():
        raise ApiError('El archivo ya no está disponible.', 404)
    return send_file(path, mimetype=MIMES.get(path.suffix.lower(), 'application/octet-stream'),
                     as_attachment=False, conditional=True)


@propuestas_bp.route('/api/propuestas/medios-aprobados', methods=['GET'])
@token_requerido
def medios_aprobados():
    conn = _db()
    cur = conn.cursor(dictionary=True)
    try:
        cur.execute('''SELECT id_ejercicio, id_propuesta, tipo_media
                       FROM propuestas_ejercicios
                       WHERE estado='APROBADA' AND id_ejercicio IS NOT NULL''')
        return jsonify({'medios': cur.fetchall()})
    finally:
        cur.close()
        conn.close()


@propuestas_bp.route('/api/propuestas/<int:id_propuesta>/revision', methods=['PATCH'])
@token_requerido
def revisar_propuesta(id_propuesta):
    if g.id_rol != 1:
        raise ApiError('Solo los administradores pueden aprobar o rechazar.', 403)
    decision = (request.get_json(silent=True) or {}).get('decision')
    if decision not in ('APROBADA', 'RECHAZADA'):
        raise ApiError('La decisión debe ser APROBADA o RECHAZADA.', 400)
    conn = _db()
    cur = conn.cursor(dictionary=True)
    try:
        conn.start_transaction()
        cur.execute('SELECT * FROM propuestas_ejercicios WHERE id_propuesta=%s FOR UPDATE', (id_propuesta,))
        propuesta = cur.fetchone()
        if not propuesta:
            raise ApiError('Propuesta no encontrada.', 404)
        if propuesta['estado'] != 'PENDIENTE':
            raise ApiError('Esta propuesta ya fue revisada.', 409)
        id_ejercicio = None
        if decision == 'APROBADA':
            cur.execute('''INSERT INTO ejercicios (id_grupo, nombre, descripcion)
                           VALUES (%s,%s,%s)''',
                        (propuesta['id_grupo'], propuesta['nombre'], propuesta['descripcion'][:255]))
            id_ejercicio = cur.lastrowid
        cur.execute('''UPDATE propuestas_ejercicios
                       SET estado=%s, id_revisor=%s, id_ejercicio=%s,
                           fecha_revision=NOW()
                       WHERE id_propuesta=%s''',
                    (decision, g.id_usuario, id_ejercicio, id_propuesta))
        cur.execute('''INSERT INTO notificaciones (id_usuario,tipo,titulo,mensaje)
                       VALUES (%s,'PROPUESTA',%s,%s)''',
                    (propuesta['id_usuario'],
                     'Propuesta ' + ('aprobada' if decision == 'APROBADA' else 'rechazada'),
                     'Tu ejercicio «' + propuesta['nombre'][:85] + '» fue ' +
                     ('aprobado y añadido al catálogo.' if decision == 'APROBADA' else 'rechazado.')))
        conn.commit()
        return jsonify({'mensaje': 'Propuesta revisada.', 'estado': decision,
                        'id_ejercicio': id_ejercicio})
    except mysql.connector.IntegrityError:
        conn.rollback()
        raise ApiError('No se pudo aprobar: ya existe un ejercicio con ese nombre.', 409)
    except Exception:
        conn.rollback()
        raise
    finally:
        cur.close()
        conn.close()
