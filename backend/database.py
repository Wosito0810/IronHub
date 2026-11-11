import os
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
            "pool_size": 10,
            "pool_reset_session": True
        }
        self.connection_pool = mysql.connector.pooling.MySQLConnectionPool(**db_config)
        DatabaseManager._instance = self

    @staticmethod
    def get_instance():
        if DatabaseManager._instance is None:
            DatabaseManager()
        return DatabaseManager._instance

    def get_connection(self):
        return self.connection_pool.get_connection()
