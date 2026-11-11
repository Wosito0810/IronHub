"""Pruebas de reglas clave para ejecutar con el entorno virtual del proyecto."""
import os
import sys
import unittest
from unittest.mock import patch
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'backend'))
# Permite pruebas sin la base MySQL: el pool real se invoca solo en endpoints.
from errors import ApiError
from extras import _integer, _text, _admin, guardar_entrenamiento, estado_usuario
from flask import Flask, g


class ValidacionesTest(unittest.TestCase):
    def setUp(self):
        self.app = Flask(__name__)

    def test_integer_rechaza_booleanos(self):
        with self.assertRaises(ApiError):
            _integer(True, 'Cantidad')

    def test_integer_limites(self):
        self.assertEqual(_integer('7', 'Día',1,7),7)
        with self.assertRaises(ApiError):
            _integer(8,'Día',1,7)

    def test_texto_requerido(self):
        self.assertEqual(_text('  Sentadilla  ','Nombre',3,100),'Sentadilla')
        with self.assertRaises(ApiError):
            _text('', 'Nombre',3,100)

    def test_cliente_no_es_admin(self):
        with self.app.test_request_context('/'):
            g.id_rol=2
            with self.assertRaises(ApiError) as exc:
                _admin()
            self.assertEqual(exc.exception.status,403)

    def test_entrenamiento_vacio_rechazado_antes_db(self):
        with self.app.test_request_context('/api/entrenamientos', method='POST',
            json={'dia_semana':3,'notas':'','ejercicios':[]}):
            g.id_usuario=7
            with self.assertRaises(ApiError) as exc:
                guardar_entrenamiento.__wrapped__()
            self.assertEqual(exc.exception.status,400)

    def test_clientes_no_pueden_gestionar_usuarios(self):
        with self.app.test_request_context('/api/admin/usuarios/3/estado', method='PATCH',json={'activo':False}):
            g.id_rol=2;g.id_usuario=7
            with self.assertRaises(ApiError) as exc:
                estado_usuario.__wrapped__(3)
            self.assertEqual(exc.exception.status,403)


if __name__=='__main__':
    unittest.main()
