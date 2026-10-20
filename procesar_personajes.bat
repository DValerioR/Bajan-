@echo off
rem Convierte los modelos de modelos\fuentes\ (Tripo) en personajes de muneco por piezas,
rem uno por archivo: modelos\personajes\<nombre>.glb (se pueden editar en Blender).
rem Los .glb que ya existen NO se tocan. Para regenerar: procesar_personajes.bat --forzar [nombre ...]
rem Los nombres, la escala y las articulaciones se configuran en modelos\personajes.cfg.
rem Si encuentra Blender (o la variable BLENDER_EXE), Blender tapa los cortes y reduce las piezas
rem (scripts\herramientas\tapar_cortes.py) y les pone la boca animada a los que tengan `boca` en el cfg
rem (caras_blender.py). Sin Blender, Godot las reduce y los cortes quedan abiertos.
setlocal
set "GODOT_CONSOLA=%~dp0herramientas\godot\Godot_v4.7.2-stable_win64_console.exe"
set "BLENDER="
for /d %%D in ("%ProgramFiles%\Blender Foundation\Blender *") do if exist "%%D\blender.exe" set "BLENDER=%%D\blender.exe"
if defined BLENDER_EXE set "BLENDER=%BLENDER_EXE%"
if defined BLENDER (
  "%GODOT_CONSOLA%" --headless --path "%~dp0." --script res://scripts/herramientas/procesar_personajes.gd -- --sin-reducir %*
  if errorlevel 1 exit /b 1
  "%BLENDER%" --background --factory-startup --python "%~dp0scripts\herramientas\tapar_cortes.py" -- "%~dp0modelos\personajes"
  if errorlevel 1 exit /b 1
  "%BLENDER%" --background --factory-startup --python "%~dp0scripts\herramientas\caras_blender.py" -- "%~dp0modelos\personajes"
  if errorlevel 1 exit /b 1
) else (
  echo Aviso: no se encontro Blender; los cortes de los personajes quedan abiertos.
  "%GODOT_CONSOLA%" --headless --path "%~dp0." --script res://scripts/herramientas/procesar_personajes.gd -- %*
  if errorlevel 1 exit /b 1
)
"%GODOT_CONSOLA%" --headless --path "%~dp0." --import
rem Las texturas de los personajes van con compresion de video de alta calidad (D46).
"%GODOT_CONSOLA%" --headless --path "%~dp0." --script res://scripts/herramientas/comprimir_texturas.gd
"%GODOT_CONSOLA%" --headless --path "%~dp0." --import
