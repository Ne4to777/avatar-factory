@echo off
setlocal EnableDelayedExpansion

echo.
echo ================================================
echo  Reinstall GPU Worker with Python 3.10
echo ================================================
echo.

echo [i] Checking Python installations...
echo.

REM First, try to find any Python
python --version 2>nul
if errorlevel 1 (
    echo [ERROR] No Python found in PATH
    echo.
    echo Please install Python 3.10.11:
    echo https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe
    echo.
    pause
    exit /b 1
)

echo Current Python:
python --version
echo.

REM Try Python launcher
py --version >nul 2>&1
if errorlevel 1 (
    echo [WARNING] Python launcher 'py' not available
    echo.
    echo Trying to use 'python' command directly...
    
    REM Check if it's Python 3.10
    for /f "tokens=2 delims= " %%v in ('python --version 2^>^&1') do set PYVER=%%v
    echo Detected version: !PYVER!
    
    if "!PYVER:~0,4!" NEQ "3.10" (
        echo.
        echo [ERROR] Need Python 3.10, but found !PYVER!
        echo.
        echo Please install Python 3.10.11:
        echo https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe
        echo.
        pause
        exit /b 1
    )
    
    set PYTHON_CMD=python
    goto :python_found
)

REM Check if Python 3.10 is available via launcher
py -3.10 --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python 3.10 not found via launcher!
    echo.
    echo Please install Python 3.10.11:
    echo https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe
    echo.
    echo Make sure to check "Install launcher for all users" during installation.
    echo.
    pause
    exit /b 1
)

set PYTHON_CMD=py -3.10

:python_found
echo [OK] Python 3.10 detected:
%PYTHON_CMD% --version
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
