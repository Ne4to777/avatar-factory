@echo off
REM Check MuseTalk models

cd /d "%~dp0"

echo.
echo Checking MuseTalk models...
echo.

echo [1] Checking MuseTalk/models/:
if exist MuseTalk\models (
    echo   [OK] models directory exists
    dir MuseTalk\models /b
    
    echo.
    echo [2] Checking models/dwpose/:
    if exist MuseTalk\models\dwpose (
        echo   [OK] dwpose exists
        dir MuseTalk\models\dwpose /b
    ) else (
        echo   [ERROR] dwpose NOT FOUND
    )
    
    echo.
    echo [3] Checking models/sd-vae/:
    if exist MuseTalk\models\sd-vae (
        echo   [OK] sd-vae exists
        dir MuseTalk\models\sd-vae /b
    ) else (
        echo   [ERROR] sd-vae NOT FOUND
    )
    
    echo.
    echo [4] Checking models/musetalk/:
    if exist MuseTalk\models\musetalk (
        echo   [OK] musetalk exists
        dir MuseTalk\models\musetalk /b
    ) else (
        echo   [ERROR] musetalk NOT FOUND
    )
) else (
    echo   [ERROR] models directory does NOT exist
)

echo.
pause
