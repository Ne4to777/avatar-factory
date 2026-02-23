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

REM Kill any Python processes that might block venv
echo Checking for running Python processes...
taskkill /F /IM python.exe >nul 2>&1
timeout /t 1 /nobreak >nul

REM Remove old venv if exists
if exist venv (
    echo Removing old venv...
    rmdir /s /q venv 2>nul
    if exist venv (
        echo [WARNING] Cannot remove venv - files locked
        echo Please close all Python programs and try again
        pause
        exit /b 1
    )
    timeout /t 2 /nobreak >nul
)

REM Create venv
echo [1/4] Creating virtual environment...
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

REM Install chumpy first (needed by mmpose, requires special handling)
echo [3/5] Installing chumpy...
venv\Scripts\pip.exe install --no-build-isolation chumpy
echo.

REM Install dependencies
echo [4/5] Installing dependencies...
venv\Scripts\pip.exe install -r requirements.txt
if %errorLevel% neq 0 (
    echo [ERROR] Failed to install dependencies
    pause
    exit /b 1
)
echo [OK] Dependencies installed
echo.

REM Clone MuseTalk
echo [5/5] Cloning MuseTalk...
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
