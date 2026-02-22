@echo off
REM Avatar Factory GPU Worker - Upgrade to Python 3.11
REM Full stack upgrade: Python 3.11 + PyTorch 2.7 + MuseTalk

setlocal EnableDelayedExpansion

cd /d "%~dp0"

cls
echo.
echo ========================================
echo  Avatar Factory - Python 3.11 Upgrade
echo ========================================
echo.
echo This will:
echo   - Install Python 3.11 (if needed)
echo   - Remove old venv
echo   - Install PyTorch 2.7.0 + CUDA 11.8
echo   - Install latest AI libraries
echo   - Prepare for MuseTalk integration
echo.
echo IMPORTANT: This will take 15-30 minutes
echo.
pause

REM Check if Python 3.11 is available
echo [i] Checking for Python 3.11...
py -3.11 --version >nul 2>&1
if %errorLevel% equ 0 (
    echo [OK] Python 3.11 found
    set PYTHON_CMD=py -3.11
) else (
    python --version | findstr "3.11" >nul 2>&1
    if !errorLevel! equ 0 (
        echo [OK] Python 3.11 found
        set PYTHON_CMD=python
    ) else (
        echo [ERROR] Python 3.11 not found!
        echo.
        echo Please install Python 3.11 from:
        echo https://www.python.org/downloads/
        echo.
        echo Or use winget:
        echo   winget install Python.Python.3.11
        echo.
        pause
        exit /b 1
    )
)

echo.
echo [i] Python command: !PYTHON_CMD!
!PYTHON_CMD! --version
echo.

REM Backup old venv if exists
if exist "venv" (
    echo [i] Backing up old venv to venv.old...
    if exist "venv.old" (
        echo [i] Removing previous backup...
        rmdir /s /q venv.old
    )
    move venv venv.old >nul
    echo [OK] Backup complete
    echo.
)

REM Remove obsolete files from previous installations
echo [i] Cleaning obsolete files...

REM Remove legacy lip-sync module directory
if exist "SadTalker" (
    rmdir /s /q "SadTalker" 2>nul
)

REM Remove legacy inference wrappers and scripts
for %%F in (*talker*.py *talker*.ps1 *talker*.txt *-py312.ps1) do (
    if exist "%%F" (
        del /q "%%F" 2>nul
    )
)

echo [OK] Cleanup complete
echo.

REM Create new venv with Python 3.11
echo [i] Creating new virtual environment with Python 3.11...
!PYTHON_CMD! -m venv venv
if %errorLevel% neq 0 (
    echo [ERROR] Failed to create venv
    pause
    exit /b 1
)
echo [OK] Virtual environment created
echo.

REM Activate and upgrade pip
echo [i] Upgrading pip, setuptools, wheel...
call venv\Scripts\activate.bat
python -m pip install --upgrade pip setuptools==69.0.0 wheel --quiet
echo [OK] Core tools upgraded
echo.

REM Run new installer
echo [i] Starting full installation...
echo.
echo Press any key to run install.bat...
pause >nul

call install.bat

echo.
echo ========================================
echo  Upgrade Complete!
echo ========================================
echo.
echo Old venv backed up to: venv.old
echo You can delete it once you confirm everything works.
echo.
echo Next steps:
echo   1. Test the server: .\start.bat
echo   2. Check health: curl http://localhost:8001/health
echo.
pause
