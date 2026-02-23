@echo off
REM Download correct VAE model

cd /d "%~dp0"

echo.
echo Downloading Stable Diffusion VAE...
echo.

cd MuseTalk\models

echo Removing incomplete sd-vae...
rmdir /s /q sd-vae 2>nul

echo.
echo Downloading from HuggingFace (stabilityai/sd-vae-ft-mse)...
echo This may take 2-3 minutes...
echo.

git lfs install
git clone https://huggingface.co/stabilityai/sd-vae-ft-mse sd-vae

if exist sd-vae\config.json (
    echo.
    echo [OK] VAE downloaded successfully
) else (
    echo.
    echo [ERROR] Download failed
)

cd ..\..

echo.
pause
