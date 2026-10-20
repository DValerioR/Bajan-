@echo off
rem Convierte los modelos de modelos\fuentes\ (Tripo) en personajes con esqueleto (una malla
rem continua con 11 huesos), uno por archivo: modelos\personajes\<nombre>.glb (se pueden editar en Blender).
rem Los .glb que ya existen NO se tocan. Para regenerar: procesar_personajes.bat --forzar [nombre ...]
rem Los nombres, la escala y las articulaciones se configuran en modelos\personajes.cfg.
rem Necesita Blender (o la variable BLENDER_EXE): Godot corta el modelo en piezas, Blender las une en
rem una malla con esqueleto y la reduce (scripts\herramientas\esqueleto_blender.py) y les pone la
rem boca animada a los que tengan `boca` en el cfg (caras_blender.py).
setlocal
set "GODOT_CONSOLA=%~dp0herramientas\godot\Godot_v4.7.2-stable_win64_console.exe"
set "BLENDER="
for /d %%D in ("%ProgramFiles%\Blender Foundation\Blender *") do if exist "%%D\blender.exe" set "BLENDER=%%D\blender.exe"
if defined BLENDER_EXE set "BLENDER=%BLENDER_EXE%"
if not defined BLENDER (
  echo Error: no se encontro Blender; hace falta para armar el esqueleto de los personajes.
  exit /b 1
)
"%GODOT_CONSOLA%" --headless --path "%~dp0." --script res://scripts/herramientas/procesar_personajes.gd -- --para-esqueleto %*
if errorlevel 1 exit /b 1
"%BLENDER%" --background --factory-startup --python "%~dp0scripts\herramientas\esqueleto_blender.py" -- "%~dp0modelos\personajes"
if errorlevel 1 exit /b 1
rem Los que Tripo ya entrega con esqueleto (`rig` en personajes.cfg) conservan sus pesos (D53).
"%BLENDER%" --background --factory-startup --python "%~dp0scripts\herramientas\rig_tripo_blender.py" -- "%~dp0modelos\personajes" %*
if errorlevel 1 exit /b 1
"%BLENDER%" --background --factory-startup --python "%~dp0scripts\herramientas\caras_blender.py" -- "%~dp0modelos\personajes"
if errorlevel 1 exit /b 1
"%GODOT_CONSOLA%" --headless --path "%~dp0." --import
rem Las texturas de los personajes van con compresion de video de alta calidad (D46).
"%GODOT_CONSOLA%" --headless --path "%~dp0." --script res://scripts/herramientas/comprimir_texturas.gd
"%GODOT_CONSOLA%" --headless --path "%~dp0." --import
