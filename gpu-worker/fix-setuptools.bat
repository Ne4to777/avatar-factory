@echo off
REM Fix setuptools and openmim

echo.
echo Fixing setuptools and openmim...
echo.

echo [1/2] Upgrading setuptools...
venv\Scripts\pip.exe install --upgrade setuptools

echo.
echo [2/2] Reinstalling openmim...
venv\Scripts\pip.exe uninstall openmim -y
venv\Scripts\pip.exe install openmim

echo.
echo Done! Continue installation:
echo   install.bat
echo.
pause
