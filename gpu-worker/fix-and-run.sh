#!/bin/bash
# ================================================================
# Avatar Factory GPU Worker - Fix and Run Script
# ================================================================
# Fixes common issues and starts the server
# Usage: ./fix-and-run.sh
# ================================================================

echo "=== GPU Worker Fix & Run ==="
echo ""

# Check if venv exists
if [ ! -d "venv" ]; then
    echo "[ERROR] venv not found. Run 'python -m venv venv' first"
    exit 1
fi

# Activate venv
echo "[1/6] Activating virtual environment..."
source venv/Scripts/activate || source venv/bin/activate

# Remove openxlab (causes setuptools conflicts)
echo "[2/6] Removing openxlab (causes conflicts)..."
pip uninstall -y openxlab 2>/dev/null || echo "  openxlab not installed (OK)"

# Reinstall setuptools
echo "[3/6] Reinstalling setuptools..."
pip install --force-reinstall setuptools==69.0.0

# Check pkg_resources
echo "[4/6] Checking pkg_resources..."
python -c "import pkg_resources; print('  pkg_resources: OK')" || {
    echo "[ERROR] pkg_resources still not available"
    exit 1
}

# Check/Install mmcv
echo "[5/6] Checking OpenMMLab packages..."
python -c "import mmcv; print(f'  mmcv: {mmcv.__version__}')" 2>/dev/null || {
    echo "  mmcv not found, installing..."
    pip install -U openmim
    mim install mmcv==2.1.0
    pip install "mmdet>=3.3.0" "mmpose>=1.3.0"
}

# Start server
echo "[6/6] Starting GPU Worker..."
echo ""
echo "============================================"
echo "GPU Worker Server Starting..."
echo "Press Ctrl+C to stop"
echo "============================================"
echo ""

python server.py
