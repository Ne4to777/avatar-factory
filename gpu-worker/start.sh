#!/bin/bash
#
# Avatar Factory GPU Worker - Start Script
# Запуск GPU сервера
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}  🚀 Starting Avatar Factory GPU Server...                ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if venv exists
if [ ! -d "venv" ]; then
    echo -e "${RED}✗ Virtual environment not found${NC}"
    echo -e "${YELLOW}  Run ./install.sh first${NC}"
    exit 1
fi

# Activate venv
source venv/bin/activate

# Check if .env exists
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚠ .env file not found, creating with default values...${NC}"
    echo "GPU_API_KEY=$(openssl rand -base64 32)" > .env
    echo "HOST=0.0.0.0" >> .env
    echo "PORT=8001" >> .env
fi

# Get IP address
if command -v ip &> /dev/null; then
    IP_ADDR=$(ip route get 1 | awk '{print $7; exit}')
elif command -v ifconfig &> /dev/null; then
    IP_ADDR=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
else
    IP_ADDR="localhost"
fi

echo -e "${GREEN}✓ Virtual environment activated${NC}"
echo -e "${GREEN}✓ Configuration loaded${NC}"
echo ""
echo -e "${BLUE}Server will be available at:${NC}"
echo -e "  ${GREEN}http://${IP_ADDR}:8001${NC}"
echo -e "  ${GREEN}http://localhost:8001${NC}"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop the server${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Start server
python server.py
