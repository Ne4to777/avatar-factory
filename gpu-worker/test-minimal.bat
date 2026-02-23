@echo off
chcp 65001 >nul
echo ========================================
echo GPU Server Minimal Test (480p)
echo ========================================
echo.

set API_KEY=your-secret-gpu-key-change-this
set HOST=http://localhost:8001

echo [1/3] Health check...
curl -s -X GET "%HOST%/health" -H "x-api-key: %API_KEY%" > test-health.json
if errorlevel 1 (
    echo [ERROR] Health check failed
    pause
    exit /b 1
)
type test-health.json
echo.
echo [OK] Server is healthy
echo.

echo [2/3] Generating TTS (short Russian text)...
curl -X POST "%HOST%/api/tts?text=%%D0%%9F%%D1%%80%%D0%%B8%%D0%%B2%%D0%%B5%%D1%%82&speaker=xenia" -H "x-api-key: %API_KEY%" --output test-minimal-audio.wav -w "\nHTTP: %%{http_code}\n"
if errorlevel 1 (
    echo [ERROR] TTS failed
    pause
    exit /b 1
)
echo [OK] TTS generated: test-minimal-audio.wav
echo.

echo [3/3] Generating background (480x480)...
curl -X POST "%HOST%/api/generate-background?prompt=simple+white+background&negative_prompt=complex&width=480&height=480" -H "x-api-key: %API_KEY%" --output test-minimal-bg.png -w "\nHTTP: %%{http_code}\n"
if errorlevel 1 (
    echo [ERROR] Background generation failed
    pause
    exit /b 1
)
echo [OK] Background generated: test-minimal-bg.png
echo.

echo ========================================
echo All tests passed!
echo ========================================
echo.
echo Generated files:
dir /B test-minimal-*.*
echo.
echo You can test these files:
echo   1. Play audio: test-minimal-audio.wav
echo   2. View image: test-minimal-bg.png
echo.
pause
