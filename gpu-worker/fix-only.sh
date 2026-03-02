#!/bin/bash
# ================================================================
# Avatar Factory GPU Worker - Fix Only Script
# ================================================================
# Fixes common issues WITHOUT starting the server
# Usage: ./fix-only.sh
# ================================================================

echo "=== GPU Worker Fix ==="
echo ""

# Check if venv exists
if [ ! -d "venv" ]; then
    echo "[ERROR] venv not found. Run 'python -m venv venv' first"
    exit 1
fi

# Activate venv
echo "[1/5] Activating virtual environment..."
source venv/Scripts/activate || source venv/bin/activate

# Remove openxlab
echo "[2/5] Removing openxlab (causes conflicts)..."
pip uninstall -y openxlab 2>/dev/null || echo "  openxlab not installed (OK)"

# Reinstall setuptools
echo "[3/5] Reinstalling setuptools..."
pip install --force-reinstall setuptools==69.0.0

# Check pkg_resources
echo "[4/5] Checking pkg_resources..."
python -c "import pkg_resources; print('  pkg_resources: OK')" || {
    echo "[ERROR] pkg_resources still not available"
    exit 1
}

# Check/Install mmcv
echo "[5/5] Checking OpenMMLab packages..."
python -c "import mmcv; print(f'  mmcv: {mmcv.__version__}')" 2>/dev/null || {
    echo "  mmcv not found, installing..."
    pip install -U openmim
    mim install mmcv==2.1.0
    pip install "mmdet>=3.3.0" "mmpose>=1.3.0"
}

echo ""
echo "============================================"
echo "Fix complete! You can now run:"
echo "  python server.py"
echo "============================================"
