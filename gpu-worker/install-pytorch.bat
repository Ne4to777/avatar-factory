@echo off
REM Install PyTorch to current venv

cd /d "%~dp0"

echo.
echo Installing PyTorch 2.1.0 + CUDA 11.8...
echo This takes 5-10 minutes (downloads ~2GB)
echo.

venv\Scripts\python.exe -m pip install "numpy>=1.26.4,<2.0.0"
venv\Scripts\python.exe -m pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu118

echo.
echo Done!
echo.

pause
