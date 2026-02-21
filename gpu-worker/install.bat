@echo off
REM Avatar Factory GPU Worker - One-Command Installer for Windows
REM Автоматическая установка GPU сервера для Windows
REM
REM Использование: Просто запустите install.bat
REM

setlocal EnableDelayedExpansion

REM Colors (using Windows ANSI escape codes)
set "GREEN=[92m"
set "YELLOW=[93m"
set "RED=[91m"
set "BLUE=[94m"
set "NC=[0m"

REM Enable ANSI colors in Windows 10+
reg add HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1

cls
echo.
echo %BLUE%╔════════════════════════════════════════════════════════════════╗%NC%
echo %BLUE%║%NC%  🚀 Avatar Factory GPU Worker - One-Command Setup        %BLUE%║%NC%
echo %BLUE%╚════════════════════════════════════════════════════════════════╝%NC%
echo.

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo %YELLOW%⚠ Not running as Administrator%NC%
    echo %YELLOW%  Some installations may require admin rights%NC%
    echo.
)

REM Check Python
echo %BLUE%▸%NC% Checking Python...
python --version >nul 2>&1
if %errorLevel% neq 0 (
    echo %RED%✗ Python not found%NC%
    echo.
    echo %YELLOW%Please install Python 3.10+ from:%NC%
    echo https://www.python.org/downloads/
    echo.
    echo %YELLOW%Make sure to check "Add Python to PATH" during installation%NC%
    pause
    exit /b 1
) else (
    for /f "tokens=2" %%a in ('python --version 2^>^&1') do set PYTHON_VERSION=%%a
    echo %GREEN%✓ Python !PYTHON_VERSION! found%NC%
)

REM Check pip
echo %BLUE%▸%NC% Checking pip...
pip --version >nul 2>&1
if %errorLevel% neq 0 (
    echo %RED%✗ pip not found%NC%
    echo %YELLOW%Installing pip...%NC%
    python -m ensurepip --upgrade
) else (
    echo %GREEN%✓ pip found%NC%
)

REM Check CUDA/GPU
echo %BLUE%▸%NC% Checking GPU...
nvidia-smi >nul 2>&1
if %errorLevel% neq 0 (
    echo %YELLOW%⚠ nvidia-smi not found - GPU may not be available%NC%
    echo %YELLOW%  Install NVIDIA drivers and CUDA Toolkit from:%NC%
    echo %YELLOW%  https://developer.nvidia.com/cuda-downloads%NC%
) else (
    for /f "tokens=*" %%a in ('nvidia-smi --query-gpu^=name^,memory.total --format^=csv^,noheader 2^>nul ^| findstr /r "."') do (
        echo %GREEN%✓ GPU detected: %%a%NC%
        goto :gpu_found
    )
    :gpu_found
)

echo.
echo %BLUE%▸%NC% Setting up Python virtual environment...

REM Create venv if not exists
if not exist "venv" (
    python -m venv venv
    echo %GREEN%✓ Virtual environment created%NC%
) else (
    echo %GREEN%✓ Virtual environment already exists%NC%
)

REM Activate venv
call venv\Scripts\activate.bat

REM Upgrade pip
echo %BLUE%▸%NC% Upgrading pip...
python -m pip install --upgrade pip setuptools wheel >nul 2>&1
echo %GREEN%✓ pip upgraded%NC%

echo.
echo %BLUE%▸%NC% Installing PyTorch with CUDA support...
echo    This may take 5-10 minutes...
echo.

REM Install PyTorch with CUDA
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
if %errorLevel% neq 0 (
    echo %RED%✗ PyTorch installation failed%NC%
    pause
    exit /b 1
)
echo %GREEN%✓ PyTorch installed%NC%

echo.
echo %BLUE%▸%NC% Installing Python dependencies...
echo    This may take 3-5 minutes...
echo.

pip install -r requirements.txt
if %errorLevel% neq 0 (
    echo %RED%✗ Dependencies installation failed%NC%
    pause
    exit /b 1
)
echo %GREEN%✓ Python dependencies installed%NC%

echo.
echo %BLUE%▸%NC% Setting up SadTalker...

if not exist "SadTalker" (
    git clone https://github.com/OpenTalker/SadTalker.git
    cd SadTalker
    pip install -r requirements.txt
    cd ..
    echo %GREEN%✓ SadTalker cloned and installed%NC%
) else (
    echo %GREEN%✓ SadTalker already exists%NC%
)

echo.
echo %BLUE%▸%NC% Setting up environment configuration...

if not exist ".env" (
    REM Generate random API key (Windows doesn't have openssl by default)
    set "API_KEY=%RANDOM%%RANDOM%%RANDOM%%RANDOM%"
    echo GPU_API_KEY=!API_KEY! > .env
    echo HOST=0.0.0.0 >> .env
    echo PORT=8001 >> .env
    echo %GREEN%✓ .env file created%NC%
    echo.
    echo %YELLOW%━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%NC%
    echo %YELLOW%Important: Save this API key for your laptop configuration:%NC%
    echo %GREEN%!API_KEY!%NC%
    echo %YELLOW%━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%NC%
    echo.
) else (
    echo %GREEN%✓ .env file already exists%NC%
)

echo.
echo %BLUE%▸%NC% Downloading AI models...
echo    This will download ~10GB of data and may take 15-30 minutes
echo    depending on your internet speed...
echo.

set /p DOWNLOAD_MODELS="   Download models now? (y/n) [y]: "
if "!DOWNLOAD_MODELS!"=="" set DOWNLOAD_MODELS=y

if /i "!DOWNLOAD_MODELS!"=="y" (
    python download_models.py
    if %errorLevel% neq 0 (
        echo %RED%✗ Model download failed%NC%
        echo %YELLOW%You can run 'python download_models.py' manually later%NC%
    ) else (
        echo %GREEN%✓ Models downloaded%NC%
    )
) else (
    echo %YELLOW%⚠ Skipping model download%NC%
    echo %YELLOW%  Run 'python download_models.py' manually later%NC%
)

echo.
echo %BLUE%▸%NC% Testing installation...

python -c "import torch; print('✓ PyTorch:', torch.__version__)" 2>nul
python -c "import torch; print('✓ CUDA available:', torch.cuda.is_available())" 2>nul
python -c "import fastapi; print('✓ FastAPI imported')" 2>nul

if %errorLevel% neq 0 (
    echo %RED%✗ Installation test failed%NC%
) else (
    echo %GREEN%✓ Installation test passed%NC%
)

echo.
echo %GREEN%╔════════════════════════════════════════════════════════════════╗%NC%
echo %GREEN%║%NC%  ✓ Installation Complete!                                 %GREEN%║%NC%
echo %GREEN%╚════════════════════════════════════════════════════════════════╝%NC%
echo.
echo %BLUE%Next steps:%NC%
echo.
echo   1. Find your PC's IP address:
echo      %YELLOW%ipconfig%NC% (look for IPv4 Address)
echo.
echo   2. Start the GPU server:
echo      %YELLOW%start.bat%NC%
echo.
echo   3. On your laptop, update .env file:
echo      %YELLOW%GPU_SERVER_URL=http://YOUR_PC_IP:8001%NC%
echo      %YELLOW%GPU_API_KEY=^<your-api-key-from-above^>%NC%
echo.
echo   4. Test the server:
echo      %YELLOW%curl http://YOUR_PC_IP:8001/health%NC%
echo.
echo %GREEN%Documentation:%NC% README.md
echo.
echo Press any key to exit...
pause >nul
