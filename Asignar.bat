@echo off
setlocal

cd /d "%~dp0"

where julia >nul 2>&1
if errorlevel 1 (
    echo No se encontro Julia en el PATH del sistema.
    echo Instale Julia o agregue Julia al PATH.
    pause
    exit /b 1
)

julia --threads=auto --project=. -e "using AsignacionesPopApp; AsignacionesPopApp.main(String[])"

if errorlevel 1 (
    echo.
    echo La aplicacion termino con un error.
    pause
)

endlocal