#!/bin/bash
# Start Avatar Factory Frontend Server

cd "$(dirname "$0")"

echo ""
echo "============================================"
echo " Avatar Factory Frontend Server"
echo "============================================"
echo ""

# Check if venv exists
if [ ! -d "venv-frontend" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv-frontend
    
    echo "Installing dependencies..."
    venv-frontend/bin/pip install -r requirements-frontend.txt
fi

echo ""
echo "Starting server..."
echo ""
echo "Access from this laptop: http://localhost:3000"
echo "Access from network: http://<your-laptop-ip>:3000"
echo ""
echo "GPU Server must be running on Windows machine!"
echo "Set GPU_SERVER_URL environment variable if needed."
echo ""

# Получаем IP адрес
if command -v ip &> /dev/null; then
    LOCAL_IP=$(ip route get 1 | awk '{print $7}' | head -n 1)
    echo "Your laptop IP: $LOCAL_IP"
    echo ""
fi

venv-frontend/bin/python frontend-server.py
