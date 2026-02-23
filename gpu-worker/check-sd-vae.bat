@echo off
cd /d "%~dp0"

echo.
echo Checking sd-vae directories...
echo.

echo [1] models/sd-vae:
if exist MuseTalk\models\sd-vae (
    dir MuseTalk\models\sd-vae /b
) else (
    echo NOT FOUND
)

echo.
echo [2] models/sd-vae-ft-mse:
if exist MuseTalk\models\sd-vae-ft-mse (
    dir MuseTalk\models\sd-vae-ft-mse /b
) else (
    echo NOT FOUND
)

echo.
pause
