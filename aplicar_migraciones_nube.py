"""Aplica las migraciones aditivas de IRONHUB en una MySQL remota.

Uso:
    python aplicar_migraciones_nube.py
    python aplicar_migraciones_nube.py "mysql://usuario:clave@host:puerto/base?ssl-mode=REQUIRED"

Sin argumentos usa MYSQL_URL / DATABASE_URL / DB_* y aplica las migraciones
que solo crean tablas nuevas (propuestas y 3.1). Es seguro ejecutarlo varias
veces: las tablas existentes se omiten.
"""
import os
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent
sys.path.insert(0, str(RAIZ / "backend"))

import mysql.connector  # noqa: E402

from database import configuracion_conexion  # noqa: E402
from importar_base_nube import dividir_sql, tiene_sql  # noqa: E402

MIGRACIONES = [
    RAIZ / "database" / "migracion_propuestas.sql",
    RAIZ / "database" / "migracion_3_1.sql",
]

# Errores que significan "ya estaba aplicado".
IGNORABLES = {1050, 1060, 1061}  # tabla/columna/indice existente


def main():
    argumento = sys.argv[1].strip() if len(sys.argv) > 1 else ""
    if "://" in argumento:
        os.environ["MYSQL_URL"] = argumento

    config = configuracion_conexion()
    base = config.get("database") or "ironhub_db"
    resto = {clave: valor for clave, valor in config.items() if clave != "database"}

    print(f"Destino: {config.get('host')}:{config.get('port')} / base: {base}")
    try:
        conexion = mysql.connector.connect(database=base, **resto)
    except mysql.connector.Error as error:
        print("ERROR de conexion:", error)
        return 1

    cursor = conexion.cursor()
    for archivo in MIGRACIONES:
        if not archivo.is_file():
            print("No se encuentra", archivo)
            return 1

        sql = archivo.read_text(encoding="utf-8")
        sql = re.sub(r"(?im)^\s*USE\s[^;]*;", "", sql)
        # Los comentarios pueden contener ";", se quitan antes de dividir.
        sql = re.sub(r"(?m)^\s*--.*$", "", sql)
        sentencias = [s for s in dividir_sql(sql) if tiene_sql(s)]

        print(f"\n{archivo.name}: {len(sentencias)} sentencias")
        for numero, sentencia in enumerate(sentencias, 1):
            try:
                cursor.execute(sentencia)
                if cursor.with_rows:
                    cursor.fetchall()
            except mysql.connector.Error as error:
                if error.errno in IGNORABLES:
                    print(f"  [omitida {numero}] ya existe")
                    continue
                print(f"\nERROR en la sentencia {numero}: {error}")
                print(sentencia[:300])
                cursor.close()
                conexion.close()
                return 1
        conexion.commit()

    cursor.execute("SHOW TABLES")
    tablas = sorted(fila[0] for fila in cursor.fetchall())
    print(f"\nOK: {len(tablas)} tablas en {base}")
    for tabla in ("propuestas_ejercicios", "sesiones_entrenamiento",
                  "series_entrenamiento", "notificaciones"):
        print(f"  {tabla}: {'si' if tabla in tablas else 'NO'}")

    cursor.close()
    conexion.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
