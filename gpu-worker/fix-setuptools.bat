@echo off
REM Fix setuptools for openmim

echo.
echo Fixing setuptools...
echo.

venv\Scripts\pip.exe install --upgrade setuptools

echo.
echo Done! Continue installation:
echo   install.bat
echo.
pause
