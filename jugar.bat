@echo off
rem Lanza el juego Bajan! directamente, sin abrir el editor.
setlocal
set "GODOT=%~dp0herramientas\godot\Godot_v4.7.2-stable_win64.exe"
set "GODOT_CONSOLA=%~dp0herramientas\godot\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GODOT%" (
  echo No se encontro Godot en "%GODOT%".
  echo Revisa README.md, seccion "Instalacion".
  pause
  exit /b 1
)
rem La primera vez hay que importar los recursos (traducciones, etc.).
if not exist "%~dp0.godot\imported" (
  echo Importando recursos por primera vez...
  "%GODOT_CONSOLA%" --headless --path "%~dp0." --import
)
start "" "%GODOT%" --path "%~dp0."
