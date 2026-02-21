#!/bin/bash
#
# Avatar Factory - Universal Quick Start
# Автоматическое определение типа машины и установка соответствующих компонентов
#
# Использование:
#   curl -sSL https://raw.githubusercontent.com/Ne4to777/avatar-factory/main/quick-start.sh | bash
#   или: ./quick-start.sh
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear

echo -e "${CYAN}"
cat << "EOF"
    ___                __              ______           __                  
   /   |_   ______ _  / /_____ ______/ ____/___ ______/ /_____  _______  __
  / /| | | / / __ `/ / __/ __ `/ ___/ /_  / __ `/ ___/ __/ __ \/ ___/ / / /
 / ___ | |/ / /_/ / / /_/ /_/ / /  / __/ / /_/ / /__/ /_/ /_/ / /  / /_/ / 
/_/  |_|___/\__,_/  \__/\__,_/_/  /_/    \__,_/\___/\__/\____/_/   \__, /  
                                                                   /____/   
EOF
echo -e "${NC}"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}  🚀 Avatar Factory - Universal Quick Start                ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Detect machine type
echo -e "${BLUE}▸${NC} Detecting machine type..."
echo ""

HAS_GPU=0
if command -v nvidia-smi &> /dev/null; then
    GPU_INFO=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null | head -1 || echo "")
    if [ ! -z "$GPU_INFO" ]; then
        HAS_GPU=1
        echo -e "${GREEN}✓ NVIDIA GPU detected: $GPU_INFO${NC}"
    fi
else
    echo -e "${YELLOW}⚠ No NVIDIA GPU detected${NC}"
fi

echo ""

# Ask user what to install
echo -e "${CYAN}What would you like to install?${NC}"
echo ""
echo "  ${GREEN}1.${NC} GPU Worker (for desktop PC with NVIDIA GPU)"
echo "  ${GREEN}2.${NC} Main Application (for laptop/development machine)"
echo "  ${GREEN}3.${NC} Full Stack (both GPU Worker + Main App on same machine)"
echo ""

if [ "$HAS_GPU" = "1" ]; then
    DEFAULT_CHOICE=1
    echo -e "${YELLOW}Recommended:${NC} Option 1 (GPU Worker) - GPU detected"
else
    DEFAULT_CHOICE=2
    echo -e "${YELLOW}Recommended:${NC} Option 2 (Main Application) - No GPU detected"
fi

echo ""
read -p "Enter choice [${DEFAULT_CHOICE}]: " INSTALL_TYPE
INSTALL_TYPE=${INSTALL_TYPE:-$DEFAULT_CHOICE}

echo ""

case $INSTALL_TYPE in
    1)
        echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║${NC}  Installing GPU Worker...                                  ${BLUE}║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        # Check if we're in the right directory
        if [ ! -d "gpu-worker" ]; then
            if [ -d "../gpu-worker" ]; then
                cd ..
            else
                echo -e "${RED}✗ gpu-worker directory not found${NC}"
                echo -e "${YELLOW}  Please run this script from the project root${NC}"
                exit 1
            fi
        fi
        
        cd gpu-worker
        
        # Run GPU worker installation
        if [ -f "install.sh" ]; then
            chmod +x install.sh
            ./install.sh
        else
            echo -e "${RED}✗ install.sh not found in gpu-worker directory${NC}"
            exit 1
        fi
        
        echo ""
        echo -e "${GREEN}✓ GPU Worker installation complete!${NC}"
        echo ""
        echo -e "${BLUE}To start the GPU server:${NC}"
        echo -e "  ${YELLOW}cd gpu-worker && ./start.sh${NC}"
        ;;
        
    2)
        echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║${NC}  Installing Main Application...                            ${BLUE}║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        # Check if we're in the right directory
        if [ -f "package.json" ]; then
            # We're in the right place
            :
        elif [ -f "../package.json" ]; then
            cd ..
        else
            echo -e "${RED}✗ package.json not found${NC}"
            echo -e "${YELLOW}  Please run this script from the project root${NC}"
            exit 1
        fi
        
        # Run main app installation
        if [ -f "install.sh" ]; then
            chmod +x install.sh
            ./install.sh
        else
            echo -e "${RED}✗ install.sh not found${NC}"
            exit 1
        fi
        
        echo ""
        echo -e "${GREEN}✓ Main Application installation complete!${NC}"
        echo ""
        echo -e "${BLUE}To start the application:${NC}"
        echo -e "  ${YELLOW}./start.sh${NC}"
        ;;
        
    3)
        echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║${NC}  Installing Full Stack...                                  ${BLUE}║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        # Install main app first
        echo -e "${CYAN}Step 1/2: Installing Main Application...${NC}"
        echo ""
        
        if [ -f "install.sh" ]; then
            chmod +x install.sh
            ./install.sh
        fi
        
        echo ""
        echo -e "${GREEN}✓ Main Application installed${NC}"
        echo ""
        
        # Install GPU worker
        echo -e "${CYAN}Step 2/2: Installing GPU Worker...${NC}"
        echo ""
        
        if [ -d "gpu-worker" ]; then
            cd gpu-worker
            if [ -f "install.sh" ]; then
                chmod +x install.sh
                ./install.sh
            fi
            cd ..
        fi
        
        echo ""
        echo -e "${GREEN}✓ Full Stack installation complete!${NC}"
        echo ""
        echo -e "${BLUE}To start everything:${NC}"
        echo ""
        echo -e "  ${YELLOW}Terminal 1:${NC} cd gpu-worker && ./start.sh"
        echo -e "  ${YELLOW}Terminal 2:${NC} ./start.sh"
        ;;
        
    *)
        echo -e "${RED}✗ Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}  🎉 Installation Complete!                                 ${GREEN}║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Documentation:${NC}"
echo "  • ${YELLOW}QUICKSTART.md${NC} - Quick start guide (15 minutes)"
echo "  • ${YELLOW}README.md${NC} - Full documentation"
echo "  • ${YELLOW}LAPTOP_TEST_SUMMARY.md${NC} - Test results"
echo ""
echo -e "${CYAN}Happy video making! 🎬${NC}"
echo ""
