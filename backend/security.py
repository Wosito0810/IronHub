"""Tokens JWT para IRONHUB (desarrollo local).

Si el usuario no ha configurado JWT_SECRET, se crea una clave aleatoria
persistente SOLO en este computador. El archivo nunca debe compartirse.
"""
import datetime
import os
import secrets
from pathlib import Path
from dotenv import load_dotenv
from functools import wraps

import jwt
from flask import g, request

from errors import ApiError

load_dotenv()


def _get_secret():
    configurada = os.getenv('JWT_SECRET', '').strip()
    if configurada:
        return configurada
    ruta = Path(__file__).resolve().parent / '.jwt_secret'
    try:
        with ruta.open('x', encoding='ascii') as f:
            f.write(secrets.token_urlsafe(48))
    except FileExistsError:
        pass
    return ruta.read_text(encoding='ascii').strip()


SECRET_KEY = _get_secret()
ALGORITHM = 'HS256'
TOKEN_HORAS = 8


def crear_token(id_usuario, id_rol):
    return jwt.encode({
        'id_usuario': int(id_usuario), 'id_rol': int(id_rol),
        'exp': datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=TOKEN_HORAS),
    }, SECRET_KEY, algorithm=ALGORITHM)


def token_requerido(funcion):
    @wraps(funcion)
    def envoltura(*args, **kwargs):
        cabecera = request.headers.get('Authorization', '')
        if not cabecera.startswith('Bearer '):
            raise ApiError('Debes iniciar sesión para realizar esta operación.', 401)
        try:
            payload = jwt.decode(cabecera[7:].strip(), SECRET_KEY, algorithms=[ALGORITHM])
        except jwt.ExpiredSignatureError:
            raise ApiError('Tu sesión expiró. Vuelve a iniciar sesión.', 401)
        except jwt.InvalidTokenError:
            raise ApiError('Token de sesión inválido.', 401)
        try:
            user_id = int(payload.get('id_usuario'))
            if user_id < 1: raise ValueError()
        except (TypeError, ValueError):
            raise ApiError('Token de sesión inválido.', 401)
        # No confiar en el rol incrustado en un token antiguo: consultar
        # el estado y el rol actuales en MySQL en cada operación protegida.
        from database import DatabaseManager
        conexion = DatabaseManager.get_instance().get_connection()
        cursor = conexion.cursor(dictionary=True)
        try:
            cursor.execute('SELECT id_rol, activo FROM usuarios WHERE id_usuario=%s', (user_id,))
            usuario = cursor.fetchone()
        finally:
            cursor.close()
            conexion.close()
        if not usuario or not usuario['activo']:
            raise ApiError('Tu cuenta está inactiva o ya no existe.', 403)
        g.id_usuario = user_id
        g.id_rol = usuario['id_rol']
        return funcion(*args, **kwargs)
    return envoltura
