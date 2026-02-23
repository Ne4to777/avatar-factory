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

echo Checking for existing server on port 8001...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8001 ^| findstr LISTENING') do (
    echo Found process %%a on port 8001, killing it...
    taskkill /F /PID %%a >nul 2>&1
    if errorlevel 1 (
        echo [WARNING] Could not kill process %%a
    ) else (
        echo Process %%a killed successfully
    )
)

echo Cleaning Python cache...
if exist __pycache__ rd /s /q __pycache__
if exist MuseTalk\__pycache__ rd /s /q MuseTalk\__pycache__
for /d /r %%d in (__pycache__) do @if exist "%%d" rd /s /q "%%d"

echo.
echo Starting server on http://localhost:8001
echo Press Ctrl+C to stop
echo.

venv\Scripts\python.exe server.py

pause
