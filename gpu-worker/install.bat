@echo off
REM Avatar Factory GPU Worker - WORKING Installation
REM This uses PyTorch 2.1.0 + openmim (proven method)

setlocal EnableDelayedExpansion

echo.
echo ============================================
echo  Avatar Factory GPU Worker - Installation
echo ============================================
echo.

REM Check Python
where python >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Python not found!
    echo Install Python 3.11: https://www.python.org/downloads/
    pause
    exit /b 1
)

python --version
echo.

REM Create venv (skip if exists)
if exist venv\Scripts\python.exe (
    echo [OK] Virtual environment exists
) else (
    echo [1/7] Creating virtual environment...
    python -m venv venv
    if %errorLevel% neq 0 (
        echo [ERROR] Failed to create venv
        pause
        exit /b 1
    )
    echo [OK] venv created
)
echo.

REM Install NumPy 1.x first (PyTorch 2.1.0 incompatible with NumPy 2.x!)
echo [2/7] Installing NumPy 1.x...
venv\Scripts\pip.exe install "numpy>=1.26.4,<2.0.0"
if %errorLevel% neq 0 (
    echo [ERROR] Failed to install NumPy
    pause
    exit /b 1
)
echo [OK] NumPy installed
echo.

REM Install PyTorch 2.1.0 (has prebuilt mmcv wheels!)
echo [3/7] Installing PyTorch 2.1.0 + CUDA 11.8...
echo This downloads ~2GB, takes 5-10 minutes
venv\Scripts\pip.exe install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu118
if %errorLevel% neq 0 (
    echo [ERROR] Failed to install PyTorch
    pause
    exit /b 1
)
echo [OK] PyTorch 2.1.0 installed
echo.

REM Install openmim
echo [4/7] Installing openmim...
venv\Scripts\pip.exe install openmim
if %errorLevel% neq 0 (
    echo [ERROR] Failed to install openmim
    pause
    exit /b 1
)
echo [OK] openmim installed
echo.

REM Install mmengine
echo [5/7] Installing mmengine...
venv\Scripts\python.exe -m mim install mmengine
if %errorLevel% neq 0 (
    echo [ERROR] Failed to install mmengine
    pause
    exit /b 1
)
echo [OK] mmengine installed
echo.

REM Install mmcv (prebuilt wheel via mim)
echo [6/7] Installing mmcv...
venv\Scripts\python.exe -m mim install mmcv
if %errorLevel% neq 0 (
    echo [ERROR] Failed to install mmcv
    pause
    exit /b 1
)
echo [OK] mmcv installed
echo.

REM Install mmdet and mmpose
echo [7/7] Installing mmdet and mmpose...
venv\Scripts\python.exe -m mim install mmdet mmpose
if %errorLevel% neq 0 (
    echo [ERROR] Failed to install mmdet/mmpose
    pause
    exit /b 1
)
echo [OK] mmdet and mmpose installed
echo.

REM Install other dependencies
echo [8/8] Installing other dependencies...
venv\Scripts\pip.exe install -r requirements.txt
if %errorLevel% neq 0 (
    echo [ERROR] Failed to install dependencies
    pause
    exit /b 1
)
echo [OK] Dependencies installed
echo.

REM Clone MuseTalk
if exist MuseTalk (
    echo [OK] MuseTalk already exists
) else (
    echo Cloning MuseTalk...
    git clone https://github.com/TMElyralab/MuseTalk.git
    if %errorLevel% neq 0 (
        echo [WARNING] Failed to clone MuseTalk
    ) else (
        echo [OK] MuseTalk cloned
    )
)
echo.

REM Create .env
if not exist .env (
    echo Creating .env...
    (
        echo GPU_API_KEY=%RANDOM%%RANDOM%%RANDOM%%RANDOM%
        echo HOST=0.0.0.0
        echo PORT=8001
    ) > .env
    echo [OK] .env created
)
echo.

REM Test GPU
echo ============================================
echo Testing GPU...
echo ============================================
venv\Scripts\python.exe -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA: {torch.cuda.is_available()}'); print(f'GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"Not detected\"}')"
echo.

echo ============================================
echo  Installation Complete!
echo ============================================
echo.
echo Start server:
echo   run.bat
echo.
echo Or manually:
echo   venv\Scripts\python.exe server.py
echo.
pause
