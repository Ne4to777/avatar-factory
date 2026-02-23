@echo off
REM Avatar Factory GPU Worker - Open Shell Inside Container

setlocal

set "YELLOW=[93m"
set "NC=[0m"

reg add HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1

echo.
echo %YELLOW%Opening shell in GPU worker container...%NC%
echo.
echo You can run Python commands, check files, etc.
echo Type 'exit' to leave the container shell.
echo.

docker exec -it avatar-gpu-worker /bin/bash

if %errorLevel% neq 0 (
    echo.
    echo Container is not running. Start it with: docker-start.bat
    pause
)
