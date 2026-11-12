import os
import threading
from urllib.parse import parse_qs, unquote, urlparse

import mysql.connector
from mysql.connector import pooling
from dotenv import load_dotenv

load_dotenv()


def config_desde_url(url):
    """Convierte una URI mysql://... en parametros de conexion.

    Soporta el formato que entregan Aiven, Railway, TiDB y la mayoria de
    proveedores:

        mysql://usuario:clave@host:puerto/base?ssl-mode=REQUIRED
    """
    partes = urlparse((url or "").strip())
    if partes.scheme not in ("mysql", "mysql2", "mariadb"):
        return None

    parametros = {
        "host": partes.hostname,
        "port": partes.port or 3306,
        "user": unquote(partes.username) if partes.username else None,
        "password": unquote(partes.password) if partes.password else None,
        "database": (partes.path or "").lstrip("/") or None,
    }

    consulta = {
        clave.lower(): valores[0].lower()
        for clave, valores in parse_qs(partes.query).items()
    }
    ssl_mode = consulta.get("ssl-mode", consulta.get("sslmode", ""))
    ssl_query = consulta.get("ssl", "")
    parametros["ssl"] = (
        ssl_mode in ("required", "verify_ca", "verify_identity")
        or ssl_query not in ("", "false", "0", "disabled")
    )
    return parametros


def configuracion_conexion():
    """Parametros de conexion a partir del entorno.

    Prioridad: MYSQL_URL / DATABASE_URL / DB_URL (una sola cadena) y, si no
    existe, las variables DB_HOST, DB_PORT, DB_NAME, DB_USER y DB_PASSWORD.
    """
    db_config = {
        "host": os.getenv("DB_HOST", "localhost"),
        "port": int(os.getenv("DB_PORT", 3306)),
        "database": os.getenv("DB_NAME", "ironhub_db"),
        "user": os.getenv("DB_USER", "root"),
        "password": os.getenv("DB_PASSWORD", ""),
    }

    url = (
        os.getenv("MYSQL_URL")
        or os.getenv("DATABASE_URL")
        or os.getenv("DB_URL")
        or ""
    ).strip()
    desde_url = config_desde_url(url) if url else None
    if desde_url:
        for clave in ("host", "port", "user", "password", "database"):
            if desde_url.get(clave):
                db_config[clave] = desde_url[clave]

    # Bases de datos en la nube (Aiven, TiDB, Railway, etc.) exigen TLS.
    # En local la variable no existe y la conexion sigue igual.
    usar_ssl = bool(desde_url and desde_url.get("ssl"))
    if os.getenv("DB_SSL", "").strip().lower() in ("1", "true", "yes", "si"):
        usar_ssl = True
    if usar_ssl:
        db_config.update({
            "ssl_disabled": False,
            "ssl_verify_cert": True,
            "ssl_verify_identity": False,
        })
        ca = os.getenv("DB_SSL_CA", "").strip()
        if ca:
            db_config["ssl_ca"] = ca
        else:
            # Muchos proveedores usan certificados que no estan en el
            # almacen del runtime; se cifra sin verificar la cadena.
            db_config["ssl_verify_cert"] = False

    timeout = os.getenv("DB_CONNECT_TIMEOUT", "").strip()
    if timeout:
        db_config["connection_timeout"] = int(timeout)

    return db_config


class DatabaseManager:
    _instance = None

    def __init__(self):
        if DatabaseManager._instance is not None:
            raise Exception("Esta clase es un singleton. Use DatabaseManager.get_instance()")

        db_config = configuracion_conexion()
        db_config.update({
            "pool_name": "ironhub_pool",
            "pool_size": int(os.getenv(
                "DB_POOL_SIZE", "2" if os.getenv("VERCEL") else "10"
            )),
            "pool_reset_session": True,
        })

        self._db_config = db_config
        self._lock = threading.Lock()
        # El pool se crea en la primera consulta, no al importar el modulo.
        # Asi la aplicacion arranca aunque la base este momentaneamente
        # inaccesible y responde con un error claro en vez de caerse.
        self.connection_pool = None
        DatabaseManager._instance = self

    @staticmethod
    def get_instance():
        if DatabaseManager._instance is None:
            DatabaseManager()
        return DatabaseManager._instance

    def _crear_pool(self):
        self.connection_pool = mysql.connector.pooling.MySQLConnectionPool(**self._db_config)

    def get_connection(self):
        if self.connection_pool is None:
            with self._lock:
                if self.connection_pool is None:
                    self._crear_pool()
        return self.connection_pool.get_connection()
