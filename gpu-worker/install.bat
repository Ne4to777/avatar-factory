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

REM Check if running as administrator
echo %YELLOW%Checking administrator rights...%NC%
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo %RED%Error: Not running as Administrator%NC%
    echo.
    echo %YELLOW%Setup requires administrator rights for Python, firewall, etc.%NC%
    echo.
    echo %YELLOW%To run as Administrator:%NC%
    echo   1. Right-click this file (install.bat)
    echo   2. Select "Run as administrator"
    echo.
    echo   Or from an elevated Command Prompt:
    echo   cd /d "%~dp0"
    echo   install.bat
    echo.
    pause
    exit /b 1
) else (
    echo %GREEN%Administrator rights confirmed.%NC%
    echo.
)

REM Run setup.ps1
if not exist "%~dp0setup.ps1" (
    echo %RED%Error: setup.ps1 not found%NC%
    pause
    exit /b 1
)

echo %GREEN%Running setup...%NC%
echo.
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0setup.ps1" %*
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
