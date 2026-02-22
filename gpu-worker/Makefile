# Avatar Factory GPU Worker - Makefile

.PHONY: help install start test clean health

# Colors
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m

PYTHON := python3
VENV := venv
VENV_BIN := $(VENV)/bin
PIP := $(VENV_BIN)/pip
PYTHON_VENV := $(VENV_BIN)/python

help:
	@echo "$(BLUE)Avatar Factory GPU Worker - Available Commands$(NC)"
	@echo ""
	@echo "$(GREEN)Setup:$(NC)"
	@echo "  make install          - Full installation"
	@echo "  make install-deps     - Install Python dependencies"
	@echo "  make install-models   - Download AI models"
	@echo "  make setup-musetalk   - Setup MuseTalk"
	@echo ""
	@echo "$(GREEN)Run:$(NC)"
	@echo "  make start            - Start GPU server"
	@echo "  make dev              - Start in debug mode"
	@echo ""
	@echo "$(GREEN)Test:$(NC)"
	@echo "  make test             - Run all tests"
	@echo "  make test-health      - Test server health"
	@echo "  make test-gpu         - Test GPU availability"
	@echo ""
	@echo "$(GREEN)Maintenance:$(NC)"
	@echo "  make clean            - Clean temporary files"
	@echo "  make clean-all        - Deep clean (removes venv)"
	@echo "  make health           - Check server health"
	@echo "  make gpu-info         - Show GPU information"

# 🎯 Полная установка
install: check-deps setup-venv install-pytorch install-deps setup-musetalk create-env
	@echo -e "$(GREEN)✓ Installation complete!$(NC)"
	@echo ""
	@echo -e "$(BLUE)Next steps:$(NC)"
	@echo "  1. Download models: make install-models"
	@echo "  2. Start server: make start"
	@echo "  3. Test: make test"

# 🔍 Проверка зависимостей
check-deps:
	@echo -e "$(BLUE)Checking dependencies...$(NC)"
	@command -v $(PYTHON) >/dev/null 2>&1 && echo -e "$(GREEN)✓ Python$(NC)" || (echo -e "$(RED)✗ Python not found$(NC)" && exit 1)
	@command -v pip3 >/dev/null 2>&1 && echo -e "$(GREEN)✓ pip$(NC)" || (echo -e "$(RED)✗ pip not found$(NC)" && exit 1)
	@command -v git >/dev/null 2>&1 && echo -e "$(GREEN)✓ git$(NC)" || (echo -e "$(RED)✗ git not found$(NC)" && exit 1)
	@command -v nvidia-smi >/dev/null 2>&1 && echo -e "$(GREEN)✓ CUDA$(NC)" || echo -e "$(YELLOW)⚠ nvidia-smi not found$(NC)"

# 🐍 Создание virtual environment
setup-venv:
	@echo -e "$(BLUE)Setting up Python virtual environment...$(NC)"
	@if [ ! -d "$(VENV)" ]; then \
		$(PYTHON) -m venv $(VENV); \
		echo -e "$(GREEN)✓ Virtual environment created$(NC)"; \
	else \
		echo -e "$(GREEN)✓ Virtual environment exists$(NC)"; \
	fi
	@$(PIP) install --upgrade pip setuptools wheel

# 🔥 Установка PyTorch с CUDA
install-pytorch:
	@echo -e "$(BLUE)Installing PyTorch with CUDA...$(NC)"
	@$(PIP) install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
	@echo -e "$(GREEN)✓ PyTorch installed$(NC)"

# 📦 Установка Python зависимостей
install-deps:
	@echo -e "$(BLUE)Installing Python dependencies...$(NC)"
	@$(PIP) install -r requirements.txt
	@echo -e "$(GREEN)✓ Dependencies installed$(NC)"

# 🎭 Настройка MuseTalk
setup-musetalk:
	@echo -e "$(BLUE)Setting up MuseTalk...$(NC)"
	@echo -e "$(YELLOW)MuseTalk requires separate installation:$(NC)"
	@echo ""
	@echo "  For Windows:"
	@echo "  powershell -ExecutionPolicy Bypass -File install-musetalk.ps1"
	@echo ""
	@echo "  For Linux/macOS:"
	@echo "  bash install-musetalk.sh  (to be created)"
	@echo ""

# 📥 Скачивание AI моделей
install-models:
	@echo -e "$(BLUE)Downloading AI models (~10GB, 15-30 minutes)...$(NC)"
	@$(PYTHON_VENV) download_models.py
	@echo -e "$(GREEN)✓ Models downloaded$(NC)"

# 🔐 Создание .env файла
create-env:
	@echo -e "$(BLUE)Creating .env file...$(NC)"
	@if [ ! -f ".env" ]; then \
		echo "GPU_API_KEY=$$(openssl rand -base64 32)" > .env; \
		echo "HOST=0.0.0.0" >> .env; \
		echo "PORT=8001" >> .env; \
		echo -e "$(GREEN)✓ .env created$(NC)"; \
		echo -e "$(YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"; \
		echo -e "$(YELLOW)API Key:$(NC) $$(grep GPU_API_KEY .env | cut -d'=' -f2)"; \
		echo -e "$(YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"; \
	else \
		echo -e "$(GREEN)✓ .env exists$(NC)"; \
	fi

# 🚀 Запуск сервера
start:
	@echo -e "$(BLUE)Starting GPU server...$(NC)"
	@. $(VENV_BIN)/activate && $(PYTHON_VENV) server.py

# 🐛 Запуск в debug режиме
dev:
	@echo -e "$(BLUE)Starting GPU server (debug mode)...$(NC)"
	@. $(VENV_BIN)/activate && DEBUG=1 $(PYTHON_VENV) server.py

# 🧪 Все тесты
test: test-gpu test-health

# 🧪 Тест GPU
test-gpu:
	@echo -e "$(BLUE)Testing GPU...$(NC)"
	@. $(VENV_BIN)/activate && $(PYTHON_VENV) -c "import torch; print('CUDA available:', torch.cuda.is_available()); print('GPU:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'N/A')"

# 🧪 Тест сервера
test-health:
	@echo -e "$(BLUE)Testing server health...$(NC)"
	@curl -s http://localhost:8001/health || echo "Server not running"

# 🧪 Полный тест
test-full:
	@echo -e "$(BLUE)Running full test suite...$(NC)"
	@. $(VENV_BIN)/activate && $(PYTHON_VENV) test_server.py

# 🏥 Health check
health:
	@. $(VENV_BIN)/activate && $(PYTHON_VENV) -c "import requests; r = requests.get('http://localhost:8001/health'); print(r.json())" 2>/dev/null || echo "Server not running"

# 🖥️ GPU информация
gpu-info:
	@echo -e "$(BLUE)=== GPU Information ===$(NC)"
	@nvidia-smi --query-gpu=name,memory.total,memory.free,temperature.gpu --format=csv,noheader 2>/dev/null || echo "nvidia-smi not available"

# 🧹 Очистка временных файлов
clean:
	@echo -e "$(BLUE)Cleaning temporary files...$(NC)"
	rm -rf /tmp/avatar-factory/*
	rm -rf temp/*
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@echo -e "$(GREEN)✓ Cleaned$(NC)"

# 🗑️ Глубокая очистка
clean-all:
	@echo -e "$(YELLOW)⚠ This will remove venv and models!$(NC)"
	@read -p "Continue? (y/n) " -n 1 -r && echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(MAKE) clean; \
		rm -rf $(VENV); \
		rm -rf checkpoints/; \
		rm -rf models/; \
		echo -e "$(GREEN)✓ Deep clean complete$(NC)"; \
	fi

# 🔄 Перезапуск
restart:
	@pkill -f "python server.py" || true
	@sleep 2
	@$(MAKE) start

# 📊 Показать информацию
info:
	@echo -e "$(BLUE)=== GPU Worker Info ===$(NC)"
	@echo "Python: $$($(PYTHON) --version 2>&1)"
	@if [ -f "$(VENV_BIN)/python" ]; then \
		echo "venv Python: $$($(PYTHON_VENV) --version 2>&1)"; \
		echo "PyTorch: $$($(PYTHON_VENV) -c 'import torch; print(torch.__version__)' 2>/dev/null || echo 'Not installed')"; \
		echo "CUDA: $$($(PYTHON_VENV) -c 'import torch; print(torch.version.cuda)' 2>/dev/null || echo 'N/A')"; \
	fi
	@echo ""
	@if command -v nvidia-smi >/dev/null 2>&1; then \
		echo -e "$(BLUE)=== GPU Info ===$(NC)"; \
		nvidia-smi --query-gpu=name,memory.total --format=csv,noheader; \
	fi

# 📚 Requirements
requirements:
	@$(PIP) list

# 🔄 Обновление зависимостей
update:
	@echo -e "$(BLUE)Updating dependencies...$(NC)"
	@$(PIP) install --upgrade pip
	@$(PIP) install --upgrade -r requirements.txt
	@echo -e "$(GREEN)✓ Updated$(NC)"
