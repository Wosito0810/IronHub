import datetime
import re
import secrets
from werkzeug.security import check_password_hash, generate_password_hash

from errors import ApiError
from repositories import (
    AsignacionRepository,
    AsistenciaRepository,
    ClienteRepository,
    EjercicioRepository,
    RutinaRepository,
    UsuarioRepository,
)
from security import crear_token

DIAS_SEMANA = {
    1: "Lunes",
    2: "Martes",
    3: "Miércoles",
    4: "Jueves",
    5: "Viernes",
    6: "Sábado",
    7: "Domingo",
}


def _texto_obligatorio(valor, campo, maximo):
    texto = (valor or "").strip() if isinstance(valor, str) else ""
    if not texto:
        raise ApiError(f"El campo «{campo}» es obligatorio.", 400)
    if len(texto) > maximo:
        raise ApiError(f"El campo «{campo}» no puede superar los {maximo} caracteres.", 400)
    return texto


def _dia_valido(valor):
    try:
        dia = int(valor)
    except (TypeError, ValueError):
        raise ApiError("El día de la semana debe ser un número entre 1 y 7.", 400)
    if dia not in DIAS_SEMANA:
        raise ApiError("El día de la semana debe ser un número entre 1 y 7.", 400)
    return dia


def _entero_en_rango(valor, campo, defecto, minimo=1, maximo=99):
    if valor is None or valor == "":
        valor = defecto
    try:
        numero = int(valor)
    except (TypeError, ValueError):
        raise ApiError(f"El campo «{campo}» debe ser un número entero entre {minimo} y {maximo}.", 400)
    if numero < minimo or numero > maximo:
        raise ApiError(f"El campo «{campo}» debe estar entre {minimo} y {maximo}.", 400)
    return numero


class AutenticacionService:
    def __init__(self):
        self.usuario_repo = UsuarioRepository()
        self.cliente_repo = ClienteRepository()

    def iniciar_sesion(self, email, password):
        email_normalizado = email.strip().lower() if isinstance(email, str) else ''
        usuario = self.usuario_repo.buscar_por_email(email_normalizado)
        if not usuario or not isinstance(password, str):
            raise ApiError("Credenciales inválidas.", 401)
        guardada = usuario['password_hash'] or ''
        # Los registros antiguos del ZIP de demostración contienen texto plano.
        # Al iniciar sesión correctamente se migran automáticamente a hash scrypt.
        if guardada.startswith(('scrypt:', 'pbkdf2:')):
            correcta = check_password_hash(guardada, password)
        else:
            correcta = secrets.compare_digest(guardada, password)
            if correcta:
                self.usuario_repo.actualizar_password(usuario['id_usuario'],
                                                       generate_password_hash(password))
        if not correcta:
            raise ApiError("Credenciales inválidas.", 401)
        if not usuario.get('activo'):
            raise ApiError("Tu usuario está inactivo. Contacta al administrador.", 403)

        id_cliente = (self.cliente_repo.asegurar_por_usuario(usuario['id_usuario'])
                      if int(usuario['id_rol']) == 2 else None)
        token = crear_token(usuario['id_usuario'], usuario['id_rol'])

        return {
            "token": token,
            "usuario": {
                "id_usuario": usuario['id_usuario'],
                "id_rol": usuario['id_rol'],
                "id_cliente": id_cliente,
                "nombre": usuario['nombre'],
                "apellido": usuario['apellido'],
                "email": usuario['email'],
            },
        }

    def perfil(self, id_usuario):
        usuario = self.usuario_repo.buscar_por_id(id_usuario)
        if not usuario:
            raise ApiError("Tu usuario ya no existe.", 404)
        id_cliente = (self.cliente_repo.asegurar_por_usuario(usuario['id_usuario'])
                      if int(usuario['id_rol']) == 2 else None)
        return {
            "id_usuario": usuario['id_usuario'],
            "id_rol": usuario['id_rol'],
            "id_cliente": id_cliente,
            "nombre": usuario['nombre'],
            "apellido": usuario['apellido'],
            "email": usuario['email'],
        }

    def registrar_usuario(self, datos):
        """Autoregistro público: solamente clientes y contraseñas con hash.

        El rol y el estado de la cuenta jamás se reciben del navegador.
        """
        if not isinstance(datos, dict):
            raise ApiError('Datos de registro no válidos.', 400)
        nombre = _texto_obligatorio(datos.get('nombre'), 'Nombre', 60)
        apellido = _texto_obligatorio(datos.get('apellido'), 'Apellido', 60)
        if len(nombre) < 2 or len(apellido) < 2:
            raise ApiError('El nombre y el apellido deben tener al menos 2 caracteres.', 400)
        email = _texto_obligatorio(datos.get('email'), 'Correo electrónico', 120).lower()
        if not re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", email):
            raise ApiError('El correo electrónico no es válido.', 400)
        password = datos.get('password')
        if (not isinstance(password, str) or not 8 <= len(password) <= 128
                or not re.search(r'[a-zA-ZÁÉÍÓÚÜÑáéíóúüñ]', password)
                or not re.search(r'[0-9]', password)):
            raise ApiError('La contraseña debe tener de 8 a 128 caracteres, una letra y un número.', 400)
        telefono = datos.get('telefono') or ''
        if not isinstance(telefono, str) or len(telefono.strip()) > 20:
            raise ApiError('El teléfono no debe superar 20 caracteres.', 400)
        if self.usuario_repo.buscar_por_email(email):
            raise ApiError('El correo ya está registrado. Inicia sesión o utiliza otro.', 409)
        return self.usuario_repo.guardar({
            'id_rol': 2,  # Prohibido elegir ADMIN desde registro público.
            'nombre': nombre,
            'apellido': apellido,
            'email': email,
            'password_hash': generate_password_hash(password),
            'telefono': telefono.strip(),
        })

class ClientesService:
    def __init__(self):
        self.cliente_repo = ClienteRepository()

    def listar_clientes(self):
        return self.cliente_repo.listar()

    def crear_cliente(self, datos):
        # RF02: Gestión de clientes (crea usuario y su perfil de cliente asociado)
        auth_svc = AutenticacionService()
        id_usuario = auth_svc.registrar_usuario({
            'id_rol': 2,
            'nombre': datos.get('nombre'),
            'apellido': datos.get('apellido'),
            'email': datos.get('email'),
            'password': datos.get('password'),
            'telefono': datos.get('telefono'),
        })
        return self.cliente_repo.guardar(
            id_usuario, datos.get('documento'), datos.get('fecha_nacimiento'), datos.get('objetivo')
        )


class EjerciciosService:
    def __init__(self):
        self.ejercicio_repo = EjercicioRepository()

    def listar(self):
        return self.ejercicio_repo.listar_todos()

    def crear(self, datos):
        # RF03: Catálogo de ejercicios
        if not datos.get('nombre') or not datos.get('id_grupo'):
            raise ApiError("Nombre y grupo muscular son obligatorios.", 400)
        return self.ejercicio_repo.guardar(datos)


class RutinasService:
    def __init__(self):
        self.rutina_repo = RutinaRepository()
        self.asignacion_repo = AsignacionRepository()
        self.cliente_repo = ClienteRepository()
        self.ejercicio_repo = EjercicioRepository()

    # ------------------------------------------------------------------
    # Validaciones compartidas
    # ------------------------------------------------------------------
    def _id_cliente(self, id_usuario):
        return self.cliente_repo.asegurar_por_usuario(id_usuario)

    def _normalizar_ejercicios(self, ejercicios):
        if not isinstance(ejercicios, list) or len(ejercicios) == 0:
            raise ApiError("Debes seleccionar al menos un ejercicio para la rutina.", 400)

        normalizados = []
        vistos = set()
        for posicion, ej in enumerate(ejercicios, start=1):
            if not isinstance(ej, dict) or not ej.get('id_ejercicio'):
                raise ApiError("Todos los ejercicios deben incluir su identificador.", 400)
            try:
                id_ejercicio = int(ej['id_ejercicio'])
            except (TypeError, ValueError):
                raise ApiError("El identificador de un ejercicio no es válido.", 400)

            if id_ejercicio in vistos:
                raise ApiError("No puedes repetir el mismo ejercicio dentro de la rutina.", 400)
            vistos.add(id_ejercicio)

            normalizados.append({
                'id_ejercicio': id_ejercicio,
                'orden': posicion,
                'series': _entero_en_rango(ej.get('series'), 'series', 3),
                'repeticiones': _entero_en_rango(ej.get('repeticiones'), 'repeticiones', 10),
            })

        existentes = self.ejercicio_repo.contar_existentes([e['id_ejercicio'] for e in normalizados])
        if existentes != len(normalizados):
            raise ApiError("Alguno de los ejercicios seleccionados ya no existe en el catálogo.", 400)

        return normalizados

    # ------------------------------------------------------------------
    # Rutinas especializadas
    # ------------------------------------------------------------------
    def listar_planes_especializados(self):
        return self.rutina_repo.listar_planes_especializados()

    def guardar_plan_especializado(self, id_usuario, datos):
        try:
            id_rutina = int(datos.get('id_rutina'))
        except (TypeError, ValueError):
            raise ApiError("Debes indicar el plan especializado que deseas guardar.", 400)

        plan = self.rutina_repo.obtener_por_id(id_rutina)
        if not plan or plan.get('tipo') != 'ESPECIALIZADA':
            raise ApiError("El plan especializado seleccionado no existe.", 404)

        dias = plan.get('dias') or []
        if len(dias) != 7 or not any(not dia['es_descanso'] for dia in dias):
            raise ApiError(
                "Este plan todavía no tiene una planificación semanal configurada. "
                "Contacta al administrador.",
                400,
            )

        id_cliente = self._id_cliente(id_usuario)
        self.asignacion_repo.reemplazar_plan_semanal(id_cliente, id_rutina)

        return {
            "id_rutina": id_rutina,
            "dias_semana": list(range(1, 8)),
            "mensaje": (
                f"Plan «{plan['nombre']}» guardado correctamente. "
                "Tu planificación semanal fue reemplazada."
            ),
        }

    def quitar_plan_especializado(self, id_usuario):
        id_cliente = self._id_cliente(id_usuario)
        eliminadas = self.asignacion_repo.eliminar_plan_semanal(id_cliente)
        if not eliminadas:
            raise ApiError("No tienes un plan especializado activo.", 404)
        return {
            "mensaje": "El plan especializado fue retirado de tu planificación semanal."
        }

    # ------------------------------------------------------------------
    # Planes personalizados
    # ------------------------------------------------------------------
    def crear_rutina_personalizada(self, id_usuario, datos):
        nombre = _texto_obligatorio(datos.get('nombre'), "nombre de la rutina", 100)
        descripcion = (datos.get('descripcion') or "Plan personalizado creado por el cliente").strip()[:255]
        dia_semana = _dia_valido(datos.get('dia_semana'))
        ejercicios = self._normalizar_ejercicios(datos.get('ejercicios'))

        id_cliente = self._id_cliente(id_usuario)
        if self.rutina_repo.existe_personalizada(id_usuario, id_cliente, nombre, dia_semana):
            raise ApiError(
                f"Ya tienes una rutina llamada «{nombre}» guardada para el {DIAS_SEMANA[dia_semana]}.",
                409,
            )

        id_rutina, id_asignacion = self.rutina_repo.crear_personalizada(
            id_usuario, id_cliente, nombre, descripcion, dia_semana, ejercicios
        )

        return {
            "id_rutina": id_rutina,
            "id_asignacion": id_asignacion,
            "dia_semana": dia_semana,
            "mensaje": f"Rutina «{nombre}» guardada correctamente para el {DIAS_SEMANA[dia_semana]}.",
        }

    def listar_rutinas_personalizadas(self, id_usuario):
        id_cliente = self._id_cliente(id_usuario)
        rutinas = self.rutina_repo.listar_personalizadas(id_usuario, id_cliente)
        for rutina in rutinas:
            for dia in rutina['dias']:
                dia['dia_nombre'] = DIAS_SEMANA.get(dia['dia_semana'], '')
        return rutinas

    def actualizar_rutina_personalizada(self, id_usuario, id_rutina, datos):
        nombre = _texto_obligatorio(datos.get('nombre'), "nombre de la rutina", 100)
        descripcion = (datos.get('descripcion') or "Plan personalizado creado por el cliente").strip()[:255]
        dia_semana = _dia_valido(datos.get('dia_semana'))
        ejercicios = self._normalizar_ejercicios(datos.get('ejercicios'))

        id_cliente = self._id_cliente(id_usuario)
        self.rutina_repo.actualizar_personalizada(
            id_rutina, id_usuario, id_cliente, nombre, descripcion, dia_semana, ejercicios
        )
        return {"mensaje": f"Rutina «{nombre}» actualizada correctamente."}

    def eliminar_rutina_personalizada(self, id_usuario, id_rutina):
        self.rutina_repo.eliminar_personalizada(id_rutina, id_usuario)
        return {"mensaje": "Rutina personalizada eliminada correctamente."}

    # ------------------------------------------------------------------
    # Rutina del día
    # ------------------------------------------------------------------
    def obtener_rutina_del_dia(self, id_usuario, dia_semana):
        dia_semana = _dia_valido(dia_semana)
        id_cliente = self._id_cliente(id_usuario)
        rutinas = self.asignacion_repo.listar_por_dia(id_cliente, dia_semana)

        return {
            "dia_semana": dia_semana,
            "dia_nombre": DIAS_SEMANA[dia_semana],
            "rutinas": rutinas,
        }

    def eliminar_asignacion(self, id_usuario, id_asignacion):
        id_cliente = self._id_cliente(id_usuario)
        tipo = self.asignacion_repo.eliminar(id_asignacion, id_cliente)
        if tipo == 'ESPECIALIZADA':
            return {
                "mensaje": "El plan especializado fue retirado de tu planificación semanal."
            }
        return {"mensaje": "La rutina fue eliminada del día seleccionado."}

    # ------------------------------------------------------------------
    # Compatibilidad con endpoints anteriores
    # ------------------------------------------------------------------
    def crear_rutina(self, id_usuario, datos):
        nombre = _texto_obligatorio(datos.get('nombre'), "nombre de la rutina", 100)
        descripcion = (datos.get('descripcion') or "").strip()[:255]
        ejercicios = self._normalizar_ejercicios(datos.get('ejercicios'))
        # El endpoint legado crea la rutina y sus detalles sin asignarla a un día.
        id_rutina = self.rutina_repo.guardar({
            'id_entrenador': id_usuario, 'nombre': nombre, 'descripcion': descripcion
        })
        for ej in ejercicios:
            self.rutina_repo.agregar_ejercicio_detalle(
                id_rutina, ej['id_ejercicio'], ej['orden'], ej['series'], ej['repeticiones']
            )
        return id_rutina

    def asignar_rutina(self, id_usuario, datos):
        dia_semana = _dia_valido(datos.get('dia_semana'))
        try:
            id_rutina = int(datos.get('id_rutina'))
        except (TypeError, ValueError):
            raise ApiError("Debes indicar la rutina que deseas asignar.", 400)

        plan = self.rutina_repo.obtener_por_id(id_rutina)
        if not plan:
            raise ApiError("La rutina indicada no existe.", 404)
        if plan['tipo'] == 'ESPECIALIZADA':
            raise ApiError(
                "Los planes especializados son semanales. Usa "
                "/api/rutinas/especializadas para activar los 7 días.",
                400,
            )
        if plan.get('id_usuario_propietario') != id_usuario:
            raise ApiError("No puedes asignar una rutina que no te pertenece.", 403)

        id_cliente = self._id_cliente(id_usuario)
        return self.asignacion_repo.asignar(id_cliente, id_rutina, dia_semana)

    def obtener_rutina_legacy(self, id_usuario, id_cliente_solicitado, dia_semana):
        id_cliente = self._id_cliente(id_usuario)
        if int(id_cliente_solicitado) != int(id_cliente):
            raise ApiError("No puedes consultar las rutinas de otro usuario.", 403)

        dia_semana = _dia_valido(dia_semana)
        rutinas = self.asignacion_repo.listar_por_dia(id_cliente, dia_semana)
        if not rutinas:
            raise ApiError(
                "No hay rutinas guardadas para este día. Elige un plan especializado o crea uno personalizado.",
                404,
            )
        return rutinas[0]


class AsistenciaService:
    def __init__(self):
        self.asistencia_repo = AsistenciaRepository()
        self.cliente_repo = ClienteRepository()

    def registrar(self, id_usuario):
        # RF07: Registro de asistencia con fecha y hora exacta
        id_cliente = self.cliente_repo.asegurar_por_usuario(id_usuario)
        ahora = datetime.datetime.now()
        fecha_hora = ahora.strftime('%Y-%m-%d %H:%M:%S')
        exito = self.asistencia_repo.registrar(id_cliente, fecha_hora, ahora.date())
        if not exito:
            raise ApiError("Ya registraste tu asistencia el día de hoy.", 409)
        return {"mensaje": "Asistencia registrada exitosamente."}

    def mi_historial(self, id_usuario):
        cliente = self.cliente_repo.asegurar_por_usuario(id_usuario)
        return self.asistencia_repo.listar_cliente(cliente)

    def generar_reporte(self):
        # RF08: Reporte de actividad
        return self.asistencia_repo.obtener_reporte()
