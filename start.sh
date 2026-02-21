#!/bin/bash
#
# Avatar Factory - Start Script (Laptop)
# Запуск приложения и воркера
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Trap Ctrl+C
trap cleanup INT TERM

cleanup() {
    echo ""
    echo -e "${YELLOW}Stopping services...${NC}"
    
    # Kill background processes
    if [ ! -z "$DEV_PID" ]; then
        kill $DEV_PID 2>/dev/null || true
    fi
    if [ ! -z "$WORKER_PID" ]; then
        kill $WORKER_PID 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✓ Services stopped${NC}"
    exit 0
}

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}  🎬 Starting Avatar Factory...                            ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if Docker is running
if ! docker ps >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Docker is not running${NC}"
    echo -e "${BLUE}  Starting Docker...${NC}"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open -a Docker
        echo -e "${BLUE}  Waiting for Docker to start...${NC}"
        
        # Wait up to 30 seconds
        for i in {1..30}; do
            if docker ps >/dev/null 2>&1; then
                break
            fi
            sleep 1
        done
    fi
fi

# Start infrastructure
echo -e "${BLUE}▸${NC} Starting infrastructure..."
docker-compose up -d

echo -e "${GREEN}✓ Infrastructure started${NC}"
echo ""

# Check services
echo -e "${BLUE}▸${NC} Checking services..."
sleep 3

POSTGRES_STATUS=$(docker-compose ps postgres | grep -c "Up" || echo "0")
REDIS_STATUS=$(docker-compose ps redis | grep -c "Up" || echo "0")
MINIO_STATUS=$(docker-compose ps minio | grep -c "Up" || echo "0")

if [ "$POSTGRES_STATUS" = "1" ]; then
    echo -e "${GREEN}✓ PostgreSQL is running${NC}"
else
    echo -e "${RED}✗ PostgreSQL is not running${NC}"
fi

if [ "$REDIS_STATUS" = "1" ]; then
    echo -e "${GREEN}✓ Redis is running${NC}"
else
    echo -e "${RED}✗ Redis is not running${NC}"
fi

if [ "$MINIO_STATUS" = "1" ]; then
    echo -e "${GREEN}✓ MinIO is running${NC}"
else
    echo -e "${RED}✗ MinIO is not running${NC}"
fi

echo ""

# Ask which mode to run
echo -e "${BLUE}Select mode:${NC}"
echo "  1. Development (UI only)"
echo "  2. Production (UI + Worker)"
echo "  3. Worker only"
echo ""
read -p "Enter choice [1]: " MODE
MODE=${MODE:-1}

echo ""

if [ "$MODE" = "1" ] || [ "$MODE" = "2" ]; then
    echo -e "${BLUE}▸${NC} Starting Next.js development server..."
    npm run dev > /tmp/avatar-factory-dev.log 2>&1 &
    DEV_PID=$!
    
    # Wait for server to start
    sleep 3
    
    if kill -0 $DEV_PID 2>/dev/null; then
        echo -e "${GREEN}✓ Next.js server started${NC}"
        echo -e "  ${GREEN}http://localhost:3000${NC}"
    else
        echo -e "${RED}✗ Next.js server failed to start${NC}"
        cat /tmp/avatar-factory-dev.log
        exit 1
    fi
fi

if [ "$MODE" = "2" ] || [ "$MODE" = "3" ]; then
    echo ""
    echo -e "${BLUE}▸${NC} Starting video worker..."
    npm run worker > /tmp/avatar-factory-worker.log 2>&1 &
    WORKER_PID=$!
    
    sleep 2
    
    if kill -0 $WORKER_PID 2>/dev/null; then
        echo -e "${GREEN}✓ Worker started${NC}"
    else
        echo -e "${RED}✗ Worker failed to start${NC}"
        cat /tmp/avatar-factory-worker.log
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}  ✓ Avatar Factory is Running!                             ${GREEN}║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Services:${NC}"
if [ "$MODE" = "1" ] || [ "$MODE" = "2" ]; then
    echo -e "  • UI:       ${GREEN}http://localhost:3000${NC}"
fi
echo -e "  • Adminer:  ${YELLOW}http://localhost:8080${NC}"
echo -e "  • MinIO:    ${YELLOW}http://localhost:9001${NC}"
echo ""

if [ "$MODE" = "1" ] || [ "$MODE" = "2" ]; then
    echo -e "${BLUE}Logs:${NC}"
    echo -e "  • Dev server: tail -f /tmp/avatar-factory-dev.log"
    if [ "$MODE" = "2" ]; then
        echo -e "  • Worker:     tail -f /tmp/avatar-factory-worker.log"
    fi
    echo ""
fi

echo -e "${YELLOW}Press Ctrl+C to stop all services${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Follow logs
if [ "$MODE" = "1" ]; then
    tail -f /tmp/avatar-factory-dev.log
elif [ "$MODE" = "2" ]; then
    tail -f /tmp/avatar-factory-dev.log /tmp/avatar-factory-worker.log
else
    tail -f /tmp/avatar-factory-worker.log
fi
