@echo off
cd /d "%~dp0backend"
if exist ".venv\Scripts\python.exe" (
  .venv\Scripts\python.exe app.py
) else (
  echo Primero crea el entorno virtual .venv desde VS Code.
)
pause
