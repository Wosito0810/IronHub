"""Carga el esquema de IRONHUB en una MySQL remota (Aiven, TiDB, Railway...).

Uso:
    python importar_base_nube.py "mysql://usuario:clave@host:puerto/base?ssl-mode=REQUIRED"

Si no se pasa la URI, toma MYSQL_URL, DATABASE_URL o las variables DB_*.
El script NO borra bases existentes: quita del .sql el DROP DATABASE y crea
las tablas dentro de la base indicada en la URI.
"""
import os
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent
sys.path.insert(0, str(RAIZ / "backend"))

import mysql.connector  # noqa: E402

from database import configuracion_conexion  # noqa: E402

ARCHIVO_SQL = RAIZ / "database" / "script_rionhub.sql"


def dividir_sql(texto):
    """Separa por ; respetando comillas simples, dobles y backticks."""
    sentencias = []
    actual = []
    comilla = None
    i = 0
    while i < len(texto):
        caracter = texto[i]
        if comilla:
            actual.append(caracter)
            if caracter == "\\" and comilla in ("'", '"'):
                if i + 1 < len(texto):
                    actual.append(texto[i + 1])
                    i += 2
                    continue
            elif caracter == comilla:
                # '' dentro de una cadena es una comilla escapada
                if comilla == "'" and i + 1 < len(texto) and texto[i + 1] == "'":
                    actual.append(texto[i + 1])
                    i += 2
                    continue
                comilla = None
        else:
            if caracter in ("'", '"', "`"):
                comilla = caracter
                actual.append(caracter)
            elif caracter == ";":
                sentencia = "".join(actual).strip()
                if sentencia:
                    sentencias.append(sentencia)
                actual = []
            else:
                actual.append(caracter)
        i += 1

    sentencia = "".join(actual).strip()
    if sentencia:
        sentencias.append(sentencia)
    return sentencias


def tiene_sql(sentencia):
    """True si la sentencia tiene algo aparte de comentarios."""
    for linea in sentencia.splitlines():
        limpia = linea.strip()
        if limpia and not limpia.startswith("--"):
            return True
    return False


def main():
    argumento = sys.argv[1].strip() if len(sys.argv) > 1 else ""
    if "://" in argumento:
        os.environ["MYSQL_URL"] = argumento

    config = configuracion_conexion()
    base = config.get("database") or "ironhub_db"
    resto = {clave: valor for clave, valor in config.items() if clave != "database"}

    host = config.get("host") or "localhost"
    if host in ("localhost", "127.0.0.1", "::1") and "--local" not in sys.argv:
        print("La configuracion apunta a localhost. Ese no es el problema de Vercel.")
        print("Pasa la URI de la base remota o usa --local si de verdad quieres la local.")
        return 1

    if not ARCHIVO_SQL.is_file():
        print("No se encuentra", ARCHIVO_SQL)
        return 1

    print(f"Destino: {host}:{config.get('port')} / base: {base}")
    print("Conectando...")

    try:
        try:
            conexion = mysql.connector.connect(database=base, **resto)
        except mysql.connector.Error as error:
            if error.errno != 1049:  # base inexistente -> se crea
                raise
            conexion = mysql.connector.connect(**resto)
            with conexion.cursor() as cursor:
                cursor.execute(
                    f"CREATE DATABASE `{base}` "
                    "CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
                )
            conexion.commit()
            conexion.close()
            conexion = mysql.connector.connect(database=base, **resto)
            print("Base creada:", base)
    except mysql.connector.Error as error:
        print("ERROR de conexion:", error)
        print("Revisa host, puerto, usuario, clave y que la base acepte conexiones externas.")
        return 1

    sql = ARCHIVO_SQL.read_text(encoding="utf-8")
    # El script original elimina y recrea ironhub_db; aqui se respeta la base
    # de la URI y solo se crean las tablas que falten.
    sql = re.sub(r"(?im)^\s*(DROP DATABASE|CREATE DATABASE|USE\s)[^;]*;", "", sql)
    sentencias = [s for s in dividir_sql(sql) if tiene_sql(s)]

    print(f"Ejecutando {len(sentencias)} sentencias...")
    cursor = conexion.cursor()
    for numero, sentencia in enumerate(sentencias, 1):
        try:
            cursor.execute(sentencia)
            if cursor.with_rows:
                cursor.fetchall()
        except mysql.connector.Error as error:
            print(f"\nERROR en la sentencia {numero}: {error}")
            print(sentencia[:300])
            cursor.close()
            conexion.close()
            return 1

    conexion.commit()

    cursor.execute("SHOW TABLES")
    tablas = [fila[0] for fila in cursor.fetchall()]
    print(f"\nOK: {len(tablas)} tablas en {base}")

    for tabla in ("roles", "usuarios", "ejercicios", "rutinas"):
        if tabla in tablas:
            cursor.execute(f"SELECT COUNT(*) FROM `{tabla}`")
            print(f"  {tabla}: {cursor.fetchone()[0]} filas")

    cursor.close()
    conexion.close()

    print("\nVariables para Vercel (Production y Preview):")
    print(f"  MYSQL_URL=mysql://{config.get('user')}:********@{host}:{config.get('port')}/{base}")
    print("  DB_SSL=true")
    print("  JWT_SECRET=<frase larga y aleatoria>")
    print("  DB_POOL_SIZE=2")
    return 0


if __name__ == "__main__":
    sys.exit(main())
