# MuseTalk Installation Script for Windows
# Downloads MuseTalk repository and models

param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Write-ColorMsg($msg, $color = "White") {
    Write-Host $msg -ForegroundColor $color
}

Write-Host "============================================================"
Write-Host "[>] MuseTalk Installation" -ForegroundColor Cyan
Write-Host "============================================================"
Write-Host ""

# CRITICAL: Check if server is running
Write-ColorMsg "[!] IMPORTANT: Server must be stopped before installation" Yellow
Write-Host ""

$serverRunning = $false

# Check Windows Service
$service = Get-Service -Name "AvatarFactoryGPU" -ErrorAction SilentlyContinue
if ($service -and $service.Status -eq 'Running') {
    Write-Host "[i] GPU Worker Windows Service is running"
    $serverRunning = $true
}

# Check for python.exe process running server.py
$pythonProcs = Get-Process python -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -like "*server.py*"
}
if ($pythonProcs) {
    Write-Host "[i] GPU Worker python process is running"
    $serverRunning = $true
}

if ($serverRunning) {
    Write-ColorMsg "[ERROR] Server is still running!" Red
    Write-Host ""
    Write-Host "Please stop the server first:"
    Write-Host "  1. Run: stop.bat"
    Write-Host "  2. Or: net stop AvatarFactoryGPU (if service)"
    Write-Host "  3. Wait 5 seconds"
    Write-Host "  4. Run this script again"
    Write-Host ""
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

Write-ColorMsg "[OK] Server is not running" Green
Write-Host ""

# Check venv and get full path
$venvPython = Resolve-Path "venv\Scripts\python.exe" -ErrorAction SilentlyContinue
if (-not $venvPython) {
    Write-ColorMsg "[ERROR] Virtual environment not found" Red
    Write-Host "  Run install.bat first"
    exit 1
}

Write-Host "[i] Using Python: $venvPython"
Write-Host ""

# Step 1: Clone MuseTalk repository
Write-ColorMsg "[1/4] Cloning MuseTalk repository..." Cyan
Write-Host ""

if (Test-Path "MuseTalk") {
    if ($Force) {
        Write-Host "[i] Removing existing MuseTalk..."
        Remove-Item -Path "MuseTalk" -Recurse -Force
    } else {
        Write-ColorMsg "[OK] MuseTalk directory already exists" Green
        Write-Host ""
    }
}

if (-not (Test-Path "MuseTalk")) {
    Write-Host "[i] Cloning from GitHub..."
    git clone https://github.com/TMElyralab/MuseTalk.git
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColorMsg "[ERROR] Failed to clone MuseTalk" Red
        exit 1
    }
    
    Write-ColorMsg "[OK] MuseTalk cloned successfully" Green
}

Write-Host ""

# Step 2: Install basic Python dependencies
Write-ColorMsg "[2/4] Installing Python dependencies..." Cyan
Write-Host ""

Write-Host "[i] Installing ffmpeg-python, moviepy, gdown..."
& $venvPython -m pip install -r musetalk-requirements.txt --quiet

if ($LASTEXITCODE -ne 0) {
    Write-ColorMsg "[ERROR] Failed to install dependencies" Red
    exit 1
}

Write-ColorMsg "[OK] Dependencies installed" Green
Write-Host ""

# Step 3: Install MuseTalk custom packages
Write-ColorMsg "[3/4] Installing MuseTalk custom packages..." Cyan
Write-Host ""

Write-Host "[i] Installing MMCM..."
& $venvPython -m pip install git+https://github.com/TMElyralab/MMCM.git@main --quiet

Write-Host "[i] Installing controlnet_aux..."
& $venvPython -m pip install git+https://github.com/TMElyralab/controlnet_aux.git@tme --quiet

Write-Host "[i] Installing IP-Adapter..."
& $venvPython -m pip install git+https://github.com/tencent-ailab/IP-Adapter.git@main --quiet

Write-Host "[i] Installing CLIP..."
& $venvPython -m pip install git+https://github.com/openai/CLIP.git@main --quiet

Write-ColorMsg "[OK] Custom packages installed" Green
Write-Host ""

# Step 4: Download MuseTalk models
Write-ColorMsg "[4/4] Downloading MuseTalk models..." Cyan
Write-Host ""

$modelsDir = "MuseTalk\models"
if (-not (Test-Path $modelsDir)) {
    New-Item -ItemType Directory -Path $modelsDir -Force | Out-Null
}

Write-Host "[i] Downloading from HuggingFace..."
Write-Host "    This will download ~2GB of models"
Write-Host ""

Push-Location "MuseTalk"
try {
    # Download using git lfs or huggingface-cli
    Write-Host "[i] Installing git-lfs if needed..."
    & $venvPython -m pip install huggingface-hub[cli] --quiet
    
    Write-Host "[i] Downloading models..."
    & $venvPython -c @"
from huggingface_hub import snapshot_download
import os

print('[i] Downloading MuseTalk models from HuggingFace...')
snapshot_download(
    repo_id='TMElyralab/MuseTalk',
    local_dir='./models',
    local_dir_use_symlinks=False
)
print('[OK] Models downloaded')
"@
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorMsg "[OK] Models downloaded successfully" Green
    } else {
        Write-ColorMsg "[ERROR] Model download failed" Red
        Write-Host "[i] You can download manually from:"
        Write-Host "    https://huggingface.co/TMElyralab/MuseTalk"
    }
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "============================================================"
Write-ColorMsg "[OK] MuseTalk Installation Complete!" Green
Write-Host "============================================================"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Restart server: .\start.bat"
Write-Host "  2. Test lip-sync API: curl -X POST http://localhost:8001/api/lipsync"
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
