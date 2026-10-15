@echo off
rem Corre las pruebas automaticas en modo headless (sin ventana).
setlocal
set "GODOT_CONSOLA=%~dp0herramientas\godot\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GODOT_CONSOLA%" (
  echo No se encontro Godot en "%GODOT_CONSOLA%".
  exit /b 1
)
"%GODOT_CONSOLA%" --headless --path "%~dp0." --import
"%GODOT_CONSOLA%" --headless --path "%~dp0." res://pruebas/prueba_etapa0.tscn
exit /b %ERRORLEVEL%
