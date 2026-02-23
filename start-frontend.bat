@echo off
REM Start Avatar Factory Frontend Server

cd /d "%~dp0"

echo.
echo ============================================
echo  Avatar Factory Frontend Server
echo ============================================
echo.

REM Check if venv exists
if not exist venv-frontend (
    echo Creating virtual environment...
    python -m venv venv-frontend
    
    echo Installing dependencies...
    venv-frontend\Scripts\pip.exe install -r requirements-frontend.txt
)

echo.
echo Starting server...
echo.
echo Access from this laptop: http://localhost:3000
echo Access from network: http://<your-laptop-ip>:3000
echo.
echo GPU Server must be running on Windows machine!
echo Set GPU_SERVER_URL environment variable if needed.
echo.

venv-frontend\Scripts\python.exe frontend-server.py

pause
