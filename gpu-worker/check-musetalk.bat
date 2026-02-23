@echo off
REM Check MuseTalk structure

cd /d "%~dp0"

echo.
echo Checking MuseTalk directory structure...
echo.

if exist MuseTalk (
    echo [OK] MuseTalk directory exists
    
    echo.
    echo Files in MuseTalk/:
    dir MuseTalk /b
    
    echo.
    echo Looking for musetalk/utils/dwpose/:
    if exist MuseTalk\musetalk\utils\dwpose (
        echo [OK] dwpose directory exists
        dir MuseTalk\musetalk\utils\dwpose /b
    ) else (
        echo [ERROR] dwpose directory NOT FOUND
    )
) else (
    echo [ERROR] MuseTalk directory does NOT exist
    echo.
    echo Cloning MuseTalk...
    git clone https://github.com/TMElyralab/MuseTalk.git
)

echo.
pause
