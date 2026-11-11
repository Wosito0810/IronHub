"""Pruebas de registro público, sin requerir una base MySQL operativa.
Ejecutar desde la raíz del proyecto: backend/.venv/Scripts/python.exe -m unittest discover -s tests -v
"""
from pathlib import Path
from unittest.mock import Mock
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'backend'))
from services import AutenticacionService
from errors import ApiError
from werkzeug.security import check_password_hash


class RegistroClientesTest(unittest.TestCase):
    def setUp(self):
        self.servicio = object.__new__(AutenticacionService)
        self.repo = Mock()
        self.repo.buscar_por_email.return_value = None
        self.repo.guardar.return_value = 51
        self.servicio.usuario_repo = self.repo
        self.datos = dict(nombre='Andrea', apellido='Pérez',
                          email=' Andrea@ejemplo.com ', password='Clave12345', telefono='')

    def test_cliente_nuevo_y_contrasena_segura(self):
        resultado = self.servicio.registrar_usuario({**self.datos, 'id_rol':1, 'activo':1})
        self.assertEqual(resultado,51)
        creado = self.repo.guardar.call_args.args[0]
        self.assertEqual(creado['id_rol'],2)
        self.assertEqual(creado['email'],'andrea@ejemplo.com')
        self.assertNotEqual(creado['password_hash'],self.datos['password'])
        self.assertTrue(check_password_hash(creado['password_hash'],self.datos['password']))

    def test_no_permite_correo_repetido(self):
        self.repo.buscar_por_email.return_value={'id_usuario':7}
        with self.assertRaises(ApiError) as contexto:
            self.servicio.registrar_usuario(self.datos)
        self.assertEqual(contexto.exception.status,409)
        self.repo.guardar.assert_not_called()

    def test_rechaza_contrasena_debil(self):
        for contrasena in ('12345678', 'abcdefgh', 'Corta1', ''):
            with self.subTest(contrasena=contrasena):
                with self.assertRaises(ApiError):
                    self.servicio.registrar_usuario({**self.datos,'password':contrasena})
        self.repo.guardar.assert_not_called()

    def test_rechaza_email_invalido(self):
        with self.assertRaises(ApiError):
            self.servicio.registrar_usuario({**self.datos,'email':'no-hay-arroba'})

    def test_nombre_y_apellido_obligatorios(self):
        with self.assertRaises(ApiError):
            self.servicio.registrar_usuario({**self.datos,'apellido':''})

if __name__ == '__main__':
    unittest.main()
