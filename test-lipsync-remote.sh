#!/bin/bash
# Test lip-sync from MacBook using test image and audio
set -e

GPU_HOST="${1:-192.168.0.128:8001}"
API_KEY="your-secret-gpu-key-change-this"

echo "========================================="
echo "Testing Lip-sync (MuseTalk)"
echo "========================================="
echo ""

# Create a simple test image (512x512 white square with black circle = face)
echo "[1/3] Creating test image..."
if command -v convert &> /dev/null; then
    convert -size 512x512 xc:white -fill black -draw "circle 256,256 256,128" /tmp/test-face.jpg
    echo "✓ Test image created: /tmp/test-face.jpg"
else
    echo "✗ ImageMagick not found, downloading sample image..."
    curl -s https://picsum.photos/512/512 -o /tmp/test-face.jpg
    echo "✓ Test image downloaded"
fi
echo ""

# Use the TTS file we just generated
echo "[2/3] Using TTS audio: /tmp/test-tts-remote.wav"
if [ ! -f /tmp/test-tts-remote.wav ]; then
    echo "✗ TTS file not found, generating..."
    curl -X POST "http://$GPU_HOST/api/tts?text=%D0%9F%D1%80%D0%B8%D0%B2%D0%B5%D1%82&speaker=xenia" \
         -H "x-api-key: $API_KEY" \
         --output /tmp/test-tts-remote.wav \
         2>/dev/null
    echo "✓ TTS generated"
fi
echo ""

# Test lip-sync
echo "[3/3] Testing lip-sync (this may take 1-2 minutes)..."
LIPSYNC_START=$(date +%s)

curl -X POST "http://$GPU_HOST/api/lipsync" \
     -H "x-api-key: $API_KEY" \
     -F "image=@/tmp/test-face.jpg" \
     -F "audio=@/tmp/test-tts-remote.wav" \
     -F "bbox_shift=0" \
     -F "batch_size=8" \
     -F "fps=25" \
     --output /tmp/test-lipsync-output.mp4 \
     -w "\nHTTP: %{http_code}\n" \
     --max-time 300 \
     2>/dev/null

LIPSYNC_END=$(date +%s)
LIPSYNC_TIME=$((LIPSYNC_END - LIPSYNC_START))

echo ""
if [ -f /tmp/test-lipsync-output.mp4 ]; then
    VIDEO_SIZE=$(stat -f%z /tmp/test-lipsync-output.mp4 2>/dev/null || stat -c%s /tmp/test-lipsync-output.mp4)
    echo "✓ Lip-sync completed: ${VIDEO_SIZE} bytes in ${LIPSYNC_TIME}s"
    
    # Check if video has audio
    if command -v ffprobe &> /dev/null; then
        echo ""
        echo "Video analysis:"
        ffprobe -v quiet -print_format json -show_streams /tmp/test-lipsync-output.mp4 | jq '.streams[] | {codec_type, codec_name, duration}'
    fi
    
    echo ""
    echo "✓ Video saved to: /tmp/test-lipsync-output.mp4"
    echo "  You can play it with: open /tmp/test-lipsync-output.mp4"
else
    echo "✗ Lip-sync video not created"
    if [ -f /tmp/test-lipsync-output.mp4 ]; then
        echo "Error response:"
        head -100 /tmp/test-lipsync-output.mp4
    fi
fi

echo ""
echo "========================================="
echo "Test complete!"
echo "========================================="
