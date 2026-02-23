@echo off
REM Simple installation using standard Python venv (no conda, no admin rights needed)

echo.
echo ============================================
echo  Avatar Factory - Simple Setup
echo ============================================
echo.

REM Check Python
where python >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Python not found
    echo Install Python 3.11: https://www.python.org/downloads/
    pause
    exit /b 1
)

python --version
echo.

REM Create venv (skip if exists)
if exist venv\Scripts\python.exe (
    echo [1/6] Virtual environment exists, using existing
    echo.
) else (
    echo [1/6] Creating virtual environment...
)
python -m venv venv
if %errorLevel% neq 0 (
    echo [ERROR] Failed to create venv
    pause
    exit /b 1
)
echo [OK] venv created
echo.

REM Install PyTorch
echo [2/4] Installing PyTorch with CUDA 11.8 (~3GB, 5-10 minutes)...
venv\Scripts\pip.exe install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
if %errorLevel% neq 0 (
    echo [ERROR] Failed to install PyTorch
    pause
    exit /b 1
)
echo [OK] PyTorch installed
echo.

REM Install build tools first
echo [3/6] Installing build tools...
venv\Scripts\pip.exe install setuptools wheel
echo.

REM Install OpenMMLab packages (required by MuseTalk)
echo [4/6] Installing OpenMMLab packages...
venv\Scripts\pip.exe install --no-build-isolation chumpy
venv\Scripts\pip.exe install --no-build-isolation mmcv mmpose mmdet
if %errorLevel% neq 0 (
    echo [WARNING] Failed to install OpenMMLab packages
    echo MuseTalk will not work without them
)
echo.

REM Install other dependencies
echo [5/6] Installing other dependencies...
venv\Scripts\pip.exe install -r requirements.txt
if %errorLevel% neq 0 (
    echo [ERROR] Failed to install dependencies
    pause
    exit /b 1
)
echo [OK] Dependencies installed
echo.

REM Clone MuseTalk
echo [6/6] Cloning MuseTalk...
if exist MuseTalk (
    echo MuseTalk exists, skipping
) else (
    git clone https://github.com/TMElyralab/MuseTalk.git
)
echo.

REM Create .env
if not exist .env (
    echo GPU_API_KEY=test-key-change-this> .env
    echo HOST=0.0.0.0>> .env
    echo PORT=8001>> .env
)

REM Test
echo ============================================
echo Testing GPU...
echo ============================================
venv\Scripts\python.exe -c "import torch; print(f'CUDA: {torch.cuda.is_available()}'); print(f'GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"Not detected\"}')"
echo.

echo ============================================
echo  Setup complete!
echo ============================================
echo.
echo Start server:
echo   run-simple.bat
echo.
pause
