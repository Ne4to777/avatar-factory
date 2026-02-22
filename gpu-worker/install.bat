@echo off
REM Avatar Factory GPU Worker - One-Command Installer Wrapper
REM Runs setup.ps1 with execution policy bypass.
REM Requires: Run as Administrator

setlocal

set "GREEN=[92m"
set "YELLOW=[93m"
set "RED=[91m"
set "NC=[0m"

reg add HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1

echo.
echo %GREEN%Avatar Factory GPU Worker - Installer%NC%
echo.

REM Check if running as administrator (multiple methods for reliability)
echo %YELLOW%Checking administrator rights...%NC%

REM Method 1: net session
net session >nul 2>&1
set "ADMIN_CHECK1=%errorLevel%"

REM Method 2: fsutil (alternative check)
fsutil dirty query %SystemDrive% >nul 2>&1
set "ADMIN_CHECK2=%errorLevel%"

if %ADMIN_CHECK1% neq 0 (
    if %ADMIN_CHECK2% neq 0 (
        echo %RED%Error: Not running as Administrator%NC%
        echo %YELLOW%  net session result: %ADMIN_CHECK1%%NC%
        echo %YELLOW%  fsutil result: %ADMIN_CHECK2%%NC%
        echo.
        echo %YELLOW%Setup requires administrator rights for Python, firewall, etc.%NC%
        echo.
        echo %YELLOW%To run as Administrator:%NC%
        echo   1. Right-click this file (install.bat)
        echo   2. Select "Run as administrator"
        echo.
        echo   Or open Command Prompt as Administrator:
        echo   - Press Win + X
        echo   - Select "Command Prompt (Admin)" or "Terminal (Admin)"
        echo   - Run: cd /d "%~dp0" ^&^& install.bat
        echo.
        pause
        exit /b 1
    )
)

echo %GREEN%Administrator rights confirmed.%NC%
echo.

REM Change to script directory
cd /d "%~dp0"

REM Run setup.ps1
if not exist "setup.ps1" (
    echo %RED%Error: setup.ps1 not found%NC%
    pause
    exit /b 1
)

echo %GREEN%Running setup...%NC%
echo.
powershell -ExecutionPolicy Bypass -NoProfile -File ".\setup.ps1" %*
set SETUP_EXIT=%errorLevel%

echo.
if %SETUP_EXIT% equ 0 (
    echo %GREEN%Installation completed successfully.%NC%
) else (
    echo %RED%Installation failed. Exit code: %SETUP_EXIT%%NC%
)

echo.
pause
exit /b %SETUP_EXIT%
