"""IRONHUB 3.1: perfil, entrenamientos, alertas y administración.

API separada para mantener intactos los controladores de rutinas 2.0.
Los endpoints siempre usan la identidad validada del token, no IDs recibidos.
"""
from datetime import date, datetime
from decimal import Decimal
import re
import secrets

import mysql.connector
from flask import Blueprint, g, jsonify, request
from werkzeug.security import check_password_hash, generate_password_hash

from database import DatabaseManager
from errors import ApiError
from security import token_requerido

extras_bp = Blueprint('extras', __name__)


def _db():
    return DatabaseManager.get_instance().get_connection()


def _body():
    value = request.get_json(silent=True)
    if not isinstance(value, dict):
        raise ApiError('Envía los datos en formato JSON.', 400)
    return value


def _admin():
    if int(g.id_rol) != 1:
        raise ApiError('Esta acción requiere permisos de administrador.', 403)


def _text(value, label, min_len, max_len):
    if not isinstance(value, str):
        raise ApiError(f'{label} debe ser texto.', 400)
    value = value.strip()
    if not min_len <= len(value) <= max_len:
        raise ApiError(f'{label} debe tener entre {min_len} y {max_len} caracteres.', 400)
    return value


def _integer(value, label, minimum=1, maximum=999):
    if isinstance(value, bool):
        raise ApiError(f'{label} debe ser un entero.', 400)
    try:
        n = int(value)
    except (ValueError, TypeError):
        raise ApiError(f'{label} debe ser un entero.', 400)
    if isinstance(value, float) and not value.is_integer():
        raise ApiError(f'{label} debe ser un entero.', 400)
    if not minimum <= n <= maximum:
        raise ApiError(f'{label} debe estar entre {minimum} y {maximum}.', 400)
    return n


def _fecha(value):
    if isinstance(value, (date, datetime)):
        return value.isoformat()
    return value


@extras_bp.route('/api/mi-perfil', methods=['GET'])
@token_requerido
def obtener_perfil():
    cn = _db(); cur = cn.cursor(dictionary=True)
    try:
        cur.execute('''SELECT id_usuario,nombre,apellido,email,telefono,fecha_registro
                       FROM usuarios WHERE id_usuario=%s''', (g.id_usuario,))
        data = cur.fetchone()
        if not data: raise ApiError('Usuario no encontrado.', 404)
        data['fecha_registro'] = _fecha(data['fecha_registro'])
        return jsonify({'perfil': data})
    finally: cur.close(); cn.close()


@extras_bp.route('/api/mi-perfil', methods=['PUT'])
@token_requerido
def editar_perfil():
    data = _body()
    nombre = _text(data.get('nombre'), 'Nombre', 2, 60)
    apellido = _text(data.get('apellido'), 'Apellido', 2, 60)
    email = _text(data.get('email'), 'Correo', 5, 120).lower()
    telefono = _text(data.get('telefono') or '', 'Teléfono', 0, 20)
    if not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', email):
        raise ApiError('Correo electrónico no válido.', 400)
    cn = _db(); cur = cn.cursor()
    try:
        cur.execute('''UPDATE usuarios SET nombre=%s, apellido=%s, email=%s, telefono=%s
                       WHERE id_usuario=%s''', (nombre, apellido, email, telefono, g.id_usuario))
        cn.commit()
    except mysql.connector.IntegrityError:
        cn.rollback(); raise ApiError('Ya existe una cuenta con ese correo.', 409)
    finally: cur.close(); cn.close()
    return jsonify({'mensaje': 'Perfil actualizado correctamente.',
                    'perfil': {'nombre':nombre, 'apellido':apellido, 'email':email, 'telefono':telefono}})


@extras_bp.route('/api/mi-perfil/clave', methods=['PUT'])
@token_requerido
def cambiar_clave():
    data = _body()
    anterior = data.get('actual')
    nueva = data.get('nueva')
    if not isinstance(anterior, str) or not isinstance(nueva, str):
        raise ApiError('Completa ambas contraseñas.', 400)
    if not 8 <= len(nueva) <= 128:
        raise ApiError('La nueva contraseña debe contener entre 8 y 128 caracteres.', 400)
    if secrets.compare_digest(anterior, nueva):
        raise ApiError('La nueva contraseña debe ser diferente de la anterior.', 400)
    cn = _db(); cur = cn.cursor(dictionary=True)
    try:
        cur.execute('SELECT password_hash FROM usuarios WHERE id_usuario=%s FOR UPDATE', (g.id_usuario,))
        row = cur.fetchone()
        if not row: raise ApiError('Usuario no encontrado.',404)
        stored = row['password_hash'] or ''
        valid = (check_password_hash(stored, anterior) if stored.startswith(('scrypt:', 'pbkdf2:'))
                 else secrets.compare_digest(stored, anterior))
        if not valid: raise ApiError('La contraseña actual no coincide.', 403)
        cur.execute('UPDATE usuarios SET password_hash=%s WHERE id_usuario=%s',
                    (generate_password_hash(nueva), g.id_usuario))
        cn.commit()
    except Exception:
        cn.rollback(); raise
    finally: cur.close(); cn.close()
    return jsonify({'mensaje': 'Contraseña actualizada. Vuelve a iniciar sesión en tus otros dispositivos.'})


@extras_bp.route('/api/entrenamientos', methods=['POST'])
@token_requerido
def guardar_entrenamiento():
    data = _body()
    dia = _integer(data.get('dia_semana'), 'Día de entrenamiento', 1, 7)
    notas = _text(data.get('notas') or '', 'Notas', 0, 255)
    ejercicios = data.get('ejercicios')
    if not isinstance(ejercicios, list) or not 1 <= len(ejercicios) <= 30:
        raise ApiError('Debes registrar entre 1 y 30 ejercicios.', 400)
    filas = []
    vistos = set()
    for row in ejercicios:
        if not isinstance(row, dict): raise ApiError('Ejercicio no válido.', 400)
        ejercicio = _integer(row.get('id_ejercicio'), 'Ejercicio')
        if ejercicio in vistos: raise ApiError('No se pueden repetir ejercicios.', 400)
        vistos.add(ejercicio)
        series = _integer(row.get('series'), 'Series', 1, 99)
        repeticiones = _integer(row.get('repeticiones'), 'Repeticiones', 1, 999)
        peso = row.get('peso_kg')
        if peso in (None, ''):
            peso = None
        else:
            try: peso = Decimal(str(peso))
            except Exception: raise ApiError('El peso debe ser numérico.', 400)
            if not peso.is_finite() or not 0 <= peso <= 99999:
                raise ApiError('El peso debe estar entre 0 y 99999 kg.', 400)
            peso = peso.quantize(Decimal('0.01'))
        filas.append((ejercicio, series, repeticiones, peso))
    cn = _db(); cur = cn.cursor()
    try:
        ids = [f[0] for f in filas]
        placeholders = ','.join(['%s'] * len(ids))
        cur.execute(f'SELECT COUNT(*) FROM ejercicios WHERE id_ejercicio IN ({placeholders})', tuple(ids))
        if cur.fetchone()[0] != len(ids):
            raise ApiError('Uno de los ejercicios ya no existe.', 400)
        cur.execute('INSERT INTO sesiones_entrenamiento (id_usuario,dia_semana,notas) VALUES (%s,%s,%s)',
                    (g.id_usuario, dia, notas))
        sesion = cur.lastrowid
        cur.executemany('''INSERT INTO series_entrenamiento
            (id_sesion,id_ejercicio,series,repeticiones,peso_kg) VALUES (%s,%s,%s,%s,%s)''',
                        [(sesion, *fila) for fila in filas])
        cn.commit()
    except Exception:
        cn.rollback(); raise
    finally: cur.close(); cn.close()
    return jsonify({'id_sesion': sesion,'mensaje': 'Entrenamiento registrado correctamente.'}), 201


@extras_bp.route('/api/entrenamientos/mios', methods=['GET'])
@token_requerido
def mis_entrenamientos():
    cn = _db(); cur = cn.cursor(dictionary=True)
    try:
        cur.execute('''SELECT id_sesion, fecha_hora, dia_semana, notas
                       FROM sesiones_entrenamiento WHERE id_usuario=%s
                       ORDER BY fecha_hora DESC, id_sesion DESC LIMIT 30''', (g.id_usuario,))
        sesiones = cur.fetchall()
        for s in sesiones:
            s['fecha_hora'] = _fecha(s['fecha_hora'])
        if sesiones:
            ids = [s['id_sesion'] for s in sesiones]
            placeholders = ','.join(['%s']*len(ids))
            cur.execute(f'''SELECT se.id_sesion,e.nombre,se.series,se.repeticiones,se.peso_kg
                FROM series_entrenamiento se JOIN ejercicios e ON e.id_ejercicio=se.id_ejercicio
                WHERE se.id_sesion IN ({placeholders}) ORDER BY se.id_serie''', tuple(ids))
            grupos = {i:[] for i in ids}
            for row in cur.fetchall():
                if row['peso_kg'] is not None: row['peso_kg'] = float(row['peso_kg'])
                grupos[row['id_sesion']].append(row)
            for s in sesiones: s['ejercicios'] = grupos[s['id_sesion']]
        cur.execute('''SELECT COUNT(*) AS total,
                       SUM(CASE WHEN YEARWEEK(fecha_hora,3)=YEARWEEK(CURRENT_DATE(),3)
                           THEN 1 ELSE 0 END) AS semana
                       FROM sesiones_entrenamiento WHERE id_usuario=%s''', (g.id_usuario,))
        resumen = cur.fetchone()
        return jsonify({'sesiones':sesiones, 'total':resumen['total'],
                        'semana':int(resumen['semana'] or 0)})
    finally: cur.close(); cn.close()


@extras_bp.route('/api/notificaciones', methods=['GET'])
@token_requerido
def mis_notificaciones():
    cn = _db(); cur = cn.cursor(dictionary=True)
    try:
        cur.execute('''SELECT id_notificacion,tipo,titulo,mensaje,leida,fecha_creacion
                       FROM notificaciones WHERE id_usuario=%s
                       ORDER BY fecha_creacion DESC,id_notificacion DESC LIMIT 50''', (g.id_usuario,))
        avisos=cur.fetchall()
        for a in avisos: a['fecha_creacion']=_fecha(a['fecha_creacion'])
        cur.execute('SELECT COUNT(*) AS total FROM notificaciones WHERE id_usuario=%s AND leida=0', (g.id_usuario,))
        return jsonify({'notificaciones':avisos,'sin_leer':cur.fetchone()['total']})
    finally: cur.close(); cn.close()


@extras_bp.route('/api/notificaciones/<int:id_notificacion>/leida', methods=['PATCH'])
@token_requerido
def leer_notificacion(id_notificacion):
    cn=_db();cur=cn.cursor()
    try:
        cur.execute('UPDATE notificaciones SET leida=1 WHERE id_notificacion=%s AND id_usuario=%s',
                    (id_notificacion,g.id_usuario))
        cn.commit()
    finally:cur.close();cn.close()
    return jsonify({'mensaje':'Notificación marcada como leída.'})


@extras_bp.route('/api/admin/resumen', methods=['GET'])
@token_requerido
def resumen_admin():
    _admin()
    cn=_db();cur=cn.cursor(dictionary=True)
    try:
        metrics={}
        for clave,consulta in [
          ('clientes','SELECT COUNT(*) AS cantidad FROM usuarios WHERE id_rol=2'),
          ('activos','SELECT COUNT(*) AS cantidad FROM usuarios WHERE id_rol=2 AND activo=1'),
          ('ejercicios','SELECT COUNT(*) AS cantidad FROM ejercicios'),
          ('propuestas',"SELECT COUNT(*) AS cantidad FROM propuestas_ejercicios WHERE estado='PENDIENTE'"),
          ('entrenamientos','SELECT COUNT(*) AS cantidad FROM sesiones_entrenamiento'),
          ('asistencias','SELECT COUNT(*) AS cantidad FROM asistencias')]:
            cur.execute(consulta);metrics[clave]=cur.fetchone()['cantidad']
        return jsonify({'estadisticas':metrics})
    finally:cur.close();cn.close()


@extras_bp.route('/api/admin/usuarios', methods=['GET'])
@token_requerido
def usuarios_admin():
    _admin()
    cn=_db();cur=cn.cursor(dictionary=True)
    try:
        cur.execute('''SELECT id_usuario,nombre,apellido,email,telefono,activo,fecha_registro
                       FROM usuarios WHERE id_rol=2 ORDER BY fecha_registro DESC LIMIT 200''')
        usuarios=cur.fetchall()
        for u in usuarios:u['fecha_registro']=_fecha(u['fecha_registro'])
        return jsonify({'usuarios':usuarios})
    finally:cur.close();cn.close()


@extras_bp.route('/api/admin/usuarios/<int:id_usuario>/estado', methods=['PATCH'])
@token_requerido
def estado_usuario(id_usuario):
    _admin()
    data=_body()
    if type(data.get('activo')) is not bool: raise ApiError('Indica activo: true o false.',400)
    cn=_db();cur=cn.cursor()
    try:
        cur.execute('UPDATE usuarios SET activo=%s WHERE id_usuario=%s AND id_rol=2',
                    (int(data['activo']), id_usuario))
        if not cur.rowcount: raise ApiError('Cliente no encontrado o sin cambios.', 404)
        cn.commit()
    except Exception:
        cn.rollback();raise
    finally:cur.close();cn.close()
    return jsonify({'mensaje':'Estado de usuario actualizado.'})


@extras_bp.route('/api/admin/ejercicios/<int:id_ejercicio>', methods=['PUT'])
@token_requerido
def editar_ejercicio(id_ejercicio):
    _admin()
    data=_body()
    nombre=_text(data.get('nombre'),'Nombre',3,100)
    desc=_text(data.get('descripcion') or '', 'Descripción', 0, 255)
    id_grupo=_integer(data.get('id_grupo'), 'Grupo muscular',1,9)
    cn=_db();cur=cn.cursor()
    try:
        cur.execute('''UPDATE ejercicios SET nombre=%s, descripcion=%s, id_grupo=%s
                       WHERE id_ejercicio=%s''',(nombre,desc,id_grupo,id_ejercicio))
        if not cur.rowcount:raise ApiError('Ejercicio no encontrado o sin cambios.',404)
        cn.commit()
    except mysql.connector.IntegrityError:
        cn.rollback();raise ApiError('Ya existe un ejercicio con ese nombre.',409)
    except Exception:
        cn.rollback();raise
    finally:cur.close();cn.close()
    return jsonify({'mensaje':'Ejercicio actualizado.'})
