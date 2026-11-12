# Despliegue de IRONHUB en Vercel

Esta guía cubre lo necesario para que el repositorio se despliegue en Vercel
sin errores de build y con el frontend y la API funcionando en el mismo dominio.

---

## 1. Qué se agregó

| Archivo | Para qué |
|---|---|
| `index.py` | Punto de entrada que Vercel detecta como Flask. Carga `backend/app.py` sin mover nada del proyecto. |
| `requirements.txt` | Dependencias que instala Vercel (mismas de `backend/requirements.txt`). |
| `.python-version` | Fija Python 3.12, la versión por defecto de Vercel. |
| `vercel.json` | Incluye la carpeta `backend/` en el bundle de la función. |
| `public/` | Copia del frontend; Vercel solo sirve estáticos desde `public/**`. |
| `sincronizar_frontend.py` | Regenera `public/` desde `frontend/`. |

## 2. Qué se corrigió

1. **El frontend llamaba a `http://127.0.0.1:5050`**, imposible desde un navegador
   en internet. Ahora usa `/api` cuando corre en cualquier dominio y mantiene
   `127.0.0.1:5050` en local.
2. **El backend creaba el pool de MySQL al importarse.** Si la base no estaba
   disponible, la función moría al arrancar y Vercel devolvía
   `FUNCTION_INVOCATION_FAILED`. Ahora el pool se crea en la primera consulta.
3. **`security.py` escribía `.jwt_secret` en disco.** En Vercel el disco es de
   solo lectura y el import fallaba. Ahora usa `JWT_SECRET` del entorno y, si no
   existe, genera una clave efímera sin caerse.
4. **Las subidas iban a `backend/uploads`** (solo lectura en Vercel). Ahora usan
   `/tmp` en Vercel y `backend/uploads` en local.
5. **Errores de MySQL** ahora responden `503` con un JSON claro en vez de un
   error genérico.

---

## 3. Requisito obligatorio: base de datos en la nube

Vercel **no puede conectarse a `localhost`**. La MySQL del computador no es
accesible desde la función. Hay que usar una MySQL hospedada (Aiven, TiDB
Cloud, Railway, o la que asigne el docente) y cargarle el esquema:

```
database/script_rionhub.sql
```

Si la base viene de una versión anterior, aplicar también las migraciones de
`database/` en orden.

### Variables de entorno (Vercel → Settings → Environment Variables)

La forma más corta es una sola variable con la *Service URI* del proveedor:

```
MYSQL_URL=mysql://usuario:clave@host:puerto/base?ssl-mode=REQUIRED
```

Si `MYSQL_URL` (o `DATABASE_URL`) existe, tiene prioridad sobre las variables
sueltas. El backend detecta `ssl-mode=REQUIRED` y activa TLS automáticamente.

También se pueden usar las variables por separado:

| Variable | Ejemplo | Notas |
|---|---|---|
| `DB_HOST` | `mysql-xxxx.aivencloud.com` | Host público del proveedor. |
| `DB_PORT` | `12345` | El que indique el proveedor. |
| `DB_NAME` | `ironhub_db` | Nombre de la base. |
| `DB_USER` | `avnadmin` | Usuario. |
| `DB_PASSWORD` | `********` | Contraseña. |
| `DB_SSL` | `true` | Obligatorio en casi todos los proveedores. |
| `DB_POOL_SIZE` | `2` | Vercel abre varias instancias; no usar 10. |
| `JWT_SECRET` | frase larga y aleatoria | Sin esto, las sesiones se pierden entre instancias. |

`DB_SSL_CA` es opcional: ruta al certificado del proveedor si exige verificar
la cadena.

### Cargar el esquema en la base remota

Con la Service URI a mano, no hace falta instalar MySQL Workbench:

```bash
python importar_base_nube.py "mysql://usuario:clave@host:puerto/base?ssl-mode=REQUIRED"
```

El script crea la base si no existe, ejecuta `database/script_rionhub.sql`
(respetando la base de la URI, sin borrar nada) y verifica las tablas. Al final
imprime las variables que hay que pegar en Vercel.

---

## 4. Pasos en Vercel

1. **Framework Preset: `Flask`.**
   Si el proyecto ya se creó antes y quedó como *Other*, cámbialo en
   **Settings → General → Framework Preset**. Este es el punto que más falla:
   con *Other*, Vercel no construye la función de Python.

2. **Root Directory:** la raíz del repositorio (`.`).

3. **Build Command, Output Directory e Install Command:** dejarlos vacíos
   (los valores por defecto de Flask).

4. Cargar las variables de entorno del punto 3.

5. **Redeploy** (Deployments → ⋯ → Redeploy, sin caché).

También se puede desplegar por CLI:

```bash
npx vercel --prod
```

---

## 5. Verificación después del despliegue

1. `https://TU-PROYECTO.vercel.app/api/health` debe responder:

   ```json
   {"estado": "ok", "base_datos": "ok"}
   ```

   Si `base_datos` es `error`, el campo `codigo` indica la causa:
   `2003` no hay conexión, `1045` usuario o clave incorrectos,
   `1049` la base no existe, `2026` problema de SSL.

2. Abrir la raíz: debe cargar el login de IRONHUB.
3. Iniciar sesión con un usuario cargado en la base en la nube.
4. Si el login responde `503`, la función está bien y el problema es la
   conexión a MySQL: revisar `DB_HOST`, `DB_PORT`, `DB_SSL` y que la base
   acepte conexiones externas.

---

## 6. Limitaciones propias de Vercel (no son errores)

- **Cuerpo máximo de 4.5 MB por request.** La app permite 25 MB de video, pero
  Vercel corta antes. Para videos grandes habría que usar almacenamiento
  externo (S3, Cloudinary, etc.).
- **`/tmp` no es persistente.** Los archivos subidos funcionan mientras la
  instancia esté caliente, pero se pierden al reiniciarse. Las propuestas
  guardadas en la base sí persisten; el archivo adjunto no.
- **Cold start.** La primera petición después de un rato inactivo tarda algo
  más.
- **Pool de conexiones.** Cada instancia abre su propio pool; por eso
  `DB_POOL_SIZE=2`.

---

## 7. Si se modifica el frontend

El código se edita en `frontend/` como siempre. Antes de hacer commit:

```bash
python sincronizar_frontend.py
```

Eso actualiza `public/`, que es lo que Vercel publica. Si no se ejecuta, el
sitio desplegado sigue mostrando la versión anterior.
