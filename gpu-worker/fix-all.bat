@echo off
REM Fix all dependency issues

cd /d "%~dp0"

echo.
echo Fixing all dependencies...
echo.

echo [1/4] Reinstalling setuptools...
venv\Scripts\python.exe -m pip install --force-reinstall setuptools

echo.
echo [2/4] Installing correct versions...
venv\Scripts\python.exe -m pip install diffusers==0.25.1 transformers==4.36.2 accelerate==0.25.0 huggingface-hub==0.20.3

echo.
echo [3/4] Verifying imports...
venv\Scripts\python.exe -c "import pkg_resources; print('pkg_resources: OK')"
venv\Scripts\python.exe -c "import diffusers; print('diffusers: OK')"

echo.
echo [4/4] Starting server...
venv\Scripts\python.exe server.py

pause
