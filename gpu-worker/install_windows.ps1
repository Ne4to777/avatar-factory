# ================================================================
# Avatar Factory GPU Worker - Windows Installation Script
# ================================================================
# 
# Prerequisites:
# - Python 3.10 or 3.11
# - CUDA 11.8 installed
# - NVIDIA GPU with compute capability 7.0+
#
# Usage:
#   .\install_windows.ps1
# ================================================================

Write-Host "=== Avatar Factory GPU Worker - Windows Setup ===" -ForegroundColor Cyan
Write-Host ""

# Check Python version
Write-Host "[1/8] Checking Python version..." -ForegroundColor Yellow
$pythonVersion = python --version 2>&1
Write-Host "      $pythonVersion" -ForegroundColor Gray

if ($pythonVersion -notmatch "Python 3\.(10|11)") {
    Write-Host "[ERROR] Python 3.10 or 3.11 required" -ForegroundColor Red
    exit 1
}
Write-Host "      [OK] Python version compatible" -ForegroundColor Green

# Create venv if not exists
if (-not (Test-Path "venv")) {
    Write-Host "[2/8] Creating virtual environment..." -ForegroundColor Yellow
    python -m venv venv
    Write-Host "      [OK] Virtual environment created" -ForegroundColor Green
} else {
    Write-Host "[2/8] Virtual environment already exists" -ForegroundColor Gray
}

# Activate venv
Write-Host "[3/8] Activating virtual environment..." -ForegroundColor Yellow
& "venv\Scripts\Activate.ps1"

# Upgrade pip, setuptools, wheel
Write-Host "[4/8] Upgrading pip, setuptools, wheel..." -ForegroundColor Yellow
python -m pip install --upgrade pip setuptools wheel
Write-Host "      [OK] Base tools upgraded" -ForegroundColor Green

# Install PyTorch with CUDA 11.8
Write-Host "[5/8] Installing PyTorch 2.1.0 + CUDA 11.8..." -ForegroundColor Yellow
Write-Host "      This may take several minutes..." -ForegroundColor Gray
pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu118
Write-Host "      [OK] PyTorch installed" -ForegroundColor Green

# Install openmim
Write-Host "[6/8] Installing OpenMMLab package manager..." -ForegroundColor Yellow
pip install -U openmim
Write-Host "      [OK] openmim installed" -ForegroundColor Green

# Install mmcv via mim
Write-Host "[7/8] Installing mmcv (OpenMMLab)..." -ForegroundColor Yellow
Write-Host "      This may take several minutes..." -ForegroundColor Gray
mim install mmcv==2.1.0

# Alternative if mim fails:
# pip install mmcv==2.1.0 -f https://download.openmmlab.com/mmcv/dist/cu118/torch2.1/index.html

Write-Host "      [OK] mmcv installed" -ForegroundColor Green

# Install mmdet and mmpose
Write-Host "      Installing mmdet and mmpose..." -ForegroundColor Gray
pip install mmdet>=3.3.0 mmpose>=1.3.0
Write-Host "      [OK] OpenMMLab packages installed" -ForegroundColor Green

# Install remaining dependencies
Write-Host "[8/8] Installing remaining dependencies..." -ForegroundColor Yellow
pip install -r requirements.txt
Write-Host "      [OK] All dependencies installed" -ForegroundColor Green

# Verify installation
Write-Host ""
Write-Host "=== Verifying Installation ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "Checking PyTorch..." -ForegroundColor Yellow
python -c "import torch; print(f'  PyTorch: {torch.__version__}'); print(f'  CUDA Available: {torch.cuda.is_available()}'); print(f'  CUDA Version: {torch.version.cuda if torch.cuda.is_available() else \"N/A\"}')"

Write-Host ""
Write-Host "Checking OpenMMLab..." -ForegroundColor Yellow
python -c "try:
    import mmcv; print(f'  mmcv: {mmcv.__version__}')
except: print('  mmcv: FAILED')
try:
    import mmdet; print(f'  mmdet: {mmdet.__version__}')
except: print('  mmdet: FAILED')
try:
    import mmpose; print(f'  mmpose: {mmpose.__version__}')
except: print('  mmpose: FAILED')"

Write-Host ""
Write-Host "=== Installation Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Set up environment variables (.env file)"
Write-Host "  2. Run server: python server.py"
Write-Host "  3. Test: curl http://localhost:8001/health"
Write-Host ""
