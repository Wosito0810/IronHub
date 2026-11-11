"""Copia de seguridad local: mysqldump + archivos adjuntos (sin .env).

Se ejecuta con RESPALDAR_IRONHUB.bat. Requiere mysqldump (MySQL Server).
"""
from datetime import datetime
from pathlib import Path
from tempfile import NamedTemporaryFile
import os
import shutil
import subprocess
import sys
import zipfile

from dotenv import load_dotenv

BASE = Path(__file__).resolve().parent.parent
load_dotenv(BASE / 'backend' / '.env')


def encontrar_dump():
    program = shutil.which('mysqldump')
    if program:
        return program
    if os.name == 'nt':
        for version in ('9.0', '8.4', '8.3', '8.2', '8.1', '8.0'):
            path = Path(f'C:/Program Files/MySQL/MySQL Server {version}/bin/mysqldump.exe')
            if path.is_file():
                return str(path)
    return None


def codificar_opcion(valor):
    # Archivo de configuración solo en el PC del usuario; jamás incluirlo en el respaldo.
    return str(valor).replace('\\', '\\\\').replace('"','\\"').replace('\n','').replace('\r','')


def respaldar():
    program = encontrar_dump()
    if not program:
        print('No encontré mysqldump. Usa MySQL Workbench: Server > Data Export > Export to Self-Contained File.')
        return 2
    user = os.getenv('DB_USER','root')
    db = os.getenv('DB_NAME','ironhub_db')
    host = os.getenv('DB_HOST','127.0.0.1')
    port = os.getenv('DB_PORT','3306')
    password = os.getenv('DB_PASSWORD','')
    if not db.replace('_','').isalnum():
        print('Nombre de la base de datos no válido.'); return 2
    destino = BASE / 'respaldos'
    destino.mkdir(exist_ok=True)
    output = destino / ('IRONHUB_respaldo_' + datetime.now().strftime('%Y%m%d_%H%M%S') + '.zip')
    config_path = None
    try:
        with NamedTemporaryFile('w', suffix='.cnf', encoding='utf-8', delete=False) as cfg:
            config_path = cfg.name
            cfg.write('[client]\n')
            for key, value in (('user',user),('password',password),('host',host),('port',port)):
                cfg.write(f'{key}="{codificar_opcion(value)}"\n')
        comando = [program, '--defaults-extra-file='+config_path,
                   '--single-transaction','--quick','--default-character-set=utf8mb4',
                   '--routines','--triggers','--databases',db]
        resultado=subprocess.run(comando,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=180)
        if resultado.returncode != 0 or not resultado.stdout:
            print('Error en mysqldump:',resultado.stderr.decode('utf-8',errors='replace')[:450])
            return 1
        with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED) as z:
            z.writestr('ironhub_db.sql', resultado.stdout)
            for carpeta, prefijo in [(BASE/'backend'/'uploads'/'propuestas','media/propuestas'),
                                      (BASE/'frontend'/'assets'/'ejercicios','media/ejercicios')]:
                if carpeta.is_dir():
                    for f in carpeta.rglob('*'):
                        if f.is_file() and not f.is_symlink():
                            z.write(f,prefijo+'/'+str(f.relative_to(carpeta)).replace('\\','/'))
        print('RESPALDO COMPLETO:',output)
        print('IMPORTANTE: mantenlo en un lugar privado. No lo compartas públicamente.')
        return 0
    except Exception as e:
        print('No se pudo completar la copia:', e)
        return 1
    finally:
        if config_path:
            try: os.unlink(config_path)
            except OSError: pass

if __name__=='__main__':
    sys.exit(respaldar())
