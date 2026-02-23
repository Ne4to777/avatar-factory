# Avatar Factory GPU Worker - Full MuseTalk Support via Anaconda
# This Dockerfile uses Miniconda for reliable OpenMMLab installation

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

# Install PyTorch with CUDA
RUN conda install pytorch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0 pytorch-cuda=11.8 -c pytorch -c nvidia -y

# Install build dependencies first
RUN pip install --no-cache-dir setuptools wheel

# Install OpenMMLab packages via pip (prebuilt wheels)
RUN pip install --no-cache-dir \
    mmengine==0.10.3 \
    mmcv==2.1.0 -f https://download.openmmlab.com/mmcv/dist/cu118/torch2.1/index.html \
    mmdet==3.3.0 \
    mmpose==1.3.1

WORKDIR /app

# Copy requirements
COPY requirements.txt pyproject.toml ./

# Install Python dependencies (includes MuseTalk dependencies)
RUN pip install --no-cache-dir -r requirements.txt

# Install project
COPY . .
RUN pip install --no-cache-dir -e .

# Setup MuseTalk
RUN if [ ! -d "MuseTalk" ]; then \
    git clone https://github.com/TMElyralab/MuseTalk.git && \
    pip install --no-cache-dir \
        git+https://github.com/TMElyralab/MMCM.git@main \
        git+https://github.com/TMElyralab/controlnet_aux.git@tme \
        git+https://github.com/tencent-ailab/IP-Adapter.git@main \
        git+https://github.com/openai/CLIP.git@main; \
    fi

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
