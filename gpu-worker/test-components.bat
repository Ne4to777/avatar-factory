@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

echo.
echo ============================================================
echo [^>] Component Testing - Avatar Factory GPU Worker
echo ============================================================
echo.

set VENV_PYTHON=venv\Scripts\python.exe

if not exist "%VENV_PYTHON%" (
    echo [ERROR] Virtual environment not found
    echo   Run install.bat first
    pause
    exit /b 1
)

echo [i] Testing Python environment...
echo.

REM Test 1: Python version
echo [1/5] Python Version
"%VENV_PYTHON%" --version
if !errorLevel! neq 0 (
    echo [ERROR] Python test failed
    pause
    exit /b 1
)
echo.

REM Test 2: PyTorch and CUDA
echo [2/5] PyTorch ^& CUDA
"%VENV_PYTHON%" -c "import torch; print('  PyTorch:', torch.__version__); print('  CUDA available:', torch.cuda.is_available()); print('  CUDA version:', torch.version.cuda if torch.cuda.is_available() else 'N/A')"
if !errorLevel! neq 0 (
    echo [ERROR] PyTorch test failed
    pause
    exit /b 1
)
echo.

REM Test 3: Core dependencies
echo [3/5] Core Dependencies
"%VENV_PYTHON%" -c "import fastapi, uvicorn, diffusers, transformers; print('  FastAPI: OK'); print('  Diffusers: OK'); print('  Transformers: OK')"
if !errorLevel! neq 0 (
    echo [ERROR] Dependency test failed
    pause
    exit /b 1
)
echo.

REM Test 4: Silero TTS
echo [4/5] Silero TTS
"%VENV_PYTHON%" -c "import torch; model, _ = torch.hub.load('snakers4/silero-models', 'silero_tts', language='ru', speaker='v3_1_ru'); print('  Silero TTS: OK')" 2>nul
if !errorLevel! neq 0 (
    echo [!] Silero TTS: FAILED (corrupted cache)
    echo   Fix: run fix-and-restart.bat
) else (
    echo [OK] Silero TTS: OK
)
echo.

REM Test 5: MuseTalk
echo [5/5] MuseTalk
"%VENV_PYTHON%" -c "from musetalk_inference import test_musetalk; test_musetalk()" 2>nul
if !errorLevel! neq 0 (
    echo [!] MuseTalk: NOT INSTALLED
    echo   Install: powershell -ExecutionPolicy Bypass -File install-musetalk.ps1
) else (
    echo [OK] MuseTalk: OK
)
echo.

echo ============================================================
echo [OK] Component Testing Complete
echo ============================================================
echo.
echo Next steps:
echo   1. If any component failed, follow the fix instructions above
echo   2. Start server: start.bat
echo   3. Test API: see TEST-API.md
echo.
pause
