@echo off
REM Avatar Factory GPU Worker - Start Script for Windows
REM Handles both venv (manual) and Windows Service deployments

setlocal EnableDelayedExpansion

REM Change to script directory
cd /d "%~dp0"

cls
echo.
echo ========================================
echo  Avatar Factory GPU Worker - Starting
echo ========================================
echo.

REM Check if Windows Service exists and is running
sc query AvatarFactoryGPU >nul 2>&1
if %errorLevel% equ 0 (
    sc query AvatarFactoryGPU | findstr "RUNNING" >nul 2>&1
    if !errorLevel! equ 0 (
        echo [OK] GPU server is already running as Windows Service.
        echo.
        echo [WARNING] Stop service and run manually in this window?
        echo   This lets you see server output directly.
        echo.
        set /p STOP_SVC="   Stop service and run manually? (y/N): "
        if /i "!STOP_SVC!"=="y" (
            net stop AvatarFactoryGPU
            if !errorLevel! neq 0 (
                echo [ERROR] Failed to stop service. Try: net stop AvatarFactoryGPU (as admin)
                pause
                exit /b 1
            )
            echo [OK] Service stopped.
            echo.
        ) else (
            echo.
            echo Server is running. Use stop.bat or: net stop AvatarFactoryGPU
            echo.
            pause
            exit /b 0
        )
    )
)

REM Check if venv exists
if not exist "venv" (
    echo [ERROR] Virtual environment not found
    echo   Run install.bat first
    echo.
    pause
    exit /b 1
)

REM Check if server.py exists
if not exist "server.py" (
    echo [ERROR] server.py not found
    echo   Make sure you're in the gpu-worker directory
    pause
    exit /b 1
)

REM Activate venv
call venv\Scripts\activate.bat

REM Check/create .env
if not exist ".env" (
    echo [WARNING] .env not found, creating defaults...
    set "API_KEY=%RANDOM%%RANDOM%%RANDOM%%RANDOM%"
    (
        echo GPU_API_KEY=!API_KEY!
        echo HOST=0.0.0.0
        echo PORT=8001
    ) > .env
    echo [OK] Created .env with random API key
)

REM Get IP for display
set IP_ADDR=localhost
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /C:"IPv4"') do (
    set TEMP_IP=%%a
    set TEMP_IP=!TEMP_IP: =!
    if not "!TEMP_IP!"=="" (
        set IP_ADDR=!TEMP_IP!
        goto :ip_found
    )
)
:ip_found

echo [OK] Virtual environment activated
echo [OK] Configuration loaded
echo.
echo Server will be available at:
echo   http://!IP_ADDR!:8001
echo   http://localhost:8001
echo.
echo Press Ctrl+C to stop the server
echo.
echo ----------------------------------------
echo.

REM Start server
python server.py
set SERVER_EXIT=!errorLevel!

REM Server stopped
if !SERVER_EXIT! neq 0 (
    echo.
    echo [ERROR] Server exited with error
)

echo.
pause
exit /b !SERVER_EXIT!
