# Avatar Factory GPU Worker - Dockerfile
# Multi-stage build для оптимизации размера

FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04 AS base

# Set environment
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PYTHON_VERSION=3.11

# Install system dependencies including Python 3.11
RUN apt-get update && apt-get install -y \
    software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-venv \
    python${PYTHON_VERSION}-dev \
    python3-pip \
    git \
    wget \
    curl \
    ffmpeg \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.11 as default
RUN update-alternatives --install /usr/bin/python python /usr/bin/python${PYTHON_VERSION} 1
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${PYTHON_VERSION} 1

WORKDIR /app

# Copy requirements first (for caching)
COPY requirements.txt pyproject.toml ./

# Create venv and install dependencies
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Upgrade pip
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# Install PyTorch 2.7.0 with CUDA 11.8 (same as native setup)
RUN pip install --no-cache-dir \
    torch==2.7.0+cu118 \
    torchvision==0.22.0+cu118 \
    torchaudio==2.7.0+cu118 \
    --index-url https://download.pytorch.org/whl/cu118

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Install project
RUN pip install --no-cache-dir -e .

# Copy application code
COPY . .

# Install OpenMMLab packages (works fine in Docker/Linux)
RUN pip install --no-cache-dir \
    openmim \
    && mim install mmcv \
    && pip install --no-cache-dir mmdet mmpose

# Setup MuseTalk
RUN if [ ! -d "MuseTalk" ]; then \
    git clone https://github.com/TMElyralab/MuseTalk.git && \
    pip install --no-cache-dir -r musetalk-requirements.txt && \
    pip install --no-cache-dir \
        git+https://github.com/TMElyralab/MMCM.git@main \
        git+https://github.com/TMElyralab/controlnet_aux.git@tme \
        git+https://github.com/tencent-ailab/IP-Adapter.git@main \
        git+https://github.com/openai/CLIP.git@main; \
    fi

# Download models (optional - can be done at runtime)
# RUN python download_models.py

# Create temp directory
RUN mkdir -p /tmp/avatar-factory && chmod 777 /tmp/avatar-factory

# Expose port
EXPOSE 8001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=300s --retries=3 \
    CMD curl -f http://localhost:8001/health || exit 1

# Run server
CMD ["python", "server.py"]
