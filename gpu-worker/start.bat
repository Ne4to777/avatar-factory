@echo off
REM Avatar Factory GPU Worker - Start Script for Windows
REM Запуск GPU сервера

setlocal EnableDelayedExpansion

set "GREEN=[92m"
set "YELLOW=[93m"
set "RED=[91m"
set "BLUE=[94m"
set "NC=[0m"

reg add HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1

cls
echo.
echo %BLUE%╔════════════════════════════════════════════════════════════════╗%NC%
echo %BLUE%║%NC%  🚀 Starting Avatar Factory GPU Server...                %BLUE%║%NC%
echo %BLUE%╚════════════════════════════════════════════════════════════════╝%NC%
echo.

REM Check if venv exists
if not exist "venv" (
    echo %RED%✗ Virtual environment not found%NC%
    echo %YELLOW%  Run install.bat first%NC%
    pause
    exit /b 1
)

REM Activate venv
call venv\Scripts\activate.bat

REM Check if .env exists
if not exist ".env" (
    echo %YELLOW%⚠ .env file not found, creating with default values...%NC%
    set "API_KEY=%RANDOM%%RANDOM%%RANDOM%%RANDOM%"
    echo GPU_API_KEY=!API_KEY! > .env
    echo HOST=0.0.0.0 >> .env
    echo PORT=8001 >> .env
)

REM Get IP address
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address"') do (
    set IP_ADDR=%%a
    set IP_ADDR=!IP_ADDR:~1!
    goto :ip_found
)
:ip_found

if "!IP_ADDR!"=="" set IP_ADDR=localhost

echo %GREEN%✓ Virtual environment activated%NC%
echo %GREEN%✓ Configuration loaded%NC%
echo.
echo %BLUE%Server will be available at:%NC%
echo   %GREEN%http://!IP_ADDR!:8001%NC%
echo   %GREEN%http://localhost:8001%NC%
echo.
echo %YELLOW%Press Ctrl+C to stop the server%NC%
echo.
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo.

REM Start server
python server.py

if %errorLevel% neq 0 (
    echo.
    echo %RED%✗ Server crashed or failed to start%NC%
    pause
)
