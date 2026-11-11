# IRONHUB 3.2 — Acceso y registro

Esta actualización completa IRONHUB 3.1 con una **portada de acceso para clientes por defecto**, un **registro público exclusivamente para clientes**, un **acceso administrativo diferenciado**, un **logotipo SVG propio**, una **fotografía deportiva local** y una interfaz adaptable inspirada en la referencia compartida.

## Funciones

- Inicio de sesión predeterminado en modo Cliente; selector visible de Administrador, con validación del rol después de autenticar.
- Registro con nombre, apellido, correo, teléfono opcional, contraseña y confirmación.
- Contraseña de 8–128 caracteres que exige al menos una letra y un número; almacenamiento con hash seguro.
- Correo normalizado, control de duplicados, validaciones y mensajes de error legibles.
- Solo se permite el rol CLIENTE (2) desde el registro público. No existe función pública para registrar administradores.
- Navegación lateral en computador y navegación horizontal en pantalla pequeña; conserva las secciones de rutinas, ejercicios, propuestas, progreso, perfil, avisos y administración.
- Botón para mostrar u ocultar contraseñas y acceso a crear cuenta desde la pantalla de inicio.
- Los datos existentes no se borran; **no hay migración SQL nueva para 3.2**.

Para instalarlo, sigue `INSTALAR_3_2_LEEME.txt`. Mantén tu `.env`, `.venv`, las fotos de ejercicios y los archivos enviados por usuarios.

La verificación del navegador y del registro con respuestas simuladas fue satisfactoria, pero las consultas y guardados reales en la base MySQL de tu computador todavía deben validarse allí.
