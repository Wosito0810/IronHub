> **Novedades 3.2:** portada de acceso, registro público de clientes, selector cliente/administrador, nuevo logo e interfaz adaptable. Antes de instalar consulta `INSTALAR_3_2_LEEME.txt` y `NOVEDADES_3_2.md`. No requiere migración nueva si ya instalaste la 3.1.

> **NUEVO — IRONHUB 3.1:** antes de modificar una instalación funcional, abre
> `GUIA_INSTALACION_3_1.txt` y `NOVEDADES_3_1.md`. Ejecuta únicamente
> `database/migracion_3_1.sql`, nunca el script de creación inicial.
> Este paquete preserva el estilo 3.0 y los módulos anteriores.

# IRONHUB: Sistema de Gestión de Rutinas y Asistencia para Gimnasios

**Proyecto de Aula – Diseño de Software 1**  
**Integrantes:** Moisés Baquero, Sergio Cristancho, David Vargas  

---

> **Versión 2.0 — Importante para quienes ya tienen IRONHUB funcionando:**
> Lee primero `GUIA_DE_INSTALACION.txt`. Ejecuta únicamente
> `database/migracion_propuestas.sql` para añadir las propuestas.
> **NO ejecutes `script_rionhub.sql` de nuevo:** contiene `DROP DATABASE` y elimina tus datos.
> El frontend usa el backend local en el **puerto 5050**, no 5000.
> Para tener fotos guardadas en el computador ejecuta `py frontend\descargar_imagenes.py`
> o haz doble clic en `DESCARGAR_IMAGENES.bat` (requiere internet una vez).

## 📋 1. Descripción General del Proyecto
IRONHUB es una solución web desarrollada para reemplazar el uso de cuadernos, cartones y archivos de Excel en la gestión operativa de gimnasios, especialmente durante las horas pico. Permite a los administradores/entrenadores estructurar planes de entrenamiento personalizados, gestionar clientes, controlar catálogos de ejercicios y supervisar la asistencia en tiempo real, mientras que los deportistas pueden consultar sus rutinas y registrar su asistencia directamente desde sus teléfonos móviles en la zona de pesas.

---

## ⚙️ 2. Arquitectura y Tecnologías
El sistema está construido bajo una **Arquitectura en Capas** estricta, garantizando bajo acoplamiento y alta cohesión:
- **Capa de Presentación (Frontend):** HTML5, CSS3 y JavaScript puro (Vanilla JS), optimizado con diseño responsivo Mobile-First.
- **Capa de Servicios (API RESTful):** Desarrollada en Python utilizando el microframework Flask, exponiendo endpoints limpios mapeados a métodos HTTP (`GET`, `POST`, `PUT`, `DELETE`).
- **Capa de Lógica de Negocio:** Implementada en Python aplicando estrictamente los principios de la **Programación Orientada a Objetos (POO)**.
- **Capa de Acceso a Datos (DAO / Repositorios):** Diseñada con un gestor de conexiones basado en **Pool** para soportar alta concurrencia en horas pico sin bloqueos en la base de datos.
- **Persistencia:** Base de datos relacional normalizada hasta la 3FN alojada en **MySQL 8.0** y administrada con **MySQL Workbench**.

---

## 📂 3. Estructura del Repositorio
```text
ironhub_project/
│
├── database/
│   ├── script_rionhub.sql                  # Creación completa de BD desde cero (tablas, FKs, índices, planes y ejercicios)
│   ├── migracion_rutinas.sql               # Migración base del módulo de rutinas (conserva los datos)
│   └── migracion_planes_semanales.sql      # Planes semanales: días, descansos y asignación automática
├── backend/
│   ├── app.py                   # Servidor Flask y controladores de la API RESTful
│   ├── services.py              # Lógica de negocio (POO: Autenticación, Rutinas, Ejercicios, Asistencia)
│   ├── repositories.py          # Capa de Acceso a Datos (DAO) con transacciones
│   ├── security.py              # Generación y validación del token JWT de sesión
│   ├── errors.py                # Errores controlados de la API (mensaje + código HTTP)
│   ├── database.py              # Singleton y Gestor de Conexiones Pool MySQL
│   └── requirements.txt         # Dependencias de Python
└── frontend/
    ├── index.html               # Interfaz responsiva web y consumo de API con Fetch
    └── ejercicios_demo.js       # Demostraciones, instrucciones y consejos por ejercicio
```

---

## 🚀 4. Instrucciones de Ejecución

### Paso 1: Configurar la Base de Datos
**Opción A — Instalación nueva:** abre **MySQL Workbench** y ejecuta
`database/script_rionhub.sql`. Crea la base `ironhub_db` con su esquema,
catálogo de ejercicios, planes especializados y usuarios de prueba.

**Opción B — Base de datos existente:** ejecuta en este orden:

1. `database/migracion_rutinas.sql`: añade las columnas y tablas base del
   módulo de rutinas.
2. `database/migracion_planes_semanales.sql`: crea `rutina_dias` y
   `rutina_dia_ejercicios`, define los 7 días de los 6 planes y convierte las
   asignaciones especializadas antiguas en planes semanales completos.

Ninguno de los dos scripts borra usuarios, rutinas personalizadas ni
asistencias. Ambos son idempotentes (se pueden ejecutar más de una vez sin
duplicar datos).

### Paso 2: Ejecutar el Backend en Python
1. Instala Python 3.10 o superior.
2. Abre una terminal en la carpeta `backend/` e instala las dependencias:
   ```bash
   pip install -r requirements.txt
   ```
3. Verifica la conexión en `backend/.env` (`DB_HOST`, `DB_PORT`, `DB_NAME`,
   `DB_USER`, `DB_PASSWORD`) e inicia el servidor Flask:
   ```bash
   python app.py
   ```
   El servidor correrá en `http://127.0.0.1:5050`.

### Paso 3: Probar el Frontend
1. Abre el archivo `frontend/index.html` en tu navegador web o mediante un
   servidor local (Live Server). También puedes usar
   `python -m http.server 8000` dentro de `frontend/`.
2. Inicia sesión con cualquiera de los usuarios de prueba, por ejemplo
   `carlos@ironhub.com` / `1234` o `ana@ironhub.com` / `1234`.
3. En **Rutina del Día** selecciona un día y consulta tus rutinas y descansos.
4. En cada ejercicio de **Rutina del Día** pulsa **👁️ Ver ejercicio** para abrir
   su demostración con imágenes, instrucciones paso a paso y recomendaciones
   técnicas. Al cerrar con **Volver a rutina del día**, la planificación y tu
   progreso permanecen intactos. Este botón aparece individualmente junto al
   nombre de cada ejercicio, sin importar el plan o el día.
5. En **Rutinas Especializadas** pulsa **Ver ejercicios** para revisar la
   planificación semanal completa. Al pulsar **Elegir Plan**, el plan se guarda
   automáticamente para los 7 días y reemplaza el plan especializado anterior.
   No se abre ningún selector de días.
6. En **Plan Personalizado** marca ejercicios, ajusta series/reps, escribe un
   nombre, elige el día y pulsa **Guardar Rutina en la Base de Datos**.

### Demostraciones por ejercicio
La sección **Rutina del Día** muestra el botón **👁️ Ver ejercicio** al lado del
nombre de cada ejercicio. El modal incluye:

- Dos imágenes de demostración (posición inicial y final) del ejercicio
  concreto, alojadas en **Free Exercise DB** (Unlicense / dominio público).
- Instrucciones paso a paso y recomendaciones técnicas en español.
- Un enlace para buscar un video demostrativo del ejercicio en YouTube.

La información está en `frontend/ejercicios_demo.js`, indexada por el nombre
exacto del ejercicio. Esto permite que funcione con los 50 ejercicios del
catálogo, con planes especializados y con rutinas personalizadas. Si un
ejercicio nuevo no tiene entrada en ese archivo, el modal sigue abriéndose con
una guía técnica de respaldo. Abrir y cerrar el modal no realiza peticiones ni
modifica la rutina.

---

## 🧩 5. Módulo de Rutinas (API)

Todas las rutas de rutinas requieren la cabecera
`Authorization: Bearer <token>` obtenida en `/api/auth/login`. El backend
resuelve internamente el `id_cliente` del usuario autenticado, de modo que
nadie puede leer, editar ni eliminar rutinas de otro usuario.

| Método | Ruta | Descripción |
| --- | --- | --- |
| `POST` | `/api/auth/login` | Inicia sesión y devuelve el token JWT |
| `GET` | `/api/auth/perfil` | Devuelve el usuario autenticado y su `id_cliente` |
| `GET` | `/api/planes-especializados` | Lista los planes con sus 7 días, enfoque, descansos y ejercicios |
| `POST` | `/api/rutinas/especializadas` | Activa un plan semanal completo (`id_rutina`); reemplaza los 7 días del plan especializado anterior |
| `DELETE` | `/api/rutinas/especializadas/activa` | Retira el plan especializado semanal del usuario |
| `POST` | `/api/rutinas/personalizada` | Crea un plan personalizado y lo guarda en un día |
| `GET` | `/api/rutinas/personalizadas` | Lista los planes personalizados del usuario |
| `PUT` | `/api/rutinas/personalizadas/<id>` | Edita nombre, día y ejercicios del plan |
| `DELETE` | `/api/rutinas/personalizadas/<id>` | Elimina un plan personalizado del usuario |
| `GET` | `/api/rutinas/dia/<1-7>` | Devuelve las rutinas del día, con descansos y ejercicios |
| `DELETE` | `/api/asignaciones/<id>` | Compatibilidad: retira el plan semanal especializado completo |
| `POST` | `/api/asistencia` | Registra la asistencia del usuario autenticado |
| `GET` | `/api/ejercicios` | Catálogo completo de ejercicios |

### Reglas de negocio aplicadas
- Los planes especializados son **programas semanales predeterminados**: cada
  plan define sus 7 días, con enfoque y ejercicios o descanso.
- Al elegir un plan especializado se guarda automáticamente para los 7 días.
  No se solicita día y se reemplaza únicamente el plan especializado anterior.
- Las rutinas personalizadas **no se borran** al cambiar de plan especializado;
  pueden convivir con él en el mismo día.
- Los días de descanso se muestran como tales y no contienen ejercicios.
- El nombre del plan personalizado es obligatorio y debe tener al menos un
  ejercicio; series y repeticiones se validan entre 1 y 99.
- No se puede repetir el mismo plan personalizado con el mismo nombre en el
  mismo día (respuesta `409`); sí se permite en otro día.
- La creación y edición de planes son **transaccionales**: si falla un detalle,
  no queda una rutina incompleta en la base de datos.
- Cada plan personalizado queda asociado a su dueño
  (`rutinas.id_usuario_propietario`), y las consultas siempre filtran por el
  cliente del token.

### Planes especializados disponibles
1. **Fuerza 5x5 (3 Días - Fuerza Máxima)**: sentadilla, press banca, remo,
   press militar y peso muerto con progresión A/B (lunes, miércoles y viernes).
2. **Rutina Weider (5 Días - Hipertrofia Torso)**: división por grupo muscular
   (pecho, espalda, hombros, piernas y brazos).
3. **Push-Pull-Legs**: empuje, tirón y pierna dos veces por semana.
4. **Torso-Pierna (Énfasis Glúteos y Piernas)**: cuatro sesiones con prioridad
   al tren inferior.
5. **Full Body (Recomposición Corporal)**: tres sesiones de cuerpo completo.
6. **Arnold Split (6 Días - Volumen)**: pecho-espalda, hombros-brazos y piernas
   dos veces por semana, con un día de descanso.

Los planes **Fuerza 5x5** y **Arnold Split** se incorporaron como alternativas
de fuerza y de volumen respectivamente, siguiendo programas semanales
ampliamente documentados, para no repetir los enfoques que ya cubrían los
planes anteriores.


---

## Novedades 2.0

- **Diseño premium oscuro**, mejorado para PC y móvil (`frontend/ironhub-pro.css`).
- **Biblioteca visual** con fichas, buscador, filtros musculares y favoritos guardados localmente en el navegador.
- **Fotografías de ejercicios**: cada ficha intenta primero la foto local en
  `frontend/assets/ejercicios/<slug>/0.jpg`; si no la encuentra intenta la
  versión en GitHub y, finalmente, un respaldo SVG. Las fotografías reales
  **no están dentro del ZIP**: se descargan con `DESCARGAR_IMAGENES.bat`
  o `py frontend/descargar_imagenes.py` desde una conexión a internet.
- **Proponer ejercicio**: clientes suben un nombre, una explicación, grupo
  muscular y foto/video (JPG, PNG, WEBP, MP4 o WEBM, máximo 25 MB).
  La propuesta solo aparece en el catálogo después de ser aprobada por
  un administrador; el archivo aprobado se muestra como multimedia del ejercicio.
- **Moderación**: los administradores ven propuestas pendientes, revisan
  material adjunto y aprueban/rechazan en una nueva pestaña.
- **Centro de ayuda** flotante, estadísticas e historial de asistencias.
- **Mejora básica de contraseñas**: nuevas cuentas se guardan con hash; los
  usuarios de demostración existentes se actualizan al iniciar sesión. El
  registro público ya no puede asignar el rol ADMIN.

### Migración para actualizar una instalación existente

**1. Haz una copia de seguridad. 2. Conserva tu `backend/.env` y `.venv`.
3. Copia los archivos de esta versión encima del proyecto existente.
4. Ejecuta una sola vez en Workbench `database/migracion_propuestas.sql`.
5. Instala dependencias, inicia `app.py` y actualiza Live Server.**

Comandos desde `backend` en Windows:

```powershell
.venv\Scripts\python.exe -m pip install -r requirements.txt
.venv\Scripts\python.exe app.py
```

### API nueva

| Método | Ruta | Uso |
| --- | --- | --- |
| POST | `/api/propuestas` | Enviar formulario `multipart/form-data` autenticado con campos `nombre`, `descripcion`, `id_grupo`, `archivo` |
| GET | `/api/propuestas/mias` | Propuestas enviadas por el usuario |
| GET | `/api/propuestas/pendientes` | Moderación (solo administradores) |
| PATCH | `/api/propuestas/<id>/revision` | Aprobar/rechazar con JSON `{"decision":"APROBADA"}` (administradores) |
| GET | `/api/propuestas/<id>/archivo` | Ver media con autorización según usuario y estado |
| GET | `/api/propuestas/<id>/archivo-publico` | Ver archivo únicamente si está aprobado |
| GET | `/api/propuestas/medios-aprobados` | Vincular el catálogo a fotos/videos aprobados |
| GET | `/api/asistencia/mia` | Número total y últimos 12 registros del usuario |

La versión está destinada a **desarrollo local**. No se considera lista para
Internet sin endurecimiento adicional (HTTPS, antivirus de archivos, control
de abuso, cuentas y contraseñas de demostración reemplazadas, respaldos y
clave JWT fuerte en `.env`). Para preservar las propuestas no olvides respaldar
`backend/uploads/propuestas` además de MySQL.
