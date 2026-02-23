# Dependencies Documentation

## Overview
This document describes all dependencies used in Avatar Factory GPU Worker and their purpose.

## Dependency Audit (February 2026)

### ✅ Core Dependencies (Required)

#### FastAPI Server
- **fastapi** >= 0.110.0 - Web framework for API endpoints
- **uvicorn[standard]** >= 0.29.0 - ASGI server
- **python-multipart** >= 0.0.9 - File upload support

#### PyTorch (via Conda)
- **torch** 2.7.0 - Deep learning framework
- **torchvision** 0.22.0 - Vision models
- **torchaudio** 2.7.0 - Audio models
- **pytorch-cuda** 11.8 - CUDA bindings

#### AI Models - Stable Diffusion XL
- **diffusers** >= 0.30.0 - Stable Diffusion pipeline
- **transformers** >= 4.41.0 - Transformer models (required by diffusers)
- **accelerate** >= 0.30.0 - Memory optimization
- **safetensors** >= 0.4.3 - Safe model loading
- **huggingface-hub** >= 0.23.0 - Model downloads

#### Audio Processing - Silero TTS
- **soundfile** >= 0.12.1 - Audio I/O (WAV files)
- **librosa** >= 0.10.2 - Audio feature extraction (MuseTalk)

#### Image/Video Processing
- **opencv-python** >= 4.10.0 - Computer vision (MuseTalk face detection)
- **pillow** >= 10.3.0 - Image manipulation
- **numpy** >= 1.26.4 - Array operations

#### MuseTalk Dependencies
- **einops** >= 0.8.0 - Tensor operations
- **omegaconf** >= 2.3.0 - Configuration management
- **ffmpeg-python** >= 0.2.0 - Video encoding
- **moviepy** >= 1.0.3 - Video manipulation

### ❌ Removed Dependencies (Not Used)

#### Face Enhancement (unused)
- ~~gfpgan~~ - Face enhancement (not used in code)
- ~~realesrgan~~ - Image upscaling (not used in code)
- ~~basicsr~~ - Basic SR models (not used in code)
- ~~facexlib~~ - Face utilities (not used in code)

#### UI (unused)
- ~~gradio~~ - Web UI (not needed for API server)

#### Audio Utils (unused)
- ~~pydub~~ - Audio manipulation (not used in code)
- ~~resampy~~ - Resampling (not used in code)
- ~~numba~~ - JIT compilation (not used in code)

#### Image Utils (unused)
- ~~imageio~~ - Image I/O (not used in code)
- ~~imageio-ffmpeg~~ - FFmpeg backend (not used in code)
- ~~scikit-image~~ - Image processing (not used in code)
- ~~av~~ - Video I/O (not used in code)

#### Text Processing (unused)
- ~~sentencepiece~~ - Tokenizer (not needed for our models)
- ~~protobuf~~ - Protocol buffers (not needed for our models)

#### Utils (unused)
- ~~scipy~~ - Scientific computing (not used in code)
- ~~tqdm~~ - Progress bars (not used in code)
- ~~gdown~~ - Google Drive downloader (not used in code)
- ~~pyyaml~~ - YAML parser (omegaconf handles config)

#### OpenMMLab (unused)
- ~~mmcv~~ - Computer vision (not in official MuseTalk requirements)
- ~~mmdet~~ - Object detection (not in official MuseTalk requirements)
- ~~mmpose~~ - Pose estimation (not in official MuseTalk requirements)

#### TensorFlow (not used)
- ~~tensorflow~~ - Listed in MuseTalk requirements.txt but not used
  - MuseTalk uses PyTorch-based Whisper (tiny.pt)
  - All audio processing is PyTorch-based
  - Consider adding only if specific MuseTalk features require it

### ❌ Removed Git Dependencies

#### MuseTalk Extensions (not in official requirements)
- ~~MMCM~~ - `git+https://github.com/TMElyralab/MMCM.git@main`
- ~~controlnet_aux~~ - `git+https://github.com/TMElyralab/controlnet_aux.git@tme`
- ~~IP-Adapter~~ - `git+https://github.com/tencent-ailab/IP-Adapter.git@main`
- ~~CLIP~~ - `git+https://github.com/openai/CLIP.git@main`

These are not listed in official MuseTalk requirements.txt and likely for extended features we don't use.

## Business Logic Modules

### 1. server.py
**Purpose:** FastAPI server with 4 main endpoints

**Dependencies:**
- FastAPI, uvicorn (server)
- torch (GPU check, model loading)
- diffusers (Stable Diffusion XL)
- soundfile (TTS audio saving)
- musetalk_inference (lip-sync)

**Endpoints:**
1. `/health` - GPU status, model availability
2. `/api/tts` - Text-to-Speech (Silero)
3. `/api/lipsync` - Video generation (MuseTalk)
4. `/api/generate-background` - Image generation (SDXL)
5. `/api/cleanup` - Temp file cleanup

### 2. musetalk_inference.py
**Purpose:** Wrapper for MuseTalk lip-sync

**Dependencies:**
- torch, numpy, cv2 (core processing)
- MuseTalk repo (cloned separately)

**MuseTalk Internal Dependencies:**
- Whisper-tiny (audio features) - PyTorch-based
- VAE (image encoding)
- UNet (video generation)
- ffmpeg (video encoding)

### 3. download_models.py
**Purpose:** Model downloader script

**Dependencies:**
- torch (GPU check, Silero TTS)
- diffusers (SDXL download)
- transformers, soundfile, cv2 (validation)

## Version Compatibility

### PyTorch 2.7.0 + CUDA 11.8
All dependencies are compatible with:
- Python 3.11
- PyTorch 2.7.0
- CUDA 11.8
- cuDNN 8

### Key Compatibility Notes
- PyTorch 2.7 includes built-in SDPA (no xformers needed)
- Diffusers 0.30+ supports PyTorch 2.7
- All dependencies use prebuilt wheels (no compilation needed)

## Installation

### Via Docker (Recommended)
```bash
docker build -t avatar-gpu-worker .
```

### Via pip (Manual)
```bash
# 1. Install PyTorch with CUDA
conda install pytorch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0 pytorch-cuda=11.8 -c pytorch -c nvidia

# 2. Install dependencies
pip install -r requirements.txt

# 3. Clone MuseTalk
git clone https://github.com/TMElyralab/MuseTalk.git
```

## Disk Space Requirements

### Models
- Silero TTS: ~100MB
- Stable Diffusion XL: ~7GB
- MuseTalk: ~2GB
- **Total: ~9.2GB**

### Docker Image
- Base image (CUDA): ~5GB
- Dependencies: ~3GB
- **Total: ~8GB**

## VRAM Requirements

### Minimum (8GB)
- Silero TTS: ~500MB
- MuseTalk: ~4GB
- SDXL: ~6GB
- **Cannot run all simultaneously**

### Recommended (12GB+)
- All models: ~8GB
- Inference overhead: ~2GB
- **Comfortable operation**

## Updates

### Last Audit: February 23, 2026
- Removed 20+ unused dependencies
- Simplified MuseTalk installation
- Removed mmcv/mmdet/mmpose (compilation issues)
- Aligned requirements.txt with pyproject.toml

### Testing Required
After dependency changes, test:
1. ✅ Server startup
2. ✅ GPU detection
3. ✅ TTS generation
4. ✅ Background generation
5. ⚠️ MuseTalk lip-sync (check if git deps needed)

## Troubleshooting

### If MuseTalk fails
Try adding git dependencies back:
```dockerfile
RUN pip install --no-cache-dir \
    git+https://github.com/TMElyralab/MMCM.git@main \
    git+https://github.com/TMElyralab/controlnet_aux.git@tme \
    git+https://github.com/tencent-ailab/IP-Adapter.git@main \
    git+https://github.com/openai/CLIP.git@main
```

### If TensorFlow errors occur
Add to requirements.txt:
```
tensorflow>=2.12.0
```

## Contributing

When adding new dependencies:
1. Document why it's needed
2. Specify minimum version
3. Update this file
4. Test with clean Docker build
