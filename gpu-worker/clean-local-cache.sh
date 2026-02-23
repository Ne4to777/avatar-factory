#!/bin/bash
# Clean local cache and large directories that shouldn't be in Docker

echo "=================================="
echo "Clean Local Cache & Large Files"
echo "=================================="
echo ""

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# Check what will be deleted
echo "Checking for large directories..."
echo ""

TOTAL_SIZE=0

# MuseTalk (cloned in Dockerfile, not needed locally)
if [ -d "MuseTalk" ]; then
    SIZE=$(du -sh MuseTalk 2>/dev/null | awk '{print $1}')
    echo "❌ MuseTalk/        $SIZE (will be cloned in Docker)"
    TOTAL_SIZE=$((TOTAL_SIZE + $(du -sk MuseTalk | awk '{print $1}')))
fi

if [ -d "gpu-worker/MuseTalk" ]; then
    SIZE=$(du -sh gpu-worker/MuseTalk 2>/dev/null | awk '{print $1}')
    echo "❌ gpu-worker/MuseTalk/  $SIZE (will be cloned in Docker)"
    TOTAL_SIZE=$((TOTAL_SIZE + $(du -sk gpu-worker/MuseTalk | awk '{print $1}')))
fi

# Virtual environments (created in Docker, not needed locally)
for VENV in venv env .venv virtualenv gpu-worker/venv gpu-worker/env; do
    if [ -d "$VENV" ]; then
        SIZE=$(du -sh $VENV 2>/dev/null | awk '{print $1}')
        echo "❌ $VENV/       $SIZE (Python venv - not needed)"
        TOTAL_SIZE=$((TOTAL_SIZE + $(du -sk $VENV | awk '{print $1}')))
    fi
done

# Models (downloaded at runtime)
for MODEL_DIR in models checkpoints weights gpu-worker/models gpu-worker/checkpoints; do
    if [ -d "$MODEL_DIR" ]; then
        SIZE=$(du -sh $MODEL_DIR 2>/dev/null | awk '{print $1}')
        echo "❌ $MODEL_DIR/     $SIZE (models - downloaded at runtime)"
        TOTAL_SIZE=$((TOTAL_SIZE + $(du -sk $MODEL_DIR | awk '{print $1}')))
    fi
done

# Python cache
PYCACHE=$(find . -type d -name "__pycache__" 2>/dev/null | wc -l | tr -d ' ')
if [ "$PYCACHE" -gt 0 ]; then
    echo "❌ __pycache__/     $PYCACHE directories (Python cache)"
fi

# node_modules (should stay for development)
if [ -d "node_modules" ]; then
    SIZE=$(du -sh node_modules 2>/dev/null | awk '{print $1}')
    echo "✅ node_modules/    $SIZE (needed for development, excluded via .dockerignore)"
fi

echo ""
TOTAL_SIZE_MB=$((TOTAL_SIZE / 1024))
echo "Total to clean: ~${TOTAL_SIZE_MB} MB"
echo ""

if [ $TOTAL_SIZE -eq 0 ]; then
    echo "✅ Nothing to clean! Your project is already optimized."
    exit 0
fi

# Ask for confirmation
read -p "Delete these directories? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Delete
echo ""
echo "Cleaning..."

rm -rf MuseTalk gpu-worker/MuseTalk
rm -rf venv env .venv virtualenv gpu-worker/venv gpu-worker/env
rm -rf models checkpoints weights gpu-worker/models gpu-worker/checkpoints
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null

echo "✅ Cleaned!"
echo ""
echo "Now Docker build context will be ~600KB instead of several GB."
echo ""
echo "Build with:"
echo "  make build-gpu"
echo ""
