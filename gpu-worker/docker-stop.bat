@echo off
REM Avatar Factory GPU Worker - Docker Stop

setlocal

set "GREEN=[92m"
set "YELLOW=[93m"
set "NC=[0m"

reg add HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1

echo.
echo %YELLOW%Stopping GPU worker container...%NC%

docker stop avatar-gpu-worker
if %errorLevel% equ 0 (
    echo %GREEN%Container stopped%NC%
) else (
    echo %YELLOW%Container was not running%NC%
)

echo.
set /p REMOVE="Remove container? (y/N): "
if /i "%REMOVE%"=="y" (
    docker rm avatar-gpu-worker
    echo %GREEN%Container removed%NC%
)

echo.
pause
