@echo off
REM Avatar Factory GPU Worker - Windows Setup
REM This script installs everything needed to run GPU worker natively on Windows

setlocal EnableDelayedExpansion

echo.
echo ============================================
echo  Avatar Factory GPU Worker Setup (Windows)
echo ============================================
echo.

REM Check if conda is available
where conda >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Conda not found!
    echo.
    echo Please install Miniconda first:
    echo https://docs.conda.io/en/latest/miniconda.html
    echo.
    echo Then run this script from "Anaconda Prompt"
    echo.
    pause
    exit /b 1
)

echo [1/6] Checking conda...
conda --version
echo.

REM Create conda environment
echo [2/6] Creating conda environment 'avatar'...
conda create -n avatar python=3.11 -y
if %errorLevel% neq 0 (
    echo [ERROR] Failed to create conda environment
    pause
    exit /b 1
)
echo [OK] Environment created
echo.

REM Activate environment for subsequent commands
call conda activate avatar

REM Install PyTorch with CUDA
echo [3/6] Installing PyTorch 2.7.0 with CUDA 11.8...
echo This will download ~3GB, takes 5-10 minutes
echo.
conda install pytorch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0 pytorch-cuda=11.8 -c pytorch -c nvidia -y
if %errorLevel% neq 0 (
    echo [ERROR] Failed to install PyTorch
    pause
    exit /b 1
)
echo [OK] PyTorch installed
echo.

REM Install Python dependencies
echo [4/6] Installing Python dependencies...
pip install -r requirements.txt
if %errorLevel% neq 0 (
    echo [ERROR] Failed to install dependencies
    pause
    exit /b 1
)
echo [OK] Dependencies installed
echo.

REM Clone MuseTalk
echo [5/6] Cloning MuseTalk repository...
if exist MuseTalk (
    echo MuseTalk already exists, skipping
) else (
    git clone https://github.com/TMElyralab/MuseTalk.git
    if %errorLevel% neq 0 (
        echo [WARNING] Failed to clone MuseTalk
        echo You can clone it manually later
    ) else (
        echo [OK] MuseTalk cloned
    )
)
echo.

REM Create .env file
echo [6/6] Creating .env file...
if exist .env (
    echo .env already exists, skipping
) else (
    (
        echo GPU_API_KEY=%RANDOM%%RANDOM%%RANDOM%%RANDOM%
        echo HOST=0.0.0.0
        echo PORT=8001
        echo CUDA_VISIBLE_DEVICES=0
    ) > .env
    echo [OK] .env created
)
echo.

REM Test GPU
echo ============================================
echo Testing GPU availability...
echo ============================================
python -c "import torch; print(f'PyTorch version: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}'); print(f'GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"N/A\"}')"
echo.

if %errorLevel% neq 0 (
    echo [ERROR] GPU test failed
    pause
    exit /b 1
)

echo ============================================
echo  Setup Complete!
echo ============================================
echo.
echo To start the server, run:
echo   start-windows.bat
echo.
echo Or manually:
echo   conda activate avatar
echo   python server.py
echo.
pause
