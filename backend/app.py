import os
from flask import Flask, g, jsonify, request
from flask_cors import CORS
from propuestas import propuestas_bp
from extras import extras_bp
from werkzeug.exceptions import HTTPException

from errors import ApiError
from security import token_requerido
from services import (
    AsistenciaService,
    AutenticacionService,
    ClientesService,
    EjerciciosService,
    RutinasService,
)

app = Flask(__name__)
app.config["PROPAGATE_EXCEPTIONS"] = False
app.config["MAX_CONTENT_LENGTH"] = 26 * 1024 * 1024
CORS(app, resources={r"/api/*": {"origins": [
    r"^https?://localhost(:[0-9]+)?$",
    r"^https?://127\.0\.0\.1(:[0-9]+)?$",
]}})  # Solo Live Server/servicios locales
app.register_blueprint(propuestas_bp)
app.register_blueprint(extras_bp)

auth_service = AutenticacionService()
cliente_service = ClientesService()
ejercicio_service = EjerciciosService()
rutina_service = RutinasService()
asistencia_service = AsistenciaService()


def _json():
    return request.get_json(silent=True) or {}


# ----------------------------------------------------------------------
# Manejo centralizado de errores: siempre se responde JSON
# ----------------------------------------------------------------------
@app.errorhandler(ApiError)
def manejar_api_error(error):
    return jsonify({"error": error.mensaje}), error.status


@app.errorhandler(HTTPException)
def manejar_http_error(error):
    return jsonify({"error": error.description}), error.code


@app.errorhandler(Exception)
def manejar_error_inesperado(error):
    app.logger.exception("Error no controlado: %s", error)
    return jsonify({"error": "Ocurrió un error inesperado en el servidor. Inténtalo de nuevo."}), 500


# ----------------------------------------------------------------------
# Autenticación
# ----------------------------------------------------------------------
@app.route('/api/health', methods=['GET'])
def health():
    return jsonify({"estado": "ok"}), 200


@app.route('/api/auth/login', methods=['POST'])
def login():
    datos = _json()
    return jsonify(auth_service.iniciar_sesion(datos.get('email'), datos.get('password'))), 200


@app.route('/api/auth/perfil', methods=['GET'])
@token_requerido
def perfil():
    return jsonify({"usuario": auth_service.perfil(g.id_usuario)}), 200


@app.route('/api/auth/registro', methods=['POST'])
def registro():
    return jsonify({"id_usuario": auth_service.registrar_usuario(_json()), "mensaje": "Registrado"}), 201


# ----------------------------------------------------------------------
# Clientes
# ----------------------------------------------------------------------
@app.route('/api/clientes', methods=['GET'])
@token_requerido
def listar_clientes():
    clientes = cliente_service.listar_clientes()
    if g.id_rol != 1:
        clientes = [c for c in clientes if c['id_usuario'] == g.id_usuario]
    return jsonify(clientes), 200


@app.route('/api/clientes', methods=['POST'])
@token_requerido
def crear_cliente():
    if g.id_rol != 1:
        raise ApiError("Solo un administrador puede crear clientes.", 403)
    return jsonify({"id_cliente": cliente_service.crear_cliente(_json()), "mensaje": "Cliente creado"}), 201


# ----------------------------------------------------------------------
# Catálogo de ejercicios
# ----------------------------------------------------------------------
@app.route('/api/ejercicios', methods=['GET'])
@token_requerido
def listar_ejercicios():
    return jsonify(ejercicio_service.listar()), 200


@app.route('/api/ejercicios', methods=['POST'])
@token_requerido
def crear_ejercicio():
    if g.id_rol != 1:
        raise ApiError("Solo un administrador puede crear ejercicios.", 403)
    return jsonify({"id_ejercicio": ejercicio_service.crear(_json()), "mensaje": "Ejercicio creado"}), 201


# ----------------------------------------------------------------------
# Rutinas: planes especializados
# ----------------------------------------------------------------------
@app.route('/api/planes-especializados', methods=['GET'])
@token_requerido
def listar_planes_especializados():
    return jsonify({"planes": rutina_service.listar_planes_especializados()}), 200


@app.route('/api/rutinas/especializadas', methods=['POST'])
@token_requerido
def guardar_plan_especializado():
    return jsonify(rutina_service.guardar_plan_especializado(g.id_usuario, _json())), 201


@app.route('/api/rutinas/especializadas/activa', methods=['DELETE'])
@token_requerido
def quitar_plan_especializado():
    return jsonify(rutina_service.quitar_plan_especializado(g.id_usuario)), 200


# ----------------------------------------------------------------------
# Rutinas: planes personalizados
# ----------------------------------------------------------------------
@app.route('/api/rutinas/personalizada', methods=['POST'])
@token_requerido
def crear_rutina_personalizada():
    return jsonify(rutina_service.crear_rutina_personalizada(g.id_usuario, _json())), 201


@app.route('/api/rutinas/personalizadas', methods=['GET'])
@token_requerido
def listar_rutinas_personalizadas():
    return jsonify({"rutinas": rutina_service.listar_rutinas_personalizadas(g.id_usuario)}), 200


@app.route('/api/rutinas/personalizadas/<int:id_rutina>', methods=['PUT'])
@token_requerido
def actualizar_rutina_personalizada(id_rutina):
    return jsonify(rutina_service.actualizar_rutina_personalizada(g.id_usuario, id_rutina, _json())), 200


@app.route('/api/rutinas/personalizadas/<int:id_rutina>', methods=['DELETE'])
@token_requerido
def eliminar_rutina_personalizada(id_rutina):
    return jsonify(rutina_service.eliminar_rutina_personalizada(g.id_usuario, id_rutina)), 200


# ----------------------------------------------------------------------
# Rutina del día
# ----------------------------------------------------------------------
@app.route('/api/rutinas/dia/<int:dia_semana>', methods=['GET'])
@token_requerido
def rutina_del_dia(dia_semana):
    return jsonify(rutina_service.obtener_rutina_del_dia(g.id_usuario, dia_semana)), 200


@app.route('/api/asignaciones/<int:id_asignacion>', methods=['DELETE'])
@token_requerido
def eliminar_asignacion(id_asignacion):
    return jsonify(rutina_service.eliminar_asignacion(g.id_usuario, id_asignacion)), 200


# ----------------------------------------------------------------------
# Asistencia
# ----------------------------------------------------------------------
@app.route('/api/asistencia', methods=['POST'])
@token_requerido
def registrar_asistencia():
    return jsonify(asistencia_service.registrar(g.id_usuario)), 201


@app.route('/api/asistencia/mia', methods=['GET'])
@token_requerido
def mi_asistencia():
    return jsonify(asistencia_service.mi_historial(g.id_usuario)), 200


@app.route('/api/reportes/asistencia', methods=['GET'])
@token_requerido
def reporte_asistencia():
    if g.id_rol != 1:
        raise ApiError("Solo un administrador puede consultar el reporte general.", 403)
    return jsonify(asistencia_service.generar_reporte()), 200


# ----------------------------------------------------------------------
# Endpoints anteriores (compatibilidad, ahora protegidos y con dueño)
# ----------------------------------------------------------------------
@app.route('/api/rutinas', methods=['POST'])
@token_requerido
def crear_rutina():
    return jsonify({"id_rutina": rutina_service.crear_rutina(g.id_usuario, _json()), "mensaje": "Rutina creada"}), 201


@app.route('/api/asignaciones', methods=['POST'])
@token_requerido
def asignar_rutina():
    datos = _json()
    return jsonify({
        "id_asignacion": rutina_service.asignar_rutina(g.id_usuario, datos),
        "mensaje": "Rutina asignada",
    }), 201


@app.route('/api/clientes/<int:id_cliente>/rutina-del-dia/<int:dia_semana>', methods=['GET'])
@token_requerido
def rutina_del_dia_legacy(id_cliente, dia_semana):
    return jsonify(rutina_service.obtener_rutina_legacy(g.id_usuario, id_cliente, dia_semana)), 200


if __name__ == '__main__':
    app.run(host='127.0.0.1', port=int(os.getenv('PORT', '5050')), debug=False)
