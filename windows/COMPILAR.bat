@echo off
rem Compila o instalador ArchyOs para Windows nesta maquina.
rem Clique com o botao direito -> "Executar como administrador".
net session >nul 2>&1
if errorlevel 1 (
  echo Abra como administrador: botao direito -^> Executar como administrador.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1"
pause
