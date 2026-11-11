@echo off
cd /d "%~dp0"
echo IRONHUB 3.1: RESPALDO DE LA BASE DE DATOS Y LOS MULTIMEDIA
if exist "backend\.venv\Scripts\python.exe" (
  "backend\.venv\Scripts\python.exe" backend\respaldo.py
) else (
  py backend\respaldo.py
)
echo.
pause
