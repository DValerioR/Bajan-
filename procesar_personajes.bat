@echo off
rem Convierte los modelos de modelos\fuentes\ (Tripo) en personajes de muneco por piezas en modelos\personajes\.
rem Los nombres y la escala se configuran en modelos\personajes.cfg.
setlocal
set "GODOT_CONSOLA=%~dp0herramientas\godot\Godot_v4.7.2-stable_win64_console.exe"
"%GODOT_CONSOLA%" --headless --path "%~dp0." --script res://scripts/herramientas/procesar_personajes.gd
if errorlevel 1 exit /b 1
"%GODOT_CONSOLA%" --headless --path "%~dp0." --import
