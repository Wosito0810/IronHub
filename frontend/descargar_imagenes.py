"""Descarga las fotos del catálogo Free Exercise DB para uso sin conexión.

Ejecución desde la raíz del proyecto (en la terminal de VS Code):
    py frontend/descargar_imagenes.py

No requiere instalar librerías adicionales de Python.
"""
from __future__ import annotations

import re
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

BASES = [
    'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/',
    'https://cdn.jsdelivr.net/gh/yuhonas/free-exercise-db@main/exercises/'
]
DESTINO = Path(__file__).resolve().parent / 'assets' / 'ejercicios'
FUENTE = Path(__file__).resolve().parent / 'ejercicios_demo.js'


def obtener_ejercicios():
    texto = FUENTE.read_text(encoding='utf-8')
    return sorted(set(re.findall(r'\bdemo:\s*[\"\']([^\"\']+)[\"\']', texto)))


def descargar(item):
    ruta, posicion = item
    destino = DESTINO / ruta / f'{posicion}.jpg'
    if destino.exists() and destino.stat().st_size > 100:
        return ('ya', ruta, posicion)
    for base in BASES:
        url = base + quote(ruta) + f'/{posicion}.jpg'
        try:
            peticion = Request(url, headers={'User-Agent': 'IRONHUB-Local-Exercise-Downloader/1.0'})
            with urlopen(peticion, timeout=18) as resp:
                contenido = resp.read(5_000_001)
            if len(contenido) > 5_000_000 or not contenido.startswith(b'\xff\xd8\xff'):
                continue
            destino.parent.mkdir(parents=True, exist_ok=True)
            destino.write_bytes(contenido)
            return ('ok', ruta, posicion)
        except (HTTPError, URLError, OSError, TimeoutError):
            continue
    return ('fallo', ruta, posicion)


def main():
    rutas = obtener_ejercicios()
    tareas = [(ruta, idx) for ruta in rutas for idx in (0, 1)]
    print(f'IRONHUB | {len(rutas)} demostraciones distintas, {len(tareas)} imágenes por comprobar.')
    print('Se necesita conexión a internet solamente para esta descarga inicial.\n')
    resumen = {'ok': 0, 'ya': 0, 'fallo': 0}
    errores = []
    with ThreadPoolExecutor(max_workers=4) as cola:
        futuras = [cola.submit(descargar, tarea) for tarea in tareas]
        for futura in as_completed(futuras):
            estado, ruta, numero = futura.result()
            resumen[estado] += 1
            if estado == 'fallo':
                errores.append(f'{ruta}/{numero}.jpg')
    print(f'Descargadas: {resumen["ok"]}. Existentes: {resumen["ya"]}. No disponibles: {resumen["fallo"]}.')
    if errores:
        print('Imágenes que no pudo recuperar (la app mostrará alternativa o respaldo):')
        for e in sorted(errores):
            print(' -', e)
        print('Comprueba conexión a internet y vuelve a ejecutar el script cuando puedas.')
    else:
        print('Listo. Abre Live Server y actualiza el navegador con Ctrl + F5.')
    return 0 if resumen['ok'] + resumen['ya'] else 1


if __name__ == '__main__':
    sys.exit(main())
