@echo off
REM Download MuseTalk models

cd /d "%~dp0"

echo.
echo ============================================
echo  Downloading MuseTalk Models
echo ============================================
echo.
echo This downloads ~2GB of model weights
echo.

if not exist MuseTalk (
    echo [ERROR] MuseTalk directory not found!
    echo Run: git clone https://github.com/TMElyralab/MuseTalk.git
    pause
    exit /b 1
)

cd MuseTalk

if exist download_weights.bat (
    echo [1/1] Running MuseTalk download_weights.bat...
    call download_weights.bat
) else (
    echo [ERROR] download_weights.bat not found in MuseTalk directory
    pause
    exit /b 1
)

cd ..

echo.
echo ============================================
echo  Models downloaded!
echo ============================================
echo.
echo Now start the server:
echo   venv\Scripts\python.exe server.py
echo.
pause
