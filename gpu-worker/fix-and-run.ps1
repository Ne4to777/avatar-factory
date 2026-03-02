# ================================================================
# Avatar Factory GPU Worker - Fix and Run Script (PowerShell)
# ================================================================
# Fixes common issues and starts the server
# Usage: .\fix-and-run.ps1
# ================================================================

Write-Host "=== GPU Worker Fix & Run ===" -ForegroundColor Cyan
Write-Host ""

# Check if venv exists
if (-not (Test-Path "venv")) {
    Write-Host "[ERROR] venv not found. Run 'python -m venv venv' first" -ForegroundColor Red
    exit 1
}

# Activate venv
Write-Host "[1/6] Activating virtual environment..." -ForegroundColor Yellow
& "venv\Scripts\Activate.ps1"

# Remove openxlab (causes setuptools conflicts)
Write-Host "[2/6] Removing openxlab (causes conflicts)..." -ForegroundColor Yellow
pip uninstall -y openxlab 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "      openxlab removed" -ForegroundColor Gray
} else {
    Write-Host "      openxlab not installed (OK)" -ForegroundColor Gray
}

# Reinstall setuptools
Write-Host "[3/6] Reinstalling setuptools..." -ForegroundColor Yellow
pip install --force-reinstall setuptools==69.0.0
Write-Host "      setuptools reinstalled" -ForegroundColor Green

# Check pkg_resources
Write-Host "[4/6] Checking pkg_resources..." -ForegroundColor Yellow
python -c "import pkg_resources; print('  pkg_resources: OK')"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] pkg_resources still not available" -ForegroundColor Red
    exit 1
}

# Check/Install mmcv
Write-Host "[5/6] Checking OpenMMLab packages..." -ForegroundColor Yellow
python -c "import mmcv; print(f'  mmcv: {mmcv.__version__}')" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "      mmcv not found, installing..." -ForegroundColor Gray
    pip install -U openmim
    mim install mmcv==2.1.0
    pip install "mmdet>=3.3.0" "mmpose>=1.3.0"
}

# Start server
Write-Host "[6/6] Starting GPU Worker..." -ForegroundColor Yellow
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "GPU Worker Server Starting..." -ForegroundColor Green
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

python server.py
