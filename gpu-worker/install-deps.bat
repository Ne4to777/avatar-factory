@echo off
REM Install dependencies to current venv

cd /d "%~dp0"

echo.
echo Installing dependencies...
echo.

venv\Scripts\python.exe -m pip install --upgrade pip setuptools wheel
venv\Scripts\python.exe -m pip install -r requirements.txt

echo.
echo Done!
echo.

pause
