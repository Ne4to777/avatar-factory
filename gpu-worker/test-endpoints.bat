@echo off
chcp 65001 >nul
echo ========================================
echo GPU Server API Tests
echo ========================================
echo.

set API_KEY=your-secret-gpu-key-change-this
set HOST=http://localhost:8001

echo [1/4] Testing Health Endpoint...
echo.
curl -X GET "%HOST%/health" -H "x-api-key: %API_KEY%"
echo.
echo.

echo [2/4] Testing TTS with English text...
echo.
curl -X POST "%HOST%/api/tts?text=Hello&speaker=aidar" -H "x-api-key: %API_KEY%" --output test-tts-en.wav -w "\nHTTP Status: %%{http_code}\n"
echo.
echo.

echo [3/4] Testing TTS with simple text...
echo.
curl -X POST "%HOST%/api/tts?text=Test&speaker=xenia" -H "x-api-key: %API_KEY%" --output test-tts-simple.wav -w "\nHTTP Status: %%{http_code}\n"
echo.
echo.

echo [4/4] Testing Background Generation...
echo.
curl -X POST "%HOST%/api/generate-background?prompt=modern office&negative_prompt=blurry&width=512&height=512" -H "x-api-key: %API_KEY%" --output test-bg.png -w "\nHTTP Status: %%{http_code}\n"
echo.
echo.

echo ========================================
echo Tests Complete!
echo ========================================
echo Check files: test-tts-en.wav, test-tts-simple.wav, test-bg.png
echo.
pause
