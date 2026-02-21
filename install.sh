#!/bin/bash
#
# Avatar Factory - One-Command Installer (Laptop/Development Machine)
# Автоматическая установка главного приложения
#
# Использование:
#   curl -sSL https://raw.githubusercontent.com/Ne4to777/avatar-factory/main/install.sh | bash
#   или просто: ./install.sh
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  🎬 Avatar Factory - One-Command Setup (Laptop)          ${BLUE}║${NC}"
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

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    else
        print_error "Unsupported OS: $OSTYPE"
        exit 1
    fi
}

# Check Node.js
check_node() {
    print_step "Checking Node.js..."
    
    if ! command_exists node; then
        print_error "Node.js not found"
        echo ""
        print_step "Installing Node.js..."
        
        if [ "$OS" = "macos" ]; then
            if ! command_exists brew; then
                print_step "Installing Homebrew first..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            brew install node
        elif [ "$OS" = "linux" ]; then
            # Install Node.js 18.x LTS
            curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
            sudo apt-get install -y nodejs
        fi
    else
        NODE_VERSION=$(node --version)
        print_success "Node.js $NODE_VERSION found"
    fi
}

# Check Docker
check_docker() {
    print_step "Checking Docker..."
    
    if ! command_exists docker; then
        print_error "Docker not found"
        echo ""
        print_warning "Please install Docker Desktop from:"
        print_warning "https://www.docker.com/products/docker-desktop"
        echo ""
        read -p "Press Enter after installing Docker, or Ctrl+C to exit..."
    else
        DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
        print_success "Docker $DOCKER_VERSION found"
        
        # Check if Docker is running
        if ! docker ps >/dev/null 2>&1; then
            print_warning "Docker is installed but not running"
            print_step "Starting Docker..."
            
            if [ "$OS" = "macos" ]; then
                open -a Docker
                print_step "Waiting for Docker to start..."
                sleep 10
            fi
        fi
    fi
}

# Install npm dependencies
install_deps() {
    print_step "Installing npm dependencies..."
    echo "   This may take 2-3 minutes..."
    
    npm install
    
    print_success "Dependencies installed"
}

# Setup infrastructure
setup_infrastructure() {
    print_step "Starting infrastructure (PostgreSQL, Redis, MinIO)..."
    
    # Stop existing containers
    docker-compose down 2>/dev/null || true
    
    # Start containers
    docker-compose up -d
    
    # Wait for services to be ready
    print_step "Waiting for services to start..."
    sleep 5
    
    # Check health
    local retries=12
    local count=0
    while [ $count -lt $retries ]; do
        if docker-compose ps | grep -q "healthy"; then
            break
        fi
        sleep 5
        count=$((count + 1))
    done
    
    print_success "Infrastructure started"
}

# Setup database
setup_database() {
    print_step "Setting up database..."
    
    # Generate Prisma client
    npx prisma generate
    
    # Run migrations
    npx prisma migrate deploy
    
    print_success "Database ready"
}

# Setup environment
setup_env() {
    print_step "Setting up environment configuration..."
    
    if [ ! -f ".env" ]; then
        cp .env.example .env
        print_success ".env file created from example"
        
        echo ""
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}Important: Update GPU_SERVER_URL in .env file:${NC}"
        echo -e "${GREEN}GPU_SERVER_URL=http://YOUR_DESKTOP_PC_IP:8001${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
    else
        print_success ".env file already exists"
    fi
}

# Run tests
run_tests() {
    print_step "Running basic tests..."
    
    npx tsx test-basic.ts
    
    if [ $? -eq 0 ]; then
        print_success "Tests passed"
    else
        print_warning "Some tests failed, but you can continue"
    fi
}

main() {
    print_header
    
    detect_os
    print_success "Detected OS: $OS"
    echo ""
    
    check_node
    echo ""
    
    check_docker
    echo ""
    
    install_deps
    echo ""
    
    setup_infrastructure
    echo ""
    
    setup_env
    echo ""
    
    setup_database
    echo ""
    
    run_tests
    echo ""
    
    # Final instructions
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  ✓ Installation Complete!                                 ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo ""
    echo "  1. Update .env file with your GPU server URL:"
    echo "     ${YELLOW}GPU_SERVER_URL=http://YOUR_DESKTOP_PC_IP:8001${NC}"
    echo "     ${YELLOW}GPU_API_KEY=<key-from-gpu-server>${NC}"
    echo ""
    echo "  2. Start the application:"
    echo "     ${YELLOW}./start.sh${NC}"
    echo ""
    echo "  3. Open in browser:"
    echo "     ${YELLOW}http://localhost:3000${NC}"
    echo ""
    echo -e "${GREEN}Documentation:${NC}"
    echo "  • QUICKSTART.md - Quick start guide"
    echo "  • README.md - Full documentation"
    echo ""
}

main
