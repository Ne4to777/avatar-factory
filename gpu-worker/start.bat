@echo off
REM Avatar Factory GPU Worker - Start Script for Windows
REM Handles both venv (manual) and Windows Service deployments

setlocal EnableDelayedExpansion

set "GREEN=[92m"
set "YELLOW=[93m"
set "RED=[91m"
set "BLUE=[94m"
set "NC=[0m"

reg add HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1

REM Change to script directory
cd /d "%~dp0"

cls
echo.
echo %BLUE%Avatar Factory GPU Worker - Starting...%NC%
echo.

REM Check if Windows Service exists and is running
sc query AvatarFactoryGPU >nul 2>&1
if %errorLevel% equ 0 (
    sc query AvatarFactoryGPU | findstr "RUNNING" >nul 2>&1
    if !errorLevel! equ 0 (
        echo %GREEN%GPU server is already running as Windows Service.%NC%
        echo.
        echo %YELLOW%Stop service and run manually in this window?%NC%
        echo   This lets you see server output directly.
        echo.
        set /p STOP_SVC="   Stop service and run manually? (y/N): "
        if /i "!STOP_SVC!"=="y" (
            net stop AvatarFactoryGPU
            if !errorLevel! neq 0 (
                echo %RED%Failed to stop service. Try: net stop AvatarFactoryGPU (as admin)%NC%
                pause
                exit /b 1
            )
            echo %GREEN%Service stopped.%NC%
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
    echo %RED%Error: Virtual environment not found%NC%
    echo %YELLOW%  Run install.bat first%NC%
    echo.
    pause
    exit /b 1
)

REM Check if server.py exists
if not exist "server.py" (
    echo %RED%Error: server.py not found%NC%
    echo %YELLOW%  Make sure you're in the gpu-worker directory%NC%
    pause
    exit /b 1
)

REM Activate venv
call venv\Scripts\activate.bat

REM Check/create .env
if not exist ".env" (
    echo %YELLOW%.env not found, creating defaults...%NC%
    set "API_KEY=%RANDOM%%RANDOM%%RANDOM%%RANDOM%"
    (
        echo GPU_API_KEY=!API_KEY!
        echo HOST=0.0.0.0
        echo PORT=8001
    ) > .env
    echo %GREEN%Created .env with random API key%NC%
)

REM Get IP for display
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address"') do (
    set IP_ADDR=%%a
    set IP_ADDR=!IP_ADDR:~1!
    goto :ip_found
)
:ip_found
if "!IP_ADDR!"=="" set IP_ADDR=localhost

echo %GREEN%Virtual environment activated%NC%
echo %GREEN%Configuration loaded%NC%
echo.
echo %BLUE%Server will be available at:%NC%
echo   http://!IP_ADDR!:8001
echo   http://localhost:8001
echo.
echo %YELLOW%Press Ctrl+C to stop the server%NC%
echo.
echo ----------------------------------------
echo.

REM Start server
python server.py
set SERVER_EXIT=!errorLevel!

REM Server stopped
if !SERVER_EXIT! neq 0 (
    echo.
    echo %RED%Server exited with error%NC%
)

echo.
pause
exit /b !SERVER_EXIT!
