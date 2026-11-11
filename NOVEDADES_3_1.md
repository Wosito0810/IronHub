# IRONHUB 3.1 — Funciones entregadas

**Conserva los módulos de IRONHUB 2.0 y el diseño CSS 3.0.**

- **Mi progreso:** registra sesiones realizadas con series, repeticiones, peso (kg) opcional y notas; reutiliza la rutina de un día y muestra las últimas 30 sesiones y el total semanal.
- **Mi perfil:** modifica nombre, apellido, correo y teléfono; cambia contraseña tras verificar la actual.
- **Avisos:** recibe notificaciones de aprobación/rechazo de propuestas, con contador de no leídas y opción para marcarlas como leídas.
- **Administración:** estadísticas, clientes activos/inactivos, búsqueda, activación/desactivación, revisión de propuestas con multimedia y creación/edición del catálogo.
- **Vista previa:** conserva la previsualización de fotos y videos antes de enviar una propuesta.
- **Seguridad:** las operaciones comprueban el rol y el estado actuales de la cuenta desde MySQL; ya no dependen del rol guardado en un JWT antiguo. Se genera una clave JWT local cuando no se configura `JWT_SECRET`.
- **Copia de seguridad:** script opcional para exportar MySQL y guardar multimedia local en un ZIP privado; también puedes exportar en MySQL Workbench.
- **Pruebas:** archivo `tests/test_validaciones.py` con seis pruebas básicas de permisos y validaciones. No sustituyen una prueba integral con MySQL en tu equipo.

## Archivos clave

- `database/migracion_3_1.sql` — agrega únicamente tres tablas nuevas.
- `backend/extras.py` — endpoints API nuevos.
- `frontend/ironhub-3-1.js` — funciones e interacción nuevas.
- `frontend/index.html` — nuevas vistas.
- `frontend/ironhub-pro.css` — diseño definitivo y estilos nuevos.
- `backend/respaldo.py` + `RESPALDAR_IRONHUB.bat` — respaldo local.

**Antes de instalar, lee `GUIA_INSTALACION_3_1.txt`. No ejecutes `database/script_rionhub.sql` en una instalación existente.**
