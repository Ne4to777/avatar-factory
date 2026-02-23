@echo off
REM Avatar Factory GPU Worker - Windows Start
REM Starts the GPU worker server on Windows

setlocal EnableDelayedExpansion

echo.
echo ============================================
echo  Avatar Factory GPU Worker (Windows)
echo ============================================
echo.

REM Check if conda environment exists
call conda activate avatar 2>nul
if %errorLevel% neq 0 (
    echo [ERROR] Conda environment 'avatar' not found!
    echo.
    echo Please run setup first:
    echo   setup-windows.bat
    echo.
    pause
    exit /b 1
)

echo [OK] Environment activated
echo.

REM Check GPU
echo Checking GPU...
python -c "import torch; exit(0 if torch.cuda.is_available() else 1)" 2>nul
if %errorLevel% neq 0 (
    echo [WARNING] GPU not detected!
    echo.
    echo Make sure NVIDIA drivers and CUDA 11.8 are installed.
    echo The server will still start but will fail at runtime.
    echo.
    pause
)

REM Start server
echo.
echo ============================================
echo  Starting server on http://localhost:8001
echo ============================================
echo.
echo Press Ctrl+C to stop
echo.

python server.py

pause
