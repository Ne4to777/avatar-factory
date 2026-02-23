#!/bin/bash
# Check Docker build context size

echo "==================================="
echo "Docker Build Context Size Checker"
echo "==================================="
echo ""

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Script location: $SCRIPT_DIR"
echo "Project root: $PROJECT_ROOT"
echo ""

# Test 1: Build from gpu-worker directory (CORRECT)
echo "--- Test 1: FROM gpu-worker/ (docker build .) ---"
cd "$SCRIPT_DIR"
CONTEXT_SIZE=$(find . -type f ! -path '*/\.*' ! -path './node_modules/*' ! -path './MuseTalk/*' ! -path './models/*' ! -path './checkpoints/*' ! -name '*.pyc' ! -name '*.pth' ! -name '*.ckpt' -exec du -b {} + | awk '{sum+=$1} END {print sum}')
CONTEXT_SIZE_MB=$(echo "scale=2; $CONTEXT_SIZE / 1024 / 1024" | bc)
echo "Context size: ${CONTEXT_SIZE_MB} MB"
echo "✅ This is CORRECT (~0.6 MB expected)"
echo ""

# Test 2: Build from project root with gpu-worker context (CORRECT)
echo "--- Test 2: FROM root/ (docker build -f gpu-worker/Dockerfile gpu-worker) ---"
cd "$PROJECT_ROOT"
CONTEXT_SIZE=$(find gpu-worker -type f ! -path '*/\.*' ! -path '*/node_modules/*' ! -path '*/MuseTalk/*' ! -path '*/models/*' ! -path '*/checkpoints/*' ! -name '*.pyc' ! -name '*.pth' ! -name '*.ckpt' -exec du -b {} + | awk '{sum+=$1} END {print sum}')
CONTEXT_SIZE_MB=$(echo "scale=2; $CONTEXT_SIZE / 1024 / 1024" | bc)
echo "Context size: ${CONTEXT_SIZE_MB} MB"
echo "✅ This is CORRECT (~0.6 MB expected)"
echo ""

# Test 3: Build from project root with . context (WRONG!)
echo "--- Test 3: FROM root/ (docker build -f gpu-worker/Dockerfile .) ---"
cd "$PROJECT_ROOT"
CONTEXT_SIZE=$(find . -type f ! -path '*/\.*' ! -path './node_modules/*' ! -path '*/MuseTalk/*' ! -path '*/models/*' ! -path '*/checkpoints/*' ! -path './coverage/*' ! -name '*.pyc' ! -name '*.pth' ! -name '*.ckpt' -exec du -b {} + 2>/dev/null | awk '{sum+=$1} END {print sum}')
CONTEXT_SIZE_MB=$(echo "scale=2; $CONTEXT_SIZE / 1024 / 1024" | bc)
echo "Context size: ${CONTEXT_SIZE_MB} MB"
echo "❌ This is WRONG! (.dockerignore should reduce this)"
echo ""

# Check if .dockerignore exists
echo "--- Checking .dockerignore files ---"
if [ -f "$PROJECT_ROOT/.dockerignore" ]; then
    echo "✅ Root .dockerignore exists"
    echo "   First 5 lines:"
    head -5 "$PROJECT_ROOT/.dockerignore" | sed 's/^/   /'
else
    echo "❌ Root .dockerignore NOT FOUND"
fi

if [ -f "$SCRIPT_DIR/.dockerignore" ]; then
    echo "✅ gpu-worker/.dockerignore exists"
    echo "   First 5 lines:"
    head -5 "$SCRIPT_DIR/.dockerignore" | sed 's/^/   /'
else
    echo "❌ gpu-worker/.dockerignore NOT FOUND"
fi
echo ""

# Recommend correct command
echo "==================================="
echo "RECOMMENDED BUILD COMMANDS:"
echo "==================================="
echo ""
echo "From project root:"
echo "  make build-gpu"
echo "  OR"
echo "  docker build -f gpu-worker/Dockerfile -t avatar-gpu-worker:latest gpu-worker"
echo "                                                                      ^^^^^^^^^^"
echo "                                                                      context!"
echo ""
echo "From gpu-worker/:"
echo "  cd gpu-worker"
echo "  docker build -t avatar-gpu-worker:latest ."
echo ""
echo "DON'T USE:"
echo "  docker build -f gpu-worker/Dockerfile .  ← copies entire project!"
echo ""
