@echo off
REM Avatar Factory GPU Worker - FINAL WORKING Installation
REM NO openmim, NO mim, ONLY pip with exact versions

setlocal EnableDelayedExpansion

echo.
echo ============================================
echo  Avatar Factory GPU Worker - Installation
echo  Method: pip only (NO openmim)
echo ============================================
echo.

REM Check Python
where python >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Python not found!
    pause
    exit /b 1
)

python --version
echo.

REM Delete old venv
if exist venv (
    echo Deleting old venv...
    rmdir /s /q venv 2>nul
    timeout /t 2 >nul
)

REM Create fresh venv
echo [1/6] Creating virtual environment...
python -m venv venv
if %errorLevel% neq 0 (
    echo [ERROR] Failed to create venv
    pause
    exit /b 1
)
echo [OK] venv created
echo.

REM Install NumPy 1.x FIRST
echo [2/6] Installing NumPy 1.x...
venv\Scripts\pip.exe install "numpy>=1.26.4,<2.0.0"
if %errorLevel% neq 0 (
    echo [ERROR] Failed to install NumPy
    pause
    exit /b 1
)
echo [OK] NumPy installed
echo.

REM Install PyTorch 2.1.0
echo [3/6] Installing PyTorch 2.1.0 + CUDA 11.8...
echo This downloads ~2GB, takes 5-10 minutes
venv\Scripts\pip.exe install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu118
if %errorLevel% neq 0 (
    echo [ERROR] Failed to install PyTorch
    pause
    exit /b 1
)
echo [OK] PyTorch installed
echo.

REM Install opencv-python compatible with NumPy 1.x
echo [4/6] Installing opencv-python...
venv\Scripts\pip.exe install "opencv-python>=4.8.0,<4.10.0"
if %errorLevel% neq 0 (
    echo [ERROR] Failed to install opencv-python
    pause
    exit /b 1
)
echo [OK] opencv-python installed
echo.

REM Install mmcv, mmdet, mmpose directly (NO mim!)
echo [5/6] Installing mmcv, mmdet, mmpose...
echo Using prebuilt wheels from OpenMMLab
venv\Scripts\pip.exe install mmcv==2.1.0 -f https://download.openmmlab.com/mmcv/dist/cu118/torch2.1/index.html
venv\Scripts\pip.exe install mmengine==0.10.3 mmdet==3.3.0 mmpose==1.3.1
if %errorLevel% neq 0 (
    echo [ERROR] Failed to install OpenMMLab packages
    pause
    exit /b 1
)
echo [OK] OpenMMLab packages installed
echo.

REM Install other dependencies
echo [6/6] Installing other dependencies...
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
pause
