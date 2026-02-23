@echo off
REM Fix opencv-python version conflict

echo.
echo Fixing opencv-python (downgrade to 4.9.x)...
echo.

venv\Scripts\pip.exe uninstall opencv-python -y
venv\Scripts\pip.exe install "opencv-python>=4.8.0,<4.10.0"

echo.
echo Fixed! Starting server...
echo.
venv\Scripts\python.exe server.py
