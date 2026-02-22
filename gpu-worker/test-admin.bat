@echo off
REM Test admin rights detection

echo Testing admin detection...
echo.

net session >nul 2>&1
echo net session exit code: %errorLevel%
echo.

if %errorLevel% neq 0 (
    echo FAILED: Not admin
) else (
    echo SUCCESS: Running as admin
)

echo.
pause
