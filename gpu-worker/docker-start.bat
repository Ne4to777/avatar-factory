@echo off
REM Avatar Factory GPU Worker - Docker Start (Windows)
REM Builds and starts GPU worker in Docker container

setlocal EnableDelayedExpansion

REM Colors
set "GREEN=[92m"
set "YELLOW=[93m"
set "RED=[91m"
set "BLUE=[94m"
set "NC=[0m"

reg add HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1

echo.
echo %BLUE%========================================%NC%
echo %BLUE% Avatar Factory GPU Worker - Docker%NC%
echo %BLUE%========================================%NC%
echo.

REM Change to script directory
cd /d "%~dp0"

REM Check Docker
echo %YELLOW%[1/5] Checking Docker...%NC%
docker version >nul 2>&1
if %errorLevel% neq 0 (
    echo %RED%ERROR: Docker is not running%NC%
    echo.
    echo Please install and start Docker Desktop for Windows:
    echo https://docs.docker.com/desktop/install/windows-install/
    echo.
    pause
    exit /b 1
)
echo %GREEN%  Docker is running%NC%

REM Check NVIDIA Container Toolkit
echo.
echo %YELLOW%[2/5] Checking NVIDIA GPU support...%NC%
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi >nul 2>&1
if %errorLevel% neq 0 (
    echo %RED%WARNING: NVIDIA Container Toolkit not detected%NC%
    echo.
    echo To use GPU in Docker, install NVIDIA Container Toolkit:
    echo https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html
    echo.
    set /p CONTINUE="Continue without GPU? (y/N): "
    if /i not "!CONTINUE!"=="y" (
        exit /b 1
    )
    echo %YELLOW%  Continuing without GPU support...%NC%
) else (
    echo %GREEN%  NVIDIA GPU support detected%NC%
)

REM Check .env
echo.
echo %YELLOW%[3/5] Checking configuration...%NC%
if not exist ".env" (
    echo %YELLOW%  .env not found, creating default...%NC%
    (
        echo GPU_API_KEY=%RANDOM%%RANDOM%%RANDOM%%RANDOM%
        echo HOST=0.0.0.0
        echo PORT=8001
        echo CUDA_VISIBLE_DEVICES=0
    ) > .env
    echo %GREEN%  Created .env%NC%
) else (
    echo %GREEN%  .env exists%NC%
)

REM Build image
echo.
echo %YELLOW%[4/5] Building Docker image...%NC%
echo %BLUE%  This may take 10-20 minutes on first build%NC%
echo %BLUE%  (downloads ~5GB of dependencies)%NC%
echo.

docker build -t avatar-gpu-worker:latest .
if %errorLevel% neq 0 (
    echo.
    echo %RED%ERROR: Docker build failed%NC%
    echo.
    echo Check the output above for errors.
    echo Common issues:
    echo   - Network connection problems
    echo   - Insufficient disk space
    echo   - CUDA/Python dependency conflicts
    echo.
    pause
    exit /b 1
)
echo %GREEN%  Build successful%NC%

REM Start container
echo.
echo %YELLOW%[5/5] Starting GPU worker container...%NC%

REM Stop existing container if running
docker stop avatar-gpu-worker >nul 2>&1
docker rm avatar-gpu-worker >nul 2>&1

REM Start new container
docker run -d ^
    --name avatar-gpu-worker ^
    --gpus all ^
    -p 8001:8001 ^
    --env-file .env ^
    --restart unless-stopped ^
    -v "%cd%\checkpoints:/app/checkpoints" ^
    -v "%cd%\models:/app/models" ^
    avatar-gpu-worker:latest

if %errorLevel% neq 0 (
    echo.
    echo %RED%ERROR: Failed to start container%NC%
    echo.
    echo Try without GPU:
    echo   docker run -d --name avatar-gpu-worker -p 8001:8001 --env-file .env avatar-gpu-worker:latest
    echo.
    pause
    exit /b 1
)

echo %GREEN%  Container started%NC%

REM Wait for startup
echo.
echo %BLUE%Waiting for server to start...%NC%
timeout /t 10 /nobreak >nul

REM Check health
echo.
echo %YELLOW%Testing server health...%NC%

REM Use PowerShell to check health (works without curl)
powershell -Command "try { $response = Invoke-WebRequest -Uri 'http://localhost:8001/health' -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop; exit 0 } catch { exit 1 }" >nul 2>&1

if %errorLevel% equ 0 (
    echo %GREEN%  Server is healthy!%NC%
    echo.
    echo %GREEN%========================================%NC%
    echo %GREEN% GPU Worker is running!%NC%
    echo %GREEN%========================================%NC%
    echo.
    echo Server URL: http://localhost:8001
    echo API Key: (check .env file)
    echo.
    echo Commands:
    echo   View logs:    docker logs -f avatar-gpu-worker
    echo   Stop server:  docker-stop.bat
    echo   Restart:      docker-restart.bat
    echo.
    echo Test API:
    echo   powershell -Command "Invoke-RestMethod -Uri 'http://localhost:8001/health'"
    echo.
) else (
    echo %YELLOW%  Server is starting... (may take 1-2 minutes)%NC%
    echo.
    echo View startup logs:
    echo   docker logs -f avatar-gpu-worker
    echo.
    echo Check health when ready:
    echo   powershell -Command "Invoke-RestMethod -Uri 'http://localhost:8001/health'"
    echo.
)

pause
