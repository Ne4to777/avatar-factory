@echo off
REM Avatar Factory GPU Worker - Stop Script for Windows
REM Stops server whether running as Windows Service or manual process

setlocal EnableDelayedExpansion

set "GREEN=[92m"
set "YELLOW=[93m"
set "RED=[91m"
set "BLUE=[94m"
set "NC=[0m"

reg add HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1

cd /d "%~dp0"

echo.
echo %BLUE%Avatar Factory GPU Worker - Stopping...%NC%
echo.

REM Check if running as Windows Service
sc query AvatarFactoryGPU >nul 2>&1
if %errorLevel% equ 0 (
    sc query AvatarFactoryGPU | findstr "RUNNING" >nul 2>&1
    if !errorLevel! equ 0 (
        echo %BLUE%Stopping Windows Service...%NC%
        net stop AvatarFactoryGPU
        if !errorLevel! equ 0 (
            echo %GREEN%Service stopped successfully.%NC%
        ) else (
            echo %RED%Failed to stop service. Run as Administrator.%NC%
            echo   Try: net stop AvatarFactoryGPU
        )
        echo.
        pause
        exit /b 0
    )
)

REM Find process on port 8001
set "PID="
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":8001" ^| findstr "LISTENING"') do (
    set "PID=%%a"
    goto :found_pid
)
:found_pid

if not defined PID (
    echo %GREEN%No GPU server process found on port 8001.%NC%
    echo %GREEN%Server is not running.%NC%
    echo.
    pause
    exit /b 0
)

REM Try graceful shutdown first (sends WM_CLOSE)
echo %BLUE%Stopping process (PID !PID!)...%NC%
taskkill /PID !PID! /T >nul 2>&1

REM Wait briefly
timeout /t 2 /nobreak >nul

REM Verify stopped; force kill if still running
netstat -ano | findstr ":8001" | findstr "LISTENING" >nul 2>&1
if !errorLevel! equ 0 (
    echo %YELLOW%Process still running, forcing...%NC%
    taskkill /PID !PID! /F /T >nul 2>&1
    timeout /t 1 /nobreak >nul
)

REM Final verification
netstat -ano | findstr ":8001" | findstr "LISTENING" >nul 2>&1
if !errorLevel! equ 0 (
    echo %RED%Warning: Process may still be running. Try: taskkill /PID !PID! /F%NC%
) else (
    echo %GREEN%GPU server stopped successfully.%NC%
)

echo.
pause
exit /b 0
