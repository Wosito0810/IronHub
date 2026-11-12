"""Punto de entrada de IRONHUB para Vercel.

Vercel detecta Flask automaticamente cuando encuentra una instancia
llamada ``app`` en ``index.py``. El backend real sigue viviendo en
``backend/app.py`` (no se movio nada), pero ese archivo usa imports
relativos a su propia carpeta (``from services import ...``), asi que
antes de cargarlo agregamos ``backend/`` al path.

Se carga con importlib y un nombre de modulo distinto para evitar
cualquier colision con el ``index.py`` que Vercel importa.
"""
import importlib.util
import os
import sys

RAIZ = os.path.dirname(os.path.abspath(__file__))
BACKEND = os.path.join(RAIZ, "backend")

if BACKEND not in sys.path:
    sys.path.insert(0, BACKEND)

_ruta_app = os.path.join(BACKEND, "app.py")
_spec = importlib.util.spec_from_file_location("ironhub_backend_app", _ruta_app)
_modulo = importlib.util.module_from_spec(_spec)
sys.modules["ironhub_backend_app"] = _modulo
_spec.loader.exec_module(_modulo)

app = _modulo.app

__all__ = ["app"]
