@echo off
rem Corre las pruebas automaticas en modo headless (sin ventana).
rem Sale con codigo 0 si todas pasan.
setlocal
set "GODOT_CONSOLA=%~dp0herramientas\godot\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GODOT_CONSOLA%" (
  echo No se encontro Godot en "%GODOT_CONSOLA%".
  exit /b 1
)
set FALLOS=0
"%GODOT_CONSOLA%" --headless --path "%~dp0." --import
for %%P in (prueba_etapa0 prueba_etapa1) do (
  "%GODOT_CONSOLA%" --headless --path "%~dp0." --fixed-fps 60 res://pruebas/%%P.tscn
  if errorlevel 1 set FALLOS=1
)
if "%FALLOS%"=="1" (
  echo ALGUNA PRUEBA FALLO.
  exit /b 1
)
echo TODAS LAS PRUEBAS PASARON.
exit /b 0
