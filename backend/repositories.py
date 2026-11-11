import mysql.connector

from database import DatabaseManager
from errors import ApiError

DETALLE_RUTINA_SQL = """
    SELECT re.id_rutina_ejercicio, re.orden, re.series, re.repeticiones,
           e.id_ejercicio, e.nombre, e.descripcion, g.nombre AS grupo_muscular
    FROM rutina_ejercicios re
    JOIN ejercicios e ON re.id_ejercicio = e.id_ejercicio
    JOIN grupos_musculares g ON e.id_grupo = g.id_grupo
    WHERE re.id_rutina = %s
    ORDER BY re.orden
"""

DETALLE_DIA_SQL = """
    SELECT rde.id_rutina_dia_ejercicio, rde.orden, rde.series, rde.repeticiones,
           e.id_ejercicio, e.nombre, e.descripcion, g.nombre AS grupo_muscular
    FROM rutina_dia_ejercicios rde
    JOIN ejercicios e ON rde.id_ejercicio = e.id_ejercicio
    JOIN grupos_musculares g ON e.id_grupo = g.id_grupo
    WHERE rde.id_rutina_dia = %s
    ORDER BY rde.orden
"""


class UsuarioRepository:
    def __init__(self):
        self.db = DatabaseManager.get_instance()

    def buscar_por_email(self, email):
        conn = self.db.get_connection()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute("SELECT * FROM usuarios WHERE email = %s", (email,))
            return cursor.fetchone()
        finally:
            cursor.close()
            conn.close()

    def buscar_por_id(self, id_usuario):
        conn = self.db.get_connection()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute("SELECT * FROM usuarios WHERE id_usuario = %s", (id_usuario,))
            return cursor.fetchone()
        finally:
            cursor.close()
            conn.close()

    def actualizar_password(self, id_usuario, nuevo_hash):
        conn = self.db.get_connection()
        cur = conn.cursor()
        try:
            cur.execute('UPDATE usuarios SET password_hash=%s WHERE id_usuario=%s',
                        (nuevo_hash, id_usuario))
            conn.commit()
        finally:
            cur.close()
            conn.close()

    def guardar(self, usuario):
        conn = self.db.get_connection()
        cursor = conn.cursor()
        try:
            query = "INSERT INTO usuarios (id_rol, nombre, apellido, email, password_hash, telefono) VALUES (%s, %s, %s, %s, %s, %s)"
            cursor.execute(
                query,
                (
                    usuario['id_rol'],
                    usuario['nombre'],
                    usuario['apellido'],
                    usuario['email'],
                    usuario['password_hash'],
                    usuario['telefono'],
                ),
            )
            conn.commit()
            return cursor.lastrowid
        except mysql.connector.IntegrityError as exc:
            conn.rollback()
            if getattr(exc, 'errno', None) == 1062:
                raise ApiError('El correo ya está registrado. Inicia sesión o utiliza otro.', 409) from exc
            raise
        finally:
            cursor.close()
            conn.close()


class ClienteRepository:
    def __init__(self):
        self.db = DatabaseManager.get_instance()

    def listar(self):
        conn = self.db.get_connection()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute("""
                SELECT c.id_cliente, c.id_usuario, c.documento, c.objetivo,
                       u.nombre, u.apellido, u.email, u.telefono, u.activo
                FROM clientes c JOIN usuarios u ON c.id_usuario = u.id_usuario
                ORDER BY c.id_cliente
            """)
            return cursor.fetchall()
        finally:
            cursor.close()
            conn.close()

    def buscar_por_usuario(self, id_usuario):
        conn = self.db.get_connection()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute("SELECT * FROM clientes WHERE id_usuario = %s", (id_usuario,))
            return cursor.fetchone()
        finally:
            cursor.close()
            conn.close()

    def asegurar_por_usuario(self, id_usuario):
        """Devuelve el id_cliente del usuario y lo crea si aún no tiene perfil."""
        cliente = self.buscar_por_usuario(id_usuario)
        if cliente:
            return cliente['id_cliente']

        conn = self.db.get_connection()
        cursor = conn.cursor()
        try:
            documento = "AUTO-%06d" % int(id_usuario)
            cursor.execute(
                "INSERT INTO clientes (id_usuario, documento, fecha_nacimiento, objetivo) VALUES (%s, %s, NULL, %s)",
                (id_usuario, documento, "Perfil creado automáticamente por IRONHUB"),
            )
            conn.commit()
            return cursor.lastrowid
        except mysql.connector.IntegrityError:
            # Otro proceso pudo crearlo al mismo tiempo: se vuelve a consultar.
            conn.rollback()
            cliente = self.buscar_por_usuario(id_usuario)
            if cliente:
                return cliente['id_cliente']
            raise ApiError("No fue posible crear el perfil de cliente.", 500)
        finally:
            cursor.close()
            conn.close()

    def guardar(self, id_usuario, documento, fecha_nacimiento, objetivo):
        conn = self.db.get_connection()
        cursor = conn.cursor()
        try:
            query = "INSERT INTO clientes (id_usuario, documento, fecha_nacimiento, objetivo) VALUES (%s, %s, %s, %s)"
            cursor.execute(query, (id_usuario, documento, fecha_nacimiento, objetivo))
            conn.commit()
            return cursor.lastrowid
        finally:
            cursor.close()
            conn.close()


class EjercicioRepository:
    def __init__(self):
        self.db = DatabaseManager.get_instance()

    def listar_todos(self):
        conn = self.db.get_connection()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute("""
                SELECT e.id_ejercicio, e.id_grupo, e.nombre, e.descripcion,
                       g.nombre AS grupo_muscular
                FROM ejercicios e
                JOIN grupos_musculares g ON e.id_grupo = g.id_grupo
                ORDER BY g.nombre, e.nombre
            """)
            return cursor.fetchall()
        finally:
            cursor.close()
            conn.close()

    def contar_existentes(self, ids):
        if not ids:
            return 0
        conn = self.db.get_connection()
        cursor = conn.cursor()
        try:
            marcadores = ", ".join(["%s"] * len(ids))
            cursor.execute(
                f"SELECT COUNT(*) FROM ejercicios WHERE id_ejercicio IN ({marcadores})",
                tuple(ids),
            )
            return cursor.fetchone()[0]
        finally:
            cursor.close()
            conn.close()

    def guardar(self, ejercicio):
        conn = self.db.get_connection()
        cursor = conn.cursor()
        try:
            query = "INSERT INTO ejercicios (id_grupo, nombre, descripcion) VALUES (%s, %s, %s)"
            cursor.execute(query, (ejercicio['id_grupo'], ejercicio['nombre'], ejercicio['descripcion']))
            conn.commit()
            return cursor.lastrowid
        finally:
            cursor.close()
            conn.close()


class RutinaRepository:
    def __init__(self):
        self.db = DatabaseManager.get_instance()

    # ------------------------------------------------------------------
    # Helpers internos
    # ------------------------------------------------------------------
    def _detalles(self, cursor, id_rutina):
        cursor.execute(DETALLE_RUTINA_SQL, (id_rutina,))
        return cursor.fetchall()

    def _insertar_detalles(self, cursor, id_rutina, ejercicios):
        query = """
            INSERT INTO rutina_ejercicios (id_rutina, id_ejercicio, orden, series, repeticiones)
            VALUES (%s, %s, %s, %s, %s)
        """
        for indice, ej in enumerate(ejercicios, start=1):
            cursor.execute(
                query,
                (
                    id_rutina,
                    ej['id_ejercicio'],
                    ej.get('orden') or indice,
                    ej['series'],
                    ej['repeticiones'],
                ),
            )

    def _detalles_dia(self, cursor, id_rutina_dia):
        cursor.execute(DETALLE_DIA_SQL, (id_rutina_dia,))
        return cursor.fetchall()

    def _ejercicios_plan(self, dias):
        """Lista plana de ejercicios únicos, por compatibilidad con la API anterior."""
        vistos = set()
        ejercicios = []
        for dia in dias:
            for ejercicio in dia['ejercicios']:
                if ejercicio['id_ejercicio'] in vistos:
                    continue
                vistos.add(ejercicio['id_ejercicio'])
                ejercicios.append(dict(ejercicio))
        return ejercicios

    def _dias_plan(self, cursor, id_rutina):
        """Devuelve siempre los 7 días del plan, con descanso y ejercicios."""
        cursor.execute(
            "SELECT id_rutina_dia, dia_semana, enfoque, es_descanso "
            "FROM rutina_dias WHERE id_rutina = %s ORDER BY dia_semana",
            (id_rutina,),
        )
        filas = {fila['dia_semana']: fila for fila in cursor.fetchall()}
        dias = []
        for numero in range(1, 8):
            fila = filas.get(numero)
            if not fila:
                dias.append({
                    "id_rutina_dia": None,
                    "dia_semana": numero,
                    "enfoque": "Sin planificación",
                    "es_descanso": True,
                    "ejercicios": [],
                })
                continue

            es_descanso = bool(fila['es_descanso'])
            dias.append({
                "id_rutina_dia": fila['id_rutina_dia'],
                "dia_semana": numero,
                "enfoque": fila['enfoque'],
                "es_descanso": es_descanso,
                "ejercicios": [] if es_descanso else self._detalles_dia(cursor, fila['id_rutina_dia']),
            })
        return dias

    # ------------------------------------------------------------------
    # Consultas
    # ------------------------------------------------------------------
    def guardar(self, rutina):
        """Mantenido por compatibilidad con el endpoint legado POST /api/rutinas."""
        conn = self.db.get_connection()
        cursor = conn.cursor()
        try:
            query = (
                "INSERT INTO rutinas (id_entrenador, nombre, descripcion, tipo, id_usuario_propietario) "
                "VALUES (%s, %s, %s, 'PERSONALIZADA', %s)"
            )
            cursor.execute(
                query,
                (
                    rutina['id_entrenador'],
                    rutina['nombre'],
                    rutina['descripcion'],
                    rutina['id_entrenador'],
                ),
            )
            conn.commit()
            return cursor.lastrowid
        finally:
            cursor.close()
            conn.close()

    def agregar_ejercicio_detalle(self, id_rutina, id_ejercicio, orden, series, repeticiones):
        conn = self.db.get_connection()
        cursor = conn.cursor()
        try:
            query = "INSERT INTO rutina_ejercicios (id_rutina, id_ejercicio, orden, series, repeticiones) VALUES (%s, %s, %s, %s, %s)"
            cursor.execute(query, (id_rutina, id_ejercicio, orden, series, repeticiones))
            conn.commit()
            return cursor.lastrowid
        finally:
            cursor.close()
            conn.close()

    def obtener_por_id(self, id_rutina):
        conn = self.db.get_connection()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(
                "SELECT id_rutina, id_entrenador, id_usuario_propietario, nombre, descripcion, tipo, fecha_creacion "
                "FROM rutinas WHERE id_rutina = %s",
                (id_rutina,),
            )
            rutina = cursor.fetchone()
            if rutina:
                rutina['ejercicios'] = self._detalles(cursor, id_rutina)
                if rutina['tipo'] == 'ESPECIALIZADA':
                    rutina['dias'] = self._dias_plan(cursor, id_rutina)
                    rutina['ejercicios'] = self._ejercicios_plan(rutina['dias'])
            return rutina
        finally:
            cursor.close()
            conn.close()

    def obtener_con_detalles(self, id_rutina):
        return self.obtener_por_id(id_rutina)

    def listar_planes_especializados(self):
        conn = self.db.get_connection()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(
                "SELECT id_rutina, nombre, descripcion, fecha_creacion "
                "FROM rutinas WHERE tipo = 'ESPECIALIZADA' ORDER BY id_rutina"
            )
            planes = cursor.fetchall()
            for plan in planes:
                plan['dias'] = self._dias_plan(cursor, plan['id_rutina'])
                plan['ejercicios'] = self._ejercicios_plan(plan['dias'])
                plan['dias_entrenamiento'] = sum(
                    1 for dia in plan['dias'] if not dia['es_descanso']
                )
                plan['total_ejercicios'] = sum(
                    len(dia['ejercicios']) for dia in plan['dias']
                )
            return planes
        finally:
            cursor.close()
            conn.close()

    def listar_personalizadas(self, id_usuario, id_cliente):
        conn = self.db.get_connection()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(
                "SELECT id_rutina, nombre, descripcion, fecha_creacion "
                "FROM rutinas WHERE tipo = 'PERSONALIZADA' AND id_usuario_propietario = %s "
                "ORDER BY fecha_creacion DESC, id_rutina DESC",
                (id_usuario,),
            )
            rutinas = cursor.fetchall()
            for rutina in rutinas:
                rutina['ejercicios'] = self._detalles(cursor, rutina['id_rutina'])
                cursor.execute(
                    "SELECT id_asignacion, dia_semana FROM asignaciones "
                    "WHERE id_rutina = %s AND id_cliente = %s ORDER BY dia_semana",
                    (rutina['id_rutina'], id_cliente),
                )
                rutina['dias'] = cursor.fetchall()
            return rutinas
        finally:
            cursor.close()
            conn.close()

    # ------------------------------------------------------------------
    # Escritura transaccional
    # ------------------------------------------------------------------
    def existe_personalizada(self, id_usuario, id_cliente, nombre, dia_semana):
        conn = self.db.get_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(
                "SELECT 1 FROM rutinas r "
                "JOIN asignaciones a ON a.id_rutina = r.id_rutina "
                "WHERE r.tipo = 'PERSONALIZADA' AND r.id_usuario_propietario = %s "
                "AND a.id_cliente = %s AND a.dia_semana = %s AND r.nombre = %s LIMIT 1",
                (id_usuario, id_cliente, dia_semana, nombre),
            )
            return cursor.fetchone() is not None
        finally:
            cursor.close()
            conn.close()

    def crear_personalizada(self, id_usuario, id_cliente, nombre, descripcion, dia_semana, ejercicios):
        conn = self.db.get_connection()
        cursor = conn.cursor()
        try:
            conn.start_transaction()
            cursor.execute(
                "INSERT INTO rutinas (id_entrenador, nombre, descripcion, tipo, id_usuario_propietario) "
                "VALUES (%s, %s, %s, 'PERSONALIZADA', %s)",
                (id_usuario, nombre, descripcion, id_usuario),
            )
            id_rutina = cursor.lastrowid
            self._insertar_detalles(cursor, id_rutina, ejercicios)
            cursor.execute(
                "INSERT INTO asignaciones (id_cliente, id_rutina, dia_semana) VALUES (%s, %s, %s)",
                (id_cliente, id_rutina, dia_semana),
            )
            id_asignacion = cursor.lastrowid
            conn.commit()
            return id_rutina, id_asignacion
        except Exception:
            conn.rollback()
            raise
        finally:
            cursor.close()
            conn.close()

    def actualizar_personalizada(self, id_rutina, id_usuario, id_cliente, nombre, descripcion, dia_semana, ejercicios):
        conn = self.db.get_connection()
        cursor = conn.cursor(dictionary=True)
        try:
            conn.start_transaction()
            cursor.execute(
                "SELECT id_rutina FROM rutinas "
                "WHERE id_rutina = %s AND tipo = 'PERSONALIZADA' AND id_usuario_propietario = %s FOR UPDATE",
                (id_rutina, id_usuario),
            )
            if not cursor.fetchone():
                raise ApiError("La rutina personalizada no existe o no te pertenece.", 404)

            cursor.execute(
                "UPDATE rutinas SET nombre = %s, descripcion = %s WHERE id_rutina = %s",
                (nombre, descripcion, id_rutina),
            )
            cursor.execute("DELETE FROM rutina_ejercicios WHERE id_rutina = %s", (id_rutina,))
            self._insertar_detalles(cursor, id_rutina, ejercicios)

            cursor.execute(
                "DELETE FROM asignaciones WHERE id_rutina = %s AND id_cliente = %s",
                (id_rutina, id_cliente),
            )
            cursor.execute(
                "INSERT INTO asignaciones (id_cliente, id_rutina, dia_semana) VALUES (%s, %s, %s)",
                (id_cliente, id_rutina, dia_semana),
            )
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            cursor.close()
            conn.close()

    def eliminar_personalizada(self, id_rutina, id_usuario):
        conn = self.db.get_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(
                "DELETE FROM rutinas "
                "WHERE id_rutina = %s AND tipo = 'PERSONALIZADA' AND id_usuario_propietario = %s",
                (id_rutina, id_usuario),
            )
            eliminadas = cursor.rowcount
            conn.commit()
        finally:
            cursor.close()
            conn.close()

        if eliminadas == 0:
            raise ApiError("La rutina personalizada no existe o no te pertenece.", 404)


class AsignacionRepository:
    def __init__(self):
        self.db = DatabaseManager.get_instance()

    def asignar(self, id_cliente, id_rutina, dia_semana):
        conn = self.db.get_connection()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(
                "SELECT id_asignacion FROM asignaciones "
                "WHERE id_cliente = %s AND dia_semana = %s AND id_rutina = %s",
                (id_cliente, dia_semana, id_rutina),
            )
            if cursor.fetchone():
                raise ApiError("Ese plan ya está guardado para el día seleccionado.", 409)

            cursor.execute(
                "INSERT INTO asignaciones (id_cliente, id_rutina, dia_semana) VALUES (%s, %s, %s)",
                (id_cliente, id_rutina, dia_semana),
            )
            conn.commit()
            return cursor.lastrowid
        except mysql.connector.IntegrityError:
            conn.rollback()
            raise ApiError("Ese plan ya está guardado para el día seleccionado.", 409)
        finally:
            cursor.close()
            conn.close()

    def reemplazar_plan_semanal(self, id_cliente, id_rutina):
        """Activa un plan especializado para los 7 días del cliente.

        Sustituye únicamente las asignaciones especializadas anteriores.
        Las rutinas personalizadas del cliente se conservan intactas.
        """
        conn = self.db.get_connection()
        cursor = conn.cursor()
        try:
            conn.start_transaction()
            cursor.execute(
                "DELETE a FROM asignaciones a "
                "JOIN rutinas r ON a.id_rutina = r.id_rutina "
                "WHERE a.id_cliente = %s AND r.tipo = 'ESPECIALIZADA'",
                (id_cliente,),
            )
            for dia_semana in range(1, 8):
                cursor.execute(
                    "INSERT INTO asignaciones (id_cliente, id_rutina, dia_semana) "
                    "VALUES (%s, %s, %s)",
                    (id_cliente, id_rutina, dia_semana),
                )
            conn.commit()
            return 7
        except Exception:
            conn.rollback()
            raise
        finally:
            cursor.close()
            conn.close()

    def eliminar_plan_semanal(self, id_cliente):
        """Quita el plan especializado completo del cliente (los 7 días)."""
        conn = self.db.get_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(
                "DELETE a FROM asignaciones a "
                "JOIN rutinas r ON a.id_rutina = r.id_rutina "
                "WHERE a.id_cliente = %s AND r.tipo = 'ESPECIALIZADA'",
                (id_cliente,),
            )
            eliminadas = cursor.rowcount
            conn.commit()
            return eliminadas
        finally:
            cursor.close()
            conn.close()

    def listar_por_dia(self, id_cliente, dia_semana):
        conn = self.db.get_connection()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(
                "SELECT a.id_asignacion, a.dia_semana, a.fecha_asignacion, "
                "       r.id_rutina, r.nombre, r.descripcion, r.tipo, r.id_usuario_propietario, "
                "       rd.id_rutina_dia, rd.enfoque, rd.es_descanso "
                "FROM asignaciones a "
                "JOIN rutinas r ON a.id_rutina = r.id_rutina "
                "LEFT JOIN rutina_dias rd ON rd.id_rutina = r.id_rutina "
                "     AND rd.dia_semana = a.dia_semana "
                "WHERE a.id_cliente = %s AND a.dia_semana = %s "
                "ORDER BY CASE WHEN r.tipo = 'ESPECIALIZADA' THEN 0 ELSE 1 END, "
                "         a.fecha_asignacion ASC, a.id_asignacion ASC",
                (id_cliente, dia_semana),
            )
            rutinas = cursor.fetchall()
            for rutina in rutinas:
                rutina['enfoque'] = rutina.get('enfoque') or None
                if rutina['tipo'] == 'ESPECIALIZADA' and rutina.get('id_rutina_dia'):
                    rutina['es_descanso'] = bool(rutina.get('es_descanso'))
                    rutina['ejercicios'] = (
                        [] if rutina['es_descanso']
                        else self._detalles_dia(cursor, rutina['id_rutina_dia'])
                    )
                else:
                    rutina['es_descanso'] = False
                    rutina['ejercicios'] = self._detalles(cursor, rutina['id_rutina'])
            return rutinas
        finally:
            cursor.close()
            conn.close()

    def _detalles(self, cursor, id_rutina):
        cursor.execute(DETALLE_RUTINA_SQL, (id_rutina,))
        return cursor.fetchall()

    def _detalles_dia(self, cursor, id_rutina_dia):
        cursor.execute(DETALLE_DIA_SQL, (id_rutina_dia,))
        return cursor.fetchall()

    def eliminar(self, id_asignacion, id_cliente):
        conn = self.db.get_connection()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(
                "SELECT a.id_asignacion, r.tipo FROM asignaciones a "
                "JOIN rutinas r ON a.id_rutina = r.id_rutina "
                "WHERE a.id_asignacion = %s AND a.id_cliente = %s",
                (id_asignacion, id_cliente),
            )
            asignacion = cursor.fetchone()
            if not asignacion:
                raise ApiError("La rutina guardada no existe o no te pertenece.", 404)
            if asignacion['tipo'] == 'PERSONALIZADA':
                raise ApiError(
                    "Los planes personalizados se eliminan desde la sección de rutinas personalizadas.",
                    400,
                )

            # Un plan especializado es semanal: se retira completo para no
            # dejar una planificación incompleta.
            cursor.execute(
                "DELETE a FROM asignaciones a "
                "JOIN rutinas r ON a.id_rutina = r.id_rutina "
                "WHERE a.id_cliente = %s AND r.tipo = 'ESPECIALIZADA'",
                (id_cliente,),
            )
            conn.commit()
            return 'ESPECIALIZADA'
        finally:
            cursor.close()
            conn.close()


class AsistenciaRepository:
    def __init__(self):
        self.db = DatabaseManager.get_instance()

    def registrar(self, id_cliente, fecha_hora, fecha):
        conn = self.db.get_connection()
        cursor = conn.cursor()
        try:
            query = "INSERT INTO asistencias (id_cliente, fecha_hora, fecha) VALUES (%s, %s, %s)"
            cursor.execute(query, (id_cliente, fecha_hora, fecha))
            conn.commit()
            return True
        except mysql.connector.IntegrityError:
            conn.rollback()
            return False
        finally:
            cursor.close()
            conn.close()

    def listar_cliente(self, id_cliente, limite=12):
        conn = self.db.get_connection()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute('''SELECT id_asistencia, fecha_hora, fecha
                              FROM asistencias WHERE id_cliente=%s
                              ORDER BY fecha_hora DESC LIMIT %s''', (id_cliente, limite))
            filas = cursor.fetchall()
            cursor.execute('SELECT COUNT(*) AS total FROM asistencias WHERE id_cliente=%s', (id_cliente,))
            total = cursor.fetchone()['total']
            return {'total': total,
                    'historial': [{'id_asistencia': a['id_asistencia'],
                                  'fecha': a['fecha'].isoformat(),
                                  'fecha_hora': a['fecha_hora'].isoformat()}
                                 for a in filas]}
        finally:
            cursor.close()
            conn.close()

    def obtener_reporte(self):
        conn = self.db.get_connection()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute("SELECT * FROM vw_reporte_asistencia")
            return cursor.fetchall()
        finally:
            cursor.close()
            conn.close()
