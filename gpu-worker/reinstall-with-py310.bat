@echo off
setlocal EnableDelayedExpansion

echo.
echo ================================================
echo  Reinstall GPU Worker with Python 3.10
echo ================================================
echo.

REM Check if Python 3.10 is installed
py -3.10 --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python 3.10 not found!
    echo.
    echo Please download and install Python 3.10.11:
    echo https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe
    echo.
    echo After installation, run this script again.
    echo.
    pause
    exit /b 1
)

echo [OK] Python 3.10 detected
py -3.10 --version
echo.

REM Check if venv exists
if exist "venv\" (
    echo [WARNING] Existing venv folder found
    echo.
    set /p CONFIRM="Delete existing venv and reinstall? (y/N): "
    if /i not "!CONFIRM!"=="y" (
        echo Cancelled.
        pause
        exit /b 0
    )
    
    echo.
    echo [i] Removing old venv...
    rmdir /s /q venv
    echo [OK] Removed
    echo.
)

echo [i] Creating new venv with Python 3.10...
py -3.10 -m venv venv

if errorlevel 1 (
    echo [ERROR] Failed to create venv
    pause
    exit /b 1
)

echo [OK] venv created
echo.
echo [i] Starting installation...
echo.

call install.bat

exit /b %ERRORLEVEL%
