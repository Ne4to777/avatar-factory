@echo off
REM Avatar Factory GPU Worker - Stop Script for Windows
REM Stops server whether running as Windows Service or manual process

setlocal EnableDelayedExpansion

cd /d "%~dp0"

echo.
echo ========================================
echo  Avatar Factory GPU Worker - Stopping
echo ========================================
echo.

REM Check if running as Windows Service
sc query AvatarFactoryGPU >nul 2>&1
if %errorLevel% equ 0 (
    sc query AvatarFactoryGPU | findstr /C:"STATE" | findstr /C:"RUNNING" >nul 2>&1
    if %errorLevel% equ 0 (
        echo [i] Stopping Windows Service...
        net stop AvatarFactoryGPU
        if !errorLevel! equ 0 (
            echo [OK] Service stopped successfully
        ) else (
            echo [ERROR] Failed to stop service. Run as Administrator
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
    echo [OK] No GPU server process found on port 8001
    echo [OK] Server is not running
    echo.
    pause
    exit /b 0
)

REM Try graceful shutdown first (sends WM_CLOSE)
echo [i] Stopping process (PID !PID!)...
taskkill /PID !PID! /T >nul 2>&1

REM Wait briefly
timeout /t 2 /nobreak >nul

REM Verify stopped; force kill if still running
netstat -ano | findstr ":8001" | findstr "LISTENING" >nul 2>&1
if !errorLevel! equ 0 (
    echo [!] Process still running, forcing...
    taskkill /PID !PID! /F /T >nul 2>&1
    timeout /t 1 /nobreak >nul
)

REM Final verification
netstat -ano | findstr ":8001" | findstr "LISTENING" >nul 2>&1
if !errorLevel! equ 0 (
    echo [ERROR] Warning: Process may still be running. Try: taskkill /PID !PID! /F
) else (
    echo [OK] GPU server stopped successfully
)

echo.
pause
exit /b 0
