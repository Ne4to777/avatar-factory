#!/usr/bin/env python
"""Debug torch.xpu issue"""

import sys
import torch

print(f"PyTorch version: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"Has xpu attr: {hasattr(torch, 'xpu')}")

# Try importing problematic modules
print("\n--- Testing imports ---")

try:
    print("1. Importing diffusers...")
    from diffusers import StableDiffusionXLPipeline
    print("   ✓ OK")
except Exception as e:
    print(f"   ✗ FAILED: {e}")

try:
    print("2. Importing MuseTalk...")
    sys.path.insert(0, 'MuseTalk')
    from musetalk.utils.utils import get_file_type, get_video_fps, datagen
    print("   ✓ OK")
except Exception as e:
    print(f"   ✗ FAILED: {e}")

print("\nDone")
