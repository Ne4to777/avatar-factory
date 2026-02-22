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

Write-Host "[i] Installing OpenMMLab packages (mmcv, mmdet, mmpose)..."
Write-Host "    This may take 5-10 minutes (compiling C++ extensions)..."
Write-Host ""

# Install openmim first
Write-Host "[i] Installing openmim..."
& $venvPython -m pip install openmim --quiet

if ($LASTEXITCODE -ne 0) {
    Write-ColorMsg "[ERROR] Failed to install openmim" Red
    exit 1
}

# Install mmcv via mim (this will install openxlab as dependency)
Write-Host "[i] Installing mmcv (with C++ compilation)..."
& $venvPython -m mim install mmcv

if ($LASTEXITCODE -ne 0) {
    Write-ColorMsg "[ERROR] Failed to install mmcv" Red
    Write-Host ""
    Write-Host "[!] Common fixes:"
    Write-Host "    1. Make sure Visual Studio Build Tools are installed"
    Write-Host "    2. Restart PowerShell and try again"
    Write-Host "    3. Check: https://mmcv.readthedocs.io/en/latest/get_started/installation.html"
    Write-Host ""
    exit 1
}

# Fix dependency conflicts with openxlab (required by OpenMMLab)
Write-Host "[i] Fixing openxlab dependency conflicts..."
& $venvPython -m pip install --upgrade openxlab --quiet

# Install mmdet and mmpose
Write-Host "[i] Installing mmdet and mmpose..."
& $venvPython -m pip install mmdet mmpose --quiet

if ($LASTEXITCODE -ne 0) {
    Write-ColorMsg "[ERROR] Failed to install mmdet/mmpose" Red
    exit 1
}

Write-ColorMsg "[OK] OpenMMLab packages installed" Green
Write-Host ""

Write-Host "[i] Installing MuseTalk custom packages..."
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

# Load HF_TOKEN from .env if exists (for faster downloads)
if (Test-Path ".env") {
    Write-Host "[i] Checking for HF_TOKEN in .env..."
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^HF_TOKEN=(.+)$") {
            $env:HF_TOKEN = $matches[1].Trim()
            Write-ColorMsg "[OK] HF_TOKEN found - using authenticated requests (faster)" Green
        }
    }
}

if (-not $env:HF_TOKEN) {
    Write-Host "[!] HF_TOKEN not set - using unauthenticated requests"
    Write-Host "    Downloads will be slower but still work"
    Write-Host "    To speed up: add HF_TOKEN=your_token to .env"
    Write-Host ""
}

Write-Host "[i] Downloading from HuggingFace..."
Write-Host "    This will download ~2GB of models"
Write-Host ""

Push-Location "MuseTalk"
try {
    # Install huggingface-hub with tqdm for progress
    Write-Host "[i] Installing HuggingFace tools..."
    & $venvPython -m pip install -q huggingface-hub tqdm
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColorMsg "[ERROR] Failed to install huggingface-hub" Red
        exit 1
    }
    
    Write-Host ""
    Write-Host "[i] Downloading MuseTalk models from HuggingFace..."
    Write-Host "    Repository: TMElyralab/MuseTalk"
    Write-Host "    Size: ~2GB (this may take 5-15 minutes)"
    Write-Host ""
    
    # Download with progress bar using Python directly
    # Use cmd /c to bypass PowerShell buffering and show real-time progress
    $downloadScript = @"
import sys
import os
from huggingface_hub import snapshot_download

# Enable immediate stdout flush
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(line_buffering=True)

print('[i] Starting download...', flush=True)
print('[i] Progress will be shown by huggingface_hub', flush=True)
print('', flush=True)

try:
    # snapshot_download shows progress automatically when tqdm is installed
    snapshot_download(
        repo_id='TMElyralab/MuseTalk',
        local_dir='./models',
        local_dir_use_symlinks=False,
        resume_download=True
    )
    print('', flush=True)
    print('[OK] Download complete!', flush=True)
except Exception as e:
    print('', flush=True)
    print(f'[ERROR] Download failed: {e}', flush=True)
    sys.exit(1)
"@
    
    # Save script to temp file
    $tempScript = [System.IO.Path]::GetTempFileName() + ".py"
    $downloadScript | Out-File -FilePath $tempScript -Encoding UTF8
    
    # Run with cmd to show real-time progress
    $env:PYTHONUNBUFFERED = "1"
    cmd /c "$venvPython `"$tempScript`" 2>&1"
    $exitCode = $LASTEXITCODE
    
    # Cleanup temp script
    Remove-Item $tempScript -ErrorAction SilentlyContinue
    
    Write-Host ""
    if ($exitCode -eq 0) {
        Write-ColorMsg "[OK] Models downloaded successfully" Green
    } else {
        Write-ColorMsg "[ERROR] Model download failed (exit code: $exitCode)" Red
        Write-Host ""
        Write-Host "[!] Download failed. You can:"
        Write-Host "    1. Try again (script supports resume)"
        Write-Host "    2. Download manually - see: MANUAL-DOWNLOAD-MUSETALK.md"
        Write-Host "    3. Visit: https://huggingface.co/TMElyralab/MuseTalk"
        Write-Host ""
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
