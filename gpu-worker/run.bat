@echo off
REM Start Avatar Factory GPU Worker

echo.
echo ============================================
echo  Avatar Factory GPU Worker
echo ============================================
echo.

if not exist venv\Scripts\python.exe (
    echo [ERROR] venv not found!
    echo.
    echo Run installation first:
    echo   install.bat
    echo.
    pause
    exit /b 1
)

echo Starting server on http://localhost:8001
echo Press Ctrl+C to stop
echo.

venv\Scripts\python.exe server.py

pause
