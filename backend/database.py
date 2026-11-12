import os
import threading

import mysql.connector
from mysql.connector import pooling
from dotenv import load_dotenv

load_dotenv()


class DatabaseManager:
    _instance = None

    def __init__(self):
        if DatabaseManager._instance is not None:
            raise Exception("Esta clase es un singleton. Use DatabaseManager.get_instance()")

        db_config = {
            "host": os.getenv("DB_HOST", "localhost"),
            "port": int(os.getenv("DB_PORT", 3306)),
            "database": os.getenv("DB_NAME", "ironhub_db"),
            "user": os.getenv("DB_USER", "root"),
            "password": os.getenv("DB_PASSWORD", ""),
            "pool_name": "ironhub_pool",
            "pool_size": int(os.getenv(
                "DB_POOL_SIZE", "2" if os.getenv("VERCEL") else "10"
            )),
            "pool_reset_session": True
        }

        # Bases de datos en la nube (Aiven, TiDB, PlanetScale, etc.) exigen
        # TLS. En local la variable no existe y la conexion sigue igual.
        if os.getenv("DB_SSL", "").strip().lower() in ("1", "true", "yes", "si"):
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
