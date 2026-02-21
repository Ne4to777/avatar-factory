#!/bin/bash
#
# Avatar Factory GPU Worker - One-Command Installer
# Автоматическая установка GPU сервера для Linux/macOS
#
# Использование:
#   curl -sSL https://raw.githubusercontent.com/Ne4to777/avatar-factory/main/gpu-worker/install.sh | bash
#   или просто: ./install.sh
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Progress indicator
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Print functions
print_header() {
    echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  🚀 Avatar Factory GPU Worker - One-Command Setup        ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}\n"
}

print_step() {
    echo -e "${BLUE}▸${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        if [ -f /etc/debian_version ]; then
            DISTRO="debian"
        elif [ -f /etc/redhat-release ]; then
            DISTRO="redhat"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    else
        print_error "Unsupported OS: $OSTYPE"
        exit 1
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    local missing_deps=()
    
    # Check Python
    if ! command_exists python3; then
        missing_deps+=("python3")
    else
        PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
        if (( $(echo "$PYTHON_VERSION < 3.10" | bc -l) )); then
            print_warning "Python 3.10+ required, found $PYTHON_VERSION"
            missing_deps+=("python3.10+")
        else
            print_success "Python $PYTHON_VERSION found"
        fi
    fi
    
    # Check pip
    if ! command_exists pip3; then
        missing_deps+=("pip3")
    else
        print_success "pip3 found"
    fi
    
    # Check git
    if ! command_exists git; then
        missing_deps+=("git")
    else
        print_success "git found"
    fi
    
    # Check CUDA (GPU)
    if command_exists nvidia-smi; then
        GPU_INFO=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader | head -1)
        print_success "GPU detected: $GPU_INFO"
    else
        print_warning "nvidia-smi not found - GPU may not be available"
        print_warning "Install NVIDIA drivers and CUDA Toolkit from:"
        print_warning "https://developer.nvidia.com/cuda-downloads"
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        echo ""
        print_step "Installing missing dependencies..."
        install_dependencies "${missing_deps[@]}"
    fi
}

# Install dependencies based on OS
install_dependencies() {
    local deps=("$@")
    
    if [ "$OS" = "linux" ]; then
        if [ "$DISTRO" = "debian" ]; then
            sudo apt-get update
            sudo apt-get install -y python3 python3-pip python3-venv git
        elif [ "$DISTRO" = "redhat" ]; then
            sudo yum install -y python3 python3-pip git
        fi
    elif [ "$OS" = "macos" ]; then
        if ! command_exists brew; then
            print_step "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        brew install python@3.10 git
    fi
}

# Setup virtual environment
setup_venv() {
    print_step "Setting up Python virtual environment..."
    
    if [ ! -d "venv" ]; then
        python3 -m venv venv
        print_success "Virtual environment created"
    else
        print_success "Virtual environment already exists"
    fi
    
    # Activate venv
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip setuptools wheel
}

# Install PyTorch with CUDA
install_pytorch() {
    print_step "Installing PyTorch with CUDA support..."
    echo "   This may take 5-10 minutes..."
    
    # Check if CUDA is available
    if command_exists nvidia-smi; then
        CUDA_VERSION=$(nvidia-smi | grep "CUDA Version" | awk '{print $9}' | cut -d'.' -f1,2)
        print_success "CUDA $CUDA_VERSION detected"
        
        # Install PyTorch with CUDA
        pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
    else
        print_warning "CUDA not detected, installing CPU version"
        pip install torch torchvision torchaudio
    fi
    
    print_success "PyTorch installed"
}

# Install Python dependencies
install_python_deps() {
    print_step "Installing Python dependencies..."
    echo "   This may take 3-5 minutes..."
    
    pip install -r requirements.txt
    
    print_success "Python dependencies installed"
}

# Clone SadTalker
setup_sadtalker() {
    print_step "Setting up SadTalker..."
    
    if [ ! -d "SadTalker" ]; then
        git clone https://github.com/OpenTalker/SadTalker.git
        cd SadTalker
        pip install -r requirements.txt
        cd ..
        print_success "SadTalker cloned and installed"
    else
        print_success "SadTalker already exists"
    fi
}

# Download AI models
download_models() {
    print_step "Downloading AI models..."
    echo "   This will download ~10GB of data and may take 15-30 minutes"
    echo "   depending on your internet speed..."
    echo ""
    
    read -p "   Download models now? (y/n) [y]: " -n 1 -r
    echo
    REPLY=${REPLY:-y}
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        python download_models.py
        print_success "Models downloaded"
    else
        print_warning "Skipping model download"
        print_warning "Run 'python download_models.py' manually later"
    fi
}

# Setup environment file
setup_env() {
    print_step "Setting up environment configuration..."
    
    if [ ! -f ".env" ]; then
        echo "GPU_API_KEY=$(openssl rand -base64 32)" > .env
        echo "HOST=0.0.0.0" >> .env
        echo "PORT=8001" >> .env
        print_success ".env file created with random API key"
        
        # Show the API key
        API_KEY=$(grep GPU_API_KEY .env | cut -d'=' -f2)
        echo ""
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}Important: Save this API key for your laptop configuration:${NC}"
        echo -e "${GREEN}$API_KEY${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
    else
        print_success ".env file already exists"
    fi
}

# Test installation
test_installation() {
    print_step "Testing installation..."
    
    # Test Python imports
    python3 -c "import torch; print('✓ PyTorch:', torch.__version__)" 2>/dev/null && \
    python3 -c "import torch; print('✓ CUDA available:', torch.cuda.is_available())" 2>/dev/null && \
    python3 -c "import fastapi; print('✓ FastAPI imported')" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        print_success "Installation test passed"
    else
        print_error "Installation test failed"
        return 1
    fi
}

# Main installation flow
main() {
    print_header
    
    detect_os
    print_success "Detected OS: $OS"
    echo ""
    
    check_prerequisites
    echo ""
    
    setup_venv
    echo ""
    
    install_pytorch
    echo ""
    
    install_python_deps
    echo ""
    
    setup_sadtalker
    echo ""
    
    download_models
    echo ""
    
    setup_env
    echo ""
    
    test_installation
    echo ""
    
    # Final instructions
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  ✓ Installation Complete!                                 ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo ""
    echo "  1. Find your PC's IP address:"
    echo "     ${YELLOW}ip addr show${NC} (Linux) or ${YELLOW}ifconfig${NC} (macOS)"
    echo ""
    echo "  2. Start the GPU server:"
    echo "     ${YELLOW}./start.sh${NC}"
    echo ""
    echo "  3. On your laptop, update .env file:"
    echo "     ${YELLOW}GPU_SERVER_URL=http://YOUR_PC_IP:8001${NC}"
    echo "     ${YELLOW}GPU_API_KEY=<your-api-key-from-above>${NC}"
    echo ""
    echo "  4. Test the server:"
    echo "     ${YELLOW}curl http://YOUR_PC_IP:8001/health${NC}"
    echo ""
    echo -e "${GREEN}Documentation:${NC} README.md"
    echo ""
}

# Run main installation
main
