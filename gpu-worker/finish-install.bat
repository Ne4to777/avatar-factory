@echo off
REM Finish installation (requirements.txt)

cd /d "%~dp0"

echo.
echo Installing remaining dependencies...
echo.

venv\Scripts\pip.exe install -r requirements.txt

echo.
echo Done! Starting server...
echo.

venv\Scripts\python.exe server.py

pause
