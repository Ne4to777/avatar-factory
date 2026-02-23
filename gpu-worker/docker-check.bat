@echo off
REM Avatar Factory GPU Worker - Check Docker Requirements

setlocal EnableDelayedExpansion

set "GREEN=[92m"
set "YELLOW=[93m"
set "RED=[91m"
set "BLUE=[94m"
set "NC=[0m"

reg add HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1

cls
echo.
echo %BLUE%========================================%NC%
echo %BLUE% Docker Requirements Check%NC%
echo %BLUE%========================================%NC%
echo.

REM 1. Docker Desktop
echo %YELLOW%[1/5] Docker Desktop...%NC%
docker version >nul 2>&1
if %errorLevel% equ 0 (
    docker version --format "  {{.Server.Version}}" 2>nul
    echo %GREEN%  OK - Docker is running%NC%
) else (
    echo %RED%  FAILED - Docker not running%NC%
    echo.
    echo  Install Docker Desktop:
    echo  https://docs.docker.com/desktop/install/windows-install/
)
echo.

REM 2. WSL 2
echo %YELLOW%[2/5] WSL 2...%NC%
wsl --status >nul 2>&1
if %errorLevel% equ 0 (
    echo %GREEN%  OK - WSL 2 is available%NC%
) else (
    echo %YELLOW%  WARNING - WSL 2 not detected%NC%
    echo.
    echo  Docker Desktop requires WSL 2
    echo  Install: wsl --install
)
echo.

REM 3. NVIDIA GPU
echo %YELLOW%[3/5] NVIDIA GPU...%NC%
nvidia-smi >nul 2>&1
if %errorLevel% equ 0 (
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
    echo %GREEN%  OK - NVIDIA GPU detected%NC%
) else (
    echo %RED%  FAILED - nvidia-smi not found%NC%
    echo.
    echo  Install NVIDIA drivers:
    echo  https://www.nvidia.com/Download/index.aspx
)
echo.

REM 4. NVIDIA Container Toolkit (in Docker)
echo %YELLOW%[4/5] NVIDIA Container Toolkit...%NC%
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi >nul 2>&1
if %errorLevel% equ 0 (
    echo %GREEN%  OK - GPU works in Docker%NC%
) else (
    echo %RED%  FAILED - GPU not available in Docker%NC%
    echo.
    echo  To enable GPU in Docker:
    echo.
    echo  1. Open WSL terminal: wsl
    echo  2. Run these Linux commands in WSL:
    echo.
    echo     curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey ^| sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    echo     distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    echo     curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list ^| sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' ^| sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    echo     sudo apt-get update
    echo     sudo apt-get install -y nvidia-container-toolkit
    echo     sudo nvidia-ctk runtime configure --runtime=docker
    echo     sudo systemctl restart docker
    echo.
    echo  3. Exit WSL: exit
    echo.
    echo  Full guide: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html
)
echo.

REM 5. Disk Space
echo %YELLOW%[5/5] Disk Space...%NC%
for /f "tokens=3" %%a in ('dir /-c "%cd%" ^| findstr /C:"bytes free"') do set FREE_SPACE=%%a
set /a FREE_GB=%FREE_SPACE:~0,-9%
if %FREE_GB% gtr 30 (
    echo %GREEN%  OK - %FREE_GB%GB free%NC%
) else (
    echo %YELLOW%  WARNING - Only %FREE_GB%GB free%NC%
    echo  Recommended: 30GB+ free space
)

echo.
echo %BLUE%========================================%NC%
echo.

REM Check if container exists
docker ps -a --filter name=avatar-gpu-worker --format "{{.Names}}" | findstr "avatar-gpu-worker" >nul 2>&1
if %errorLevel% equ 0 (
    echo %BLUE%Container status:%NC%
    docker ps -a --filter name=avatar-gpu-worker --format "  Name: {{.Names}}\n  Status: {{.Status}}\n  Ports: {{.Ports}}"
    echo.
    
    REM Check if running
    docker ps --filter name=avatar-gpu-worker --format "{{.Names}}" | findstr "avatar-gpu-worker" >nul 2>&1
    if %errorLevel% equ 0 (
        echo %GREEN%GPU Worker is running%NC%
        echo.
        echo Test server:
        echo   powershell -Command "Invoke-RestMethod -Uri 'http://localhost:8001/health'"
    ) else (
        echo %YELLOW%GPU Worker container exists but is stopped%NC%
        echo.
        echo Start it:
        echo   docker-restart.bat
    )
) else (
    echo %YELLOW%No container found%NC%
    echo.
    echo Create and start:
    echo   docker-start.bat
)

echo.
pause
