@echo off
REM Add ONLY mmcv/mmdet/mmpose to existing venv
REM NO reinstall, NO openmim, ONLY pip

echo.
echo Installing OpenMMLab packages (pip only)...
echo.

echo [1/4] mmcv...
venv\Scripts\pip.exe install mmcv==2.1.0 -f https://download.openmmlab.com/mmcv/dist/cu118/torch2.1/index.html

echo.
echo [2/4] mmengine...
venv\Scripts\pip.exe install mmengine==0.10.3

echo.
echo [3/4] mmdet...
venv\Scripts\pip.exe install mmdet==3.3.0

echo.
echo [4/4] mmpose...
venv\Scripts\pip.exe install mmpose==1.3.1

echo.
echo Done! Starting server...
echo.
venv\Scripts\python.exe server.py

pause
