@echo off
REM Quick fix for NumPy version incompatibility

echo.
echo ============================================
echo  Fixing NumPy version (downgrade to 1.x)
echo ============================================
echo.

if not exist venv\Scripts\python.exe (
    echo [ERROR] venv not found!
    echo Run install.bat first
    pause
    exit /b 1
)

echo Uninstalling NumPy 2.x...
venv\Scripts\pip.exe uninstall numpy -y

echo.
echo Installing NumPy 1.x...
venv\Scripts\pip.exe install "numpy>=1.26.4,<2.0.0"

echo.
echo ============================================
echo  NumPy fixed!
echo ============================================
echo.
echo Now start the server:
echo   run.bat
echo.
pause
