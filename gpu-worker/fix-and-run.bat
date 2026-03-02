@echo off
REM ================================================================
REM Avatar Factory GPU Worker - Fix and Run Script (CMD)
REM ================================================================
REM Fixes common issues and starts the server
REM Usage: fix-and-run.bat
REM ================================================================

echo === GPU Worker Fix ^& Run ===
echo.

REM Check if venv exists
if not exist "venv" (
    echo [ERROR] venv not found. Run 'python -m venv venv' first
    exit /b 1
)

REM Activate venv
echo [1/6] Activating virtual environment...
call venv\Scripts\activate.bat

REM Remove openxlab
echo [2/6] Removing openxlab (causes conflicts)...
pip uninstall -y openxlab >nul 2>&1
echo       Done

REM Reinstall setuptools
echo [3/6] Reinstalling setuptools...
pip install --force-reinstall setuptools==69.0.0
echo       setuptools reinstalled

REM Check pkg_resources
echo [4/6] Checking pkg_resources...
python -c "import pkg_resources; print('  pkg_resources: OK')"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] pkg_resources still not available
    exit /b 1
)

REM Check/Install mmcv
echo [5/6] Checking OpenMMLab packages...
python -c "import mmcv; print(f'  mmcv: {mmcv.__version__}')" 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo       mmcv not found, installing...
    pip install -U openmim
    mim install mmcv==2.1.0
    pip install "mmdet>=3.3.0" "mmpose>=1.3.0"
)

REM Start server
echo [6/6] Starting GPU Worker...
echo.
echo ============================================
echo GPU Worker Server Starting...
echo Press Ctrl+C to stop
echo ============================================
echo.

python server.py
