@echo off
REM Avatar Factory GPU Worker - Uninstall Windows Service
REM Requires Administrator privileges

setlocal EnableDelayedExpansion

cd /d "%~dp0"

echo.
echo ========================================
echo  Uninstall Avatar Factory GPU Service
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

set SERVICE_NAME=AvatarFactoryGPU

REM Check if service exists
sc query %SERVICE_NAME% >nul 2>&1
if %errorLevel% neq 0 (
    echo [i] Service '%SERVICE_NAME%' is not installed
    echo.
    pause
    exit /b 0
)

echo [i] Found service: %SERVICE_NAME%
echo.

REM Check if NSSM exists
if not exist "bin\nssm.exe" (
    echo [ERROR] NSSM not found at bin\nssm.exe
    echo.
    echo Manual removal:
    echo   sc stop %SERVICE_NAME%
    echo   sc delete %SERVICE_NAME%
    echo.
    pause
    exit /b 1
)

set NSSM="%CD%\bin\nssm.exe"

echo [!] Are you sure you want to uninstall the service? (Y/n)
set /p CONFIRM="   "
if /i not "!CONFIRM!"=="y" if /i not "!CONFIRM!"=="" (
    echo [i] Uninstall cancelled
    pause
    exit /b 0
)

echo [i] Stopping service...
net stop %SERVICE_NAME% >nul 2>&1

echo [i] Removing service...
%NSSM% remove %SERVICE_NAME% confirm
if %errorLevel% neq 0 (
    echo [ERROR] Failed to remove service with NSSM
    echo [i] Trying sc delete...
    sc delete %SERVICE_NAME%
    if !errorLevel! neq 0 (
        echo [ERROR] Failed to remove service
        pause
        exit /b 1
    )
)

echo [OK] Service uninstalled successfully
echo.
echo The GPU worker can still be run manually with: .\start.bat
echo.
pause
