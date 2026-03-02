@echo off
REM ================================================================
REM Avatar Factory GPU Worker - Windows Installation Script
REM ================================================================
REM 
REM Prerequisites:
REM - Python 3.10 or 3.11
REM - CUDA 11.8 installed
REM - NVIDIA GPU with compute capability 7.0+
REM
REM Usage:
REM   install_windows.bat
REM ================================================================

echo === Avatar Factory GPU Worker - Windows Setup ===
echo.

REM Check Python version
echo [1/8] Checking Python version...
python --version
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Python not found in PATH
    exit /b 1
)
echo       [OK] Python found

REM Create venv if not exists
if not exist "venv" (
    echo [2/8] Creating virtual environment...
    python -m venv venv
    echo       [OK] Virtual environment created
) else (
    echo [2/8] Virtual environment already exists
)

REM Activate venv
echo [3/8] Activating virtual environment...
call venv\Scripts\activate.bat

REM Upgrade pip, setuptools, wheel
echo [4/8] Upgrading pip, setuptools, wheel...
python -m pip install --upgrade pip setuptools wheel
echo       [OK] Base tools upgraded

REM Install PyTorch with CUDA 11.8
echo [5/8] Installing PyTorch 2.1.0 + CUDA 11.8...
echo       This may take several minutes...
pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu118
echo       [OK] PyTorch installed

REM Install openmim
echo [6/8] Installing OpenMMLab package manager...
pip install -U openmim
echo       [OK] openmim installed

REM Install mmcv via mim
echo [7/8] Installing mmcv (OpenMMLab)...
echo       This may take several minutes...
mim install mmcv==2.1.0
echo       [OK] mmcv installed

REM Install mmdet and mmpose
echo       Installing mmdet and mmpose...
pip install "mmdet>=3.3.0" "mmpose>=1.3.0"
echo       [OK] OpenMMLab packages installed

REM Install remaining dependencies
echo [8/8] Installing remaining dependencies...
pip install -r requirements.txt
echo       [OK] All dependencies installed

REM Verify installation
echo.
echo === Verifying Installation ===
echo.

echo Checking PyTorch...
python -c "import torch; print(f'  PyTorch: {torch.__version__}'); print(f'  CUDA Available: {torch.cuda.is_available()}'); print(f'  CUDA Version: {torch.version.cuda if torch.cuda.is_available() else \"N/A\"}')"

echo.
echo Checking OpenMMLab...
python -c "try: import mmcv; print(f'  mmcv: {mmcv.__version__}') \nexcept: print('  mmcv: FAILED') \ntry: import mmdet; print(f'  mmdet: {mmdet.__version__}') \nexcept: print('  mmdet: FAILED') \ntry: import mmpose; print(f'  mmpose: {mmpose.__version__}') \nexcept: print('  mmpose: FAILED')"

echo.
echo === Installation Complete ===
echo.
echo Next steps:
echo   1. Set up environment variables (.env file)
echo   2. Run server: python server.py
echo   3. Test: curl http://localhost:8001/health
echo.

pause
