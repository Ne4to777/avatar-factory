@echo off
REM ================================================================
REM Тестирование новых endpoints
REM ================================================================

echo.
echo ====================================================================
echo   Testing NEW Endpoints - Avatar Factory
echo ====================================================================
echo.

set API_KEY=your-secret-gpu-key-change-this
set BASE_URL=http://localhost:8001

REM ================================================================
REM Проверка доступности сервера
REM ================================================================

echo [1/5] Checking server health...
curl -s %BASE_URL%/health | python -m json.tool
if %errorlevel% neq 0 (
    echo ❌ Server not running or not responding
    echo Start server: python server.py
    pause
    exit /b 1
)
echo.
echo ✅ Server is healthy
echo.
pause

REM ================================================================
REM Тест 1: STT (Speech-to-Text)
REM ================================================================

echo.
echo ====================================================================
echo [2/5] Testing STT (Speech-to-Text)
echo ====================================================================
echo.

REM Создать тестовый аудио файл (требуется FFmpeg)
echo Creating test audio file...
echo "Привет, это тестовое аудио" > temp_text.txt

REM Если есть FFmpeg, создаем аудио из TTS
curl -X POST "%BASE_URL%/api/tts?text=Привет, это тестовое аудио&speaker=xenia" ^
     -H "x-api-key: %API_KEY%" ^
     --output test_audio.wav

if %errorlevel% neq 0 (
    echo ⚠️  Could not generate test audio
    echo Please create test_audio.wav manually
    pause
) else (
    echo ✅ Test audio created: test_audio.wav
    echo.
    
    echo Testing STT endpoint...
    curl -X POST "%BASE_URL%/api/stt" ^
         -H "x-api-key: %API_KEY%" ^
         -F "audio=@test_audio.wav" ^
         -F "language=ru"
    
    echo.
    echo.
    
    if %errorlevel% equ 0 (
        echo ✅ STT test passed
    ) else (
        echo ❌ STT test failed
    )
)

echo.
pause

REM ================================================================
REM Тест 2: Text Improvement
REM ================================================================

echo.
echo ====================================================================
echo [3/5] Testing Text Improvement
echo ====================================================================
echo.

echo Testing text improvement (professional style)...
curl -X POST "%BASE_URL%/api/improve-text" ^
     -H "x-api-key: %API_KEY%" ^
     -G ^
     --data-urlencode "text=Короче, надо сделать штуку которая будет типа работать нормально понимаешь" ^
     --data-urlencode "style=professional"

echo.
echo.

if %errorlevel% equ 0 (
    echo ✅ Text improvement test passed
) else (
    echo ❌ Text improvement test failed
)

echo.
pause

REM ================================================================
REM Тест 3: Existing endpoints (regression test)
REM ================================================================

echo.
echo ====================================================================
echo [4/5] Regression Test - Existing Endpoints
echo ====================================================================
echo.

echo Testing existing TTS endpoint...
curl -X POST "%BASE_URL%/api/tts?text=Тест&speaker=xenia" ^
     -H "x-api-key: %API_KEY%" ^
     --output test_regression_tts.wav

if %errorlevel% equ 0 (
    echo ✅ TTS still works
) else (
    echo ❌ TTS regression - broken after update!
)

echo.
echo.

echo Testing existing background generation...
curl -X POST "%BASE_URL%/api/generate-background?prompt=test&width=512&height=512" ^
     -H "x-api-key: %API_KEY%" ^
     --output test_regression_bg.png

if %errorlevel% equ 0 (
    echo ✅ Background generation still works
) else (
    echo ❌ Background generation regression - broken after update!
)

echo.
pause

REM ================================================================
REM Итоги
REM ================================================================

echo.
echo ====================================================================
echo [5/5] Test Summary
echo ====================================================================
echo.

echo Test files created:
if exist test_audio.wav echo   - test_audio.wav (STT input)
if exist test_regression_tts.wav echo   - test_regression_tts.wav (TTS output)
if exist test_regression_bg.png echo   - test_regression_bg.png (Background)

echo.
echo Cleanup test files? (Y/N)
choice /C YN /M "Delete test files"
if %errorlevel% equ 1 (
    del /Q test_*.wav test_*.png temp_text.txt 2>nul
    echo ✅ Test files cleaned
)

echo.
echo ====================================================================
echo TESTING COMPLETE
echo ====================================================================
echo.
echo Next steps:
echo 1. Review test results above
echo 2. Check server logs: logs\server.log
echo 3. Test manual audio files with STT
echo 4. Verify VRAM usage: nvidia-smi
echo.

pause
