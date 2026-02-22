@echo off
echo Checking AvatarFactoryGPU service status...
echo.

sc query AvatarFactoryGPU 2>&1
echo.
echo ErrorLevel after sc query: %errorLevel%
echo.

echo Checking if RUNNING:
sc query AvatarFactoryGPU | findstr "RUNNING"
echo ErrorLevel after findstr: %errorLevel%
echo.

echo Checking port 8001:
netstat -ano | findstr ":8001"
echo.

pause
