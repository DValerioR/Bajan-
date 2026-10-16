@echo off
rem Convierte los modelos de modelos\fuentes\ (Tripo) en personajes de muneco por piezas,
rem uno por archivo: modelos\personajes\<nombre>.glb (se pueden editar en Blender).
rem Los .glb que ya existen NO se tocan. Para regenerar: procesar_personajes.bat --forzar [nombre ...]
rem Los nombres, la escala y las articulaciones se configuran en modelos\personajes.cfg.
setlocal
set "GODOT_CONSOLA=%~dp0herramientas\godot\Godot_v4.7.2-stable_win64_console.exe"
"%GODOT_CONSOLA%" --headless --path "%~dp0." --script res://scripts/herramientas/procesar_personajes.gd -- %*
if errorlevel 1 exit /b 1
"%GODOT_CONSOLA%" --headless --path "%~dp0." --import
