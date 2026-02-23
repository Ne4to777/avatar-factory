#!/bin/bash
# Test GPU server diagnostics from MacBook
# This allows the assistant to analyze the GPU server state

set -e

GPU_HOST="${1:-192.168.0.128:8001}"
API_KEY="your-secret-gpu-key-change-this"

echo "========================================="
echo "GPU Server Diagnostics Test"
echo "========================================="
echo ""
echo "Target: http://$GPU_HOST"
echo ""

# Test 1: Health
echo "[1/4] Testing health endpoint..."
curl -s -X GET "http://$GPU_HOST/health" -H "x-api-key: $API_KEY" | jq . > /tmp/gpu-health.json
cat /tmp/gpu-health.json
echo ""

# Test 2: Full diagnostics
echo "[2/4] Getting full diagnostics..."
curl -s -X GET "http://$GPU_HOST/diagnostics" -H "x-api-key: $API_KEY" | jq . > /tmp/gpu-diagnostics.json
cat /tmp/gpu-diagnostics.json
echo ""

# Test 3: Quick TTS test
echo "[3/4] Testing TTS (1 second audio)..."
TTS_START=$(date +%s)
curl -X POST "http://$GPU_HOST/api/tts?text=%D0%9F%D1%80%D0%B8%D0%B2%D0%B5%D1%82&speaker=xenia" \
     -H "x-api-key: $API_KEY" \
     --output /tmp/test-tts.wav \
     -w "HTTP: %{http_code}\n" \
     2>/dev/null
TTS_END=$(date +%s)
TTS_TIME=$((TTS_END - TTS_START))

if [ -f /tmp/test-tts.wav ]; then
    TTS_SIZE=$(stat -f%z /tmp/test-tts.wav 2>/dev/null || stat -c%s /tmp/test-tts.wav)
    echo "✓ TTS generated: ${TTS_SIZE} bytes in ${TTS_TIME}s"
else
    echo "✗ TTS file not created"
fi
echo ""

# Test 4: Quick background test (512x512)
echo "[4/4] Testing background generation (512x512)..."
BG_START=$(date +%s)
curl -X POST "http://$GPU_HOST/api/generate-background?prompt=white+background&width=512&height=512" \
     -H "x-api-key: $API_KEY" \
     --output /tmp/test-bg.png \
     -w "HTTP: %{http_code}\n" \
     2>/dev/null
BG_END=$(date +%s)
BG_TIME=$((BG_END - BG_START))

if [ -f /tmp/test-bg.png ]; then
    BG_SIZE=$(stat -f%z /tmp/test-bg.png 2>/dev/null || stat -c%s /tmp/test-bg.png)
    echo "✓ Background generated: ${BG_SIZE} bytes in ${BG_TIME}s"
else
    echo "✗ Background file not created"
fi
echo ""

echo "========================================="
echo "Tests complete!"
echo "========================================="
echo ""
echo "Full diagnostics saved to:"
echo "  - /tmp/gpu-health.json"
echo "  - /tmp/gpu-diagnostics.json"
echo ""
