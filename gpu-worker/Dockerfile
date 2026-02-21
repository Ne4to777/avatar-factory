# Avatar Factory GPU Worker - Dockerfile
# Multi-stage build для оптимизации размера

FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04 AS base

# Set environment
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PYTHON_VERSION=3.10

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python${PYTHON_VERSION} \
    python3-pip \
    python${PYTHON_VERSION}-venv \
    git \
    wget \
    curl \
    ffmpeg \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Set Python as default
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

# Install PyTorch with CUDA
RUN pip install --no-cache-dir \
    torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu118

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Install project
RUN pip install --no-cache-dir -e .

# Copy application code
COPY . .

# Setup SadTalker
RUN if [ ! -d "SadTalker" ]; then \
    git clone https://github.com/OpenTalker/SadTalker.git && \
    cd SadTalker && \
    pip install --no-cache-dir -r requirements.txt; \
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
