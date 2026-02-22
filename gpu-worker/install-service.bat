@echo off
REM Avatar Factory GPU Worker - Install as Windows Service
REM Requires Administrator privileges

setlocal EnableDelayedExpansion

cd /d "%~dp0"

echo.
echo ========================================
echo  Install Avatar Factory GPU Service
echo ========================================
echo.

REM Check for admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] This script requires Administrator privileges
    echo.
    echo Right-click and select "Run as Administrator"
    echo.
    pause
    exit /b 1
)

echo [OK] Running as Administrator
echo.

REM Check if venv exists
if not exist "venv\Scripts\python.exe" (
    echo [ERROR] Virtual environment not found
    echo   Run install.bat first
    echo.
    pause
    exit /b 1
)

REM Check if NSSM exists
if not exist "bin\nssm.exe" (
    echo [ERROR] NSSM not found
    echo   Run install.bat first to download NSSM
    echo.
    pause
    exit /b 1
)

set NSSM="%CD%\bin\nssm.exe"
set SERVICE_NAME=AvatarFactoryGPU
set PYTHON_EXE=%CD%\venv\Scripts\python.exe
set SERVER_SCRIPT=%CD%\server.py
set WORK_DIR=%CD%

echo [i] Configuration:
echo   Service name: %SERVICE_NAME%
echo   Python: %PYTHON_EXE%
echo   Script: %SERVER_SCRIPT%
echo   Working dir: %WORK_DIR%
echo.

REM Check if service already exists
sc query %SERVICE_NAME% >nul 2>&1
if %errorLevel% equ 0 (
    echo [!] Service already exists. Remove and reinstall? (Y/n)
    set /p REINSTALL="   "
    if /i "!REINSTALL!"=="n" (
        echo [i] Installation cancelled
        pause
        exit /b 0
    )
    
    echo [i] Stopping service...
    net stop %SERVICE_NAME% >nul 2>&1
    
    echo [i] Removing old service...
    %NSSM% remove %SERVICE_NAME% confirm
    if !errorLevel! neq 0 (
        echo [ERROR] Failed to remove old service
        pause
        exit /b 1
    )
    echo [OK] Old service removed
    echo.
)

echo [i] Installing service...
%NSSM% install %SERVICE_NAME% "%PYTHON_EXE%" "%SERVER_SCRIPT%"
if %errorLevel% neq 0 (
    echo [ERROR] Failed to install service
    pause
    exit /b 1
)

echo [i] Configuring service...
%NSSM% set %SERVICE_NAME% AppDirectory "%WORK_DIR%"
%NSSM% set %SERVICE_NAME% DisplayName "Avatar Factory GPU Worker"
%NSSM% set %SERVICE_NAME% Description "AI GPU processing server for Avatar Factory"
%NSSM% set %SERVICE_NAME% Start SERVICE_AUTO_START
%NSSM% set %SERVICE_NAME% AppStdout "%WORK_DIR%\logs\service-stdout.log"
%NSSM% set %SERVICE_NAME% AppStderr "%WORK_DIR%\logs\service-stderr.log"
%NSSM% set %SERVICE_NAME% AppRotateFiles 1
%NSSM% set %SERVICE_NAME% AppRotateOnline 1
%NSSM% set %SERVICE_NAME% AppRotateBytes 10485760

echo [OK] Service configured
echo.

echo [i] Starting service...
net start %SERVICE_NAME%
if %errorLevel% neq 0 (
    echo [ERROR] Failed to start service
    echo   Check logs in: logs\service-stderr.log
    pause
    exit /b 1
)

echo.
echo ========================================
echo  Installation Complete!
echo ========================================
echo.
echo [OK] Service installed and started
echo.
echo Service will now:
echo   - Start automatically on Windows boot
echo   - Restart automatically if it crashes
echo   - Log to: logs\service-stdout.log
echo.
echo Management commands:
echo   net start %SERVICE_NAME%     - Start service
echo   net stop %SERVICE_NAME%      - Stop service
echo   net restart %SERVICE_NAME%   - Restart service
echo.
echo Check status:
echo   sc query %SERVICE_NAME%
echo   curl http://localhost:8001/health
echo.
pause
