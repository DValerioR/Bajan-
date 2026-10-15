@echo off
rem Abre el proyecto Bajan! en el editor de Godot.
setlocal
set "GODOT=%~dp0herramientas\godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo No se encontro Godot en "%GODOT%".
  echo Revisa README.md, seccion "Instalacion".
  pause
  exit /b 1
)
start "" "%GODOT%" --path "%~dp0." --editor
