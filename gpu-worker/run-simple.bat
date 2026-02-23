@echo off
REM Run server using venv (no conda)

echo.
echo Starting Avatar Factory GPU Worker...
echo.

if not exist venv\Scripts\python.exe (
    echo [ERROR] venv not found. Run install-simple.bat first
    pause
    exit /b 1
)

echo Server: http://localhost:8001
echo Press Ctrl+C to stop
echo.

venv\Scripts\python.exe server.py

pause
