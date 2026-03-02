@echo off
REM ================================================================
REM Test background generation for timeout/hanging issues
REM ================================================================

set API_KEY=your-secret-gpu-key-change-this
set BASE_URL=http://localhost:8001

echo.
echo ====================================================================
echo   Testing Background Generation (Timeout Debug)
echo ====================================================================
echo.

REM Test 1: Small image (fast)
echo [Test 1/3] Small image (512x512) - should be fast
echo.

powershell -Command "$start = Get-Date; curl -X POST '%BASE_URL%/api/generate-background' -H 'x-api-key: %API_KEY%' -G --data-urlencode 'prompt=test' --data-urlencode 'width=512' --data-urlencode 'height=512' --output test_small.png; $end = Get-Date; Write-Host 'Time:' ($end - $start).TotalSeconds 'seconds'"

if %errorlevel% equ 0 (
    echo ✅ Small image OK
) else (
    echo ❌ Small image FAILED
)

echo.
pause

REM Test 2: Medium image (1024x1024)
echo [Test 2/3] Medium image (1024x1024)
echo.

powershell -Command "$start = Get-Date; curl -X POST '%BASE_URL%/api/generate-background' -H 'x-api-key: %API_KEY%' -G --data-urlencode 'prompt=test office' --data-urlencode 'width=1024' --data-urlencode 'height=1024' --output test_medium.png; $end = Get-Date; Write-Host 'Time:' ($end - $start).TotalSeconds 'seconds'"

if %errorlevel% equ 0 (
    echo ✅ Medium image OK
) else (
    echo ❌ Medium image FAILED
)

echo.
pause

REM Test 3: Large image (1080x1920) - your case
echo [Test 3/3] Large image (1080x1920) - PROBLEM SIZE
echo.
echo Watch server logs for:
echo   - "SDXL inference complete"
echo   - "Saving image to: ..."
echo   - "Background generated: ... (X.XX MB)"
echo.

powershell -Command "$start = Get-Date; curl -X POST '%BASE_URL%/api/generate-background' -H 'x-api-key: %API_KEY%' -G --data-urlencode 'prompt=elegant corporate meeting room' --data-urlencode 'width=1080' --data-urlencode 'height=1920' --output test_large.png --max-time 300; $end = Get-Date; Write-Host 'Time:' ($end - $start).TotalSeconds 'seconds'"

if %errorlevel% equ 0 (
    echo ✅ Large image OK
    dir test_large.png
) else (
    echo ❌ Large image FAILED or TIMEOUT
    echo Check server logs for where it stopped
)

echo.
echo ====================================================================
echo   Test Summary
echo ====================================================================
echo.

if exist test_small.png echo ✅ test_small.png: 
if exist test_small.png powershell -Command "(Get-Item test_small.png).length/1MB"

if exist test_medium.png echo ✅ test_medium.png: 
if exist test_medium.png powershell -Command "(Get-Item test_medium.png).length/1MB"

if exist test_large.png echo ✅ test_large.png: 
if exist test_large.png powershell -Command "(Get-Item test_large.png).length/1MB"

echo.
echo Check server logs: logs\server.log
echo Look for timing info and where it might hang
echo.

pause

REM Cleanup
echo.
echo Delete test files? (Y/N)
choice /C YN /M "Delete test_*.png"
if %errorlevel% equ 1 (
    del /Q test_*.png 2>nul
    echo ✅ Test files deleted
)
