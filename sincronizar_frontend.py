"""Copia frontend/ a public/ para el despliegue en Vercel.

Vercel sirve los archivos estaticos desde public/**. El frontend se sigue
editando en frontend/ (como siempre); despues de cambiar algo ahi, ejecutar:

    python sincronizar_frontend.py

y hacer commit tambien de la carpeta public/.
"""
import shutil
from pathlib import Path

RAIZ = Path(__file__).resolve().parent
ORIGEN = RAIZ / "frontend"
DESTINO = RAIZ / "public"

IGNORAR = shutil.ignore_patterns("*.py", "__pycache__", ".venv")

if not ORIGEN.is_dir():
    raise SystemExit("No existe la carpeta frontend/")

if DESTINO.exists():
    shutil.rmtree(DESTINO)

shutil.copytree(ORIGEN, DESTINO, ignore=IGNORAR)
print(f"OK: {ORIGEN} -> {DESTINO}")
