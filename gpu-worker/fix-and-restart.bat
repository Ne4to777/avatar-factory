@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

echo.
echo ============================================================
echo [^>] Fixing Issues and Restarting GPU Worker
echo ============================================================
echo.

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
if exist "temp" (
    rd /s /q "temp" 2>nul
    echo [OK] Temp directory cleaned
)

echo.
echo [i] Starting server with updated code...
echo.

REM Запуск сервера
call start.bat

echo.
echo ============================================================
echo [OK] Server restarted
echo ============================================================
echo.
echo Check status:
echo   curl http://localhost:8001/health
echo.
pause
