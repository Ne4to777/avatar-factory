# Avatar Factory GPU Worker - Full MuseTalk Support via Anaconda
# Optimized Docker image with PyTorch 2.7.0 + CUDA 11.8
#
# Build time:
#   First build: 15-20 minutes (downloads ~5GB: PyTorch, models)
#   Cached build: 2-3 minutes (only if code changes)
#
# Build context:
#   ~60KB (Python source files only, thanks to .dockerignore)
#
# Layer caching strategy:
#   1. Base image + system deps (rarely change)
#   2. Miniconda install (rarely change)
#   3. Copy requirements.txt (rarely change)
#   4. Install PyTorch ~3GB (cached if requirements unchanged)
#   5. Install pip deps (cached if requirements unchanged)
#   6. Copy code (changes frequently, doesn't invalidate above)

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
# Optional: use --mount=type=cache for faster rebuilds (requires DOCKER_BUILDKIT=1)
RUN --mount=type=cache,target=/opt/conda/pkgs \
    conda install pytorch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0 pytorch-cuda=11.8 -c pytorch -c nvidia -y

# Install build dependencies
RUN pip install --no-cache-dir setuptools wheel pip

# Install Python dependencies (includes MuseTalk dependencies)
# Optional: use --mount=type=cache for faster rebuilds
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

# Copy project code LAST (changes frequently, should not invalidate above layers)
COPY . .
RUN pip install --no-cache-dir -e .

# Setup MuseTalk
RUN if [ ! -d "MuseTalk" ]; then \
    git clone https://github.com/TMElyralab/MuseTalk.git; \
    fi
# Note: MMCM, controlnet_aux, IP-Adapter, CLIP not in official requirements.txt
# Only install if specific MuseTalk features require them

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
