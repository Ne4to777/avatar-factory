@echo off
REM Avatar Factory GPU Worker - View Logs

setlocal

echo.
echo Showing GPU worker logs (Ctrl+C to exit)...
echo.

docker logs -f avatar-gpu-worker
