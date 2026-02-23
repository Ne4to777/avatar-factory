# Avatar Factory GPU Worker - Full MuseTalk Support via Anaconda
# Optimized Docker image with PyTorch 2.7.0 + CUDA 11.8
#
# Build time:
#   First build: 15-20 minutes (downloads ~5GB: PyTorch, dependencies)
#   Cached build: 1-2 minutes (only code changes)
#
# Build context: ~60KB (thanks to .dockerignore)
#
# Key optimizations:
#   - Requirements copied before PyTorch install (layer caching)
#   - No pip install -e . (not needed, direct imports work)
#   - BuildKit cache mounts removed (better compatibility)
#   - Verification step ensures critical packages work

FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04

# Set environment
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PATH="/opt/conda/bin:$PATH"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    git \
    ffmpeg \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh \
    && bash /tmp/miniconda.sh -b -p /opt/conda \
    && rm /tmp/miniconda.sh \
    && /opt/conda/bin/conda init bash

# Accept conda Terms of Service
RUN conda config --set channel_priority flexible \
    && conda config --add channels conda-forge \
    && echo "yes" | conda tos accept

# Create conda environment
RUN conda create -n avatar python=3.11 -y

# Activate environment for subsequent RUN commands
SHELL ["conda", "run", "-n", "avatar", "/bin/bash", "-c"]

WORKDIR /app

# Copy ONLY dependency files first (for Docker layer caching)
COPY requirements.txt pyproject.toml ./

# Install PyTorch with CUDA
# NOTE: This downloads ~3-4GB (pytorch, torchvision, torchaudio, cuda bindings)
# First build takes 5-10 minutes, subsequent builds use cache
RUN conda install pytorch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0 pytorch-cuda=11.8 -c pytorch -c nvidia -y

# Install build dependencies
RUN pip install --no-cache-dir setuptools wheel pip

# Install Python dependencies (includes MuseTalk dependencies)
RUN pip install --no-cache-dir -r requirements.txt

# Copy project code LAST (changes frequently, should not invalidate above layers)
COPY . .

# Setup MuseTalk (clone repository for inference wrapper)
RUN git clone https://github.com/TMElyralab/MuseTalk.git 2>/dev/null || echo "⚠ MuseTalk clone failed, will retry at runtime"

# Note: MMCM, controlnet_aux, IP-Adapter, CLIP not in official requirements.txt
# Only install if specific MuseTalk features require them

# Verify critical imports work
RUN python -c "import torch; import diffusers; import transformers; print('✓ Core packages OK')" || exit 1

# Create temp directory
RUN mkdir -p /tmp/avatar-factory && chmod 777 /tmp/avatar-factory

# Expose port
EXPOSE 8001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=300s --retries=3 \
    CMD curl -f http://localhost:8001/health || exit 1

# Set entrypoint to use conda environment
ENTRYPOINT ["conda", "run", "--no-capture-output", "-n", "avatar"]

# Run server
CMD ["python", "server.py"]
