@echo off
REM Avatar Factory GPU Worker - Docker Restart

setlocal

set "GREEN=[92m"
set "YELLOW=[93m"
set "NC=[0m"

reg add HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1

echo.
echo %YELLOW%Restarting GPU worker container...%NC%

docker restart avatar-gpu-worker

if %errorLevel% equ 0 (
    echo %GREEN%Container restarted%NC%
    echo.
    echo View logs: docker logs -f avatar-gpu-worker
) else (
    echo %YELLOW%Failed to restart - container may not exist%NC%
    echo.
    echo Run docker-start.bat to create and start the container
)

echo.
pause
