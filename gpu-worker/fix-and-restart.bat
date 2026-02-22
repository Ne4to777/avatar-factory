@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

REM Получаем директорию где находится этот скрипт
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

echo.
echo ============================================================
echo [^>] Fixing Issues and Restarting GPU Worker
echo ============================================================
echo.
echo Script location: %SCRIPT_DIR%
echo Working directory: %CD%
echo.

REM Проверка что мы в правильной директории
if not exist "stop.bat" (
    echo [ERROR] stop.bat not found in current directory
    echo.
    echo This script must be run from gpu-worker directory:
    echo   cd C:\dev\avatar-factory\gpu-worker
    echo   fix-and-restart.bat
    echo.
    echo Or use full path:
    echo   C:\dev\avatar-factory\gpu-worker\fix-and-restart.bat
    echo.
    pause
    exit /b 1
)

if not exist "start.bat" (
    echo [ERROR] start.bat not found
    echo   Make sure you are in gpu-worker directory
    pause
    exit /b 1
)

REM Остановка сервера
echo [i] Stopping server...
call stop.bat >nul 2>&1

REM Ожидание полной остановки
timeout /t 2 /nobreak >nul

REM Очистка поврежденного torch.hub кеша для Silero TTS
echo [i] Clearing corrupted torch hub cache...
set "CACHE_DIR=%USERPROFILE%\.cache\torch\hub\snakers4_silero-models_master"
if exist "%CACHE_DIR%" (
    rd /s /q "%CACHE_DIR%" 2>nul
    echo [OK] Cache cleared: %CACHE_DIR%
) else (
    echo [i] Cache directory not found, skipping
)

REM Очистка временных файлов
echo [i] Cleaning temp directory...
if exist "%SCRIPT_DIR%temp" (
    rd /s /q "%SCRIPT_DIR%temp" 2>nul
    echo [OK] Temp directory cleaned
) else (
    echo [i] Temp directory not found, skipping
)

echo.
echo [i] Starting server with updated code...
echo.

REM Запуск сервера
if exist "%SCRIPT_DIR%start.bat" (
    call "%SCRIPT_DIR%start.bat"
) else (
    echo [ERROR] start.bat not found in %SCRIPT_DIR%
    echo.
    echo Please run this script from gpu-worker directory
    pause
    exit /b 1
)

echo.
echo ============================================================
echo [OK] Server restarted
echo ============================================================
echo.
echo Check status:
echo   curl http://localhost:8001/health
echo.
pause
