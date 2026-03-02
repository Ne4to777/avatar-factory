# ================================================================
# Avatar Factory GPU Worker - Makefile for Windows
# ================================================================
# 
# Prerequisites:
# - Python 3.10 or 3.11
# - CUDA 11.8 installed
# - NVIDIA GPU
# - GNU Make (Git Bash, WSL, or chocolatey install make)
#
# Usage:
#   make install      # Full installation
#   make run          # Start server
#   make test         # Run tests
#   make clean        # Clean temp files
#   make help         # Show all commands
# ================================================================

# Detect OS
ifeq ($(OS),Windows_NT)
    PYTHON := python
    VENV_BIN := venv/Scripts
    ACTIVATE := $(VENV_BIN)/activate
    RM := cmd /c rmdir /s /q
    MKDIR := cmd /c mkdir
else
    PYTHON := python3
    VENV_BIN := venv/bin
    ACTIVATE := $(VENV_BIN)/activate
    RM := rm -rf
    MKDIR := mkdir -p
endif

# Colors for output (works in Git Bash on Windows)
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

.PHONY: help install install-deps install-pytorch install-mmcv run test clean check-python check-cuda status venv

# Default target
help:
	@echo "$(BLUE)Avatar Factory GPU Worker - Make Commands$(NC)"
	@echo ""
	@echo "Setup:"
	@echo "  make install          Full installation (recommended)"
	@echo "  make venv             Create virtual environment only"
	@echo "  make install-deps     Install all dependencies"
	@echo ""
	@echo "Run:"
	@echo "  make run              Start GPU worker server"
	@echo "  make status           Check installation status"
	@echo ""
	@echo "Testing:"
	@echo "  make test             Run tests"
	@echo "  make check-python     Check Python version"
	@echo "  make check-cuda       Check CUDA availability"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean            Remove temp files"
	@echo "  make clean-venv       Remove virtual environment"
	@echo "  make reinstall        Clean install from scratch"
	@echo ""

# Full installation
install: check-python venv install-deps
	@echo "$(GREEN)[OK] Installation complete!$(NC)"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Set up .env file (copy from .env.example)"
	@echo "  2. Run: make run"
	@echo ""

# Create virtual environment
venv:
	@echo "$(BLUE)[1/4] Creating virtual environment...$(NC)"
	@if [ -d "venv" ]; then \
		echo "$(YELLOW)[WARNING] venv already exists$(NC)"; \
	else \
		$(PYTHON) -m venv venv; \
		echo "$(GREEN)[OK] Virtual environment created$(NC)"; \
	fi

# Install all dependencies in correct order
install-deps: venv
	@echo "$(BLUE)[2/4] Upgrading pip, setuptools, wheel...$(NC)"
	@bash -c "source $(ACTIVATE) && python -m pip install --upgrade pip setuptools wheel"
	@echo "$(GREEN)[OK] Base tools upgraded$(NC)"
	@echo ""
	@echo "$(BLUE)[3/4] Installing PyTorch 2.1.0 + CUDA 11.8...$(NC)"
	@echo "$(YELLOW)This may take several minutes...$(NC)"
	@bash -c "source $(ACTIVATE) && pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu118"
	@echo "$(GREEN)[OK] PyTorch installed$(NC)"
	@echo ""
	@echo "$(BLUE)[4/4] Installing OpenMMLab packages...$(NC)"
	@bash -c "source $(ACTIVATE) && pip install -U openmim"
	@bash -c "source $(ACTIVATE) && mim install mmcv==2.1.0"
	@bash -c "source $(ACTIVATE) && pip install 'mmdet>=3.3.0' 'mmpose>=1.3.0'"
	@echo "$(GREEN)[OK] OpenMMLab packages installed$(NC)"
	@echo ""
	@echo "$(BLUE)Installing remaining dependencies...$(NC)"
	@bash -c "source $(ACTIVATE) && pip install -r requirements.txt"
	@echo "$(GREEN)[OK] All dependencies installed$(NC)"

# Alternative: Install PyTorch only
install-pytorch: venv
	@echo "$(BLUE)Installing PyTorch 2.1.0 + CUDA 11.8...$(NC)"
	@bash -c "source $(ACTIVATE) && pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu118"
	@echo "$(GREEN)[OK] PyTorch installed$(NC)"

# Alternative: Install mmcv only
install-mmcv: venv
	@echo "$(BLUE)Installing mmcv via mim...$(NC)"
	@bash -c "source $(ACTIVATE) && pip install -U openmim"
	@bash -c "source $(ACTIVATE) && mim install mmcv==2.1.0"
	@bash -c "source $(ACTIVATE) && pip install 'mmdet>=3.3.0' 'mmpose>=1.3.0'"
	@echo "$(GREEN)[OK] mmcv installed$(NC)"

# Run server
run:
	@echo "$(BLUE)Starting GPU Worker...$(NC)"
	@bash -c "source $(ACTIVATE) && python server.py"

# Run in background (requires nohup)
run-background:
	@echo "$(BLUE)Starting GPU Worker in background...$(NC)"
	@bash -c "source $(ACTIVATE) && nohup python server.py > server.log 2>&1 &"
	@echo "$(GREEN)[OK] Server started in background$(NC)"
	@echo "Check logs: tail -f server.log"

# Check installation status
status:
	@echo "$(BLUE)=== Installation Status ===$(NC)"
	@echo ""
	@echo "Python:"
	@$(PYTHON) --version
	@echo ""
	@echo "Virtual Environment:"
	@if [ -d "venv" ]; then \
		echo "$(GREEN)[OK] venv exists$(NC)"; \
	else \
		echo "$(RED)[ERROR] venv not found$(NC)"; \
	fi
	@echo ""
	@echo "PyTorch:"
	@bash -c "source $(ACTIVATE) && python -c 'import torch; print(f\"  Version: {torch.__version__}\"); print(f\"  CUDA Available: {torch.cuda.is_available()}\"); print(f\"  CUDA Version: {torch.version.cuda if torch.cuda.is_available() else \"N/A\"}\")' 2>/dev/null || echo '$(RED)[ERROR] PyTorch not installed$(NC)'"
	@echo ""
	@echo "OpenMMLab:"
	@bash -c "source $(ACTIVATE) && python -c 'try:\n    import mmcv; print(f\"  mmcv: {mmcv.__version__}\")\nexcept: print(\"  mmcv: $(RED)NOT INSTALLED$(NC)\")'" 2>/dev/null
	@bash -c "source $(ACTIVATE) && python -c 'try:\n    import mmdet; print(f\"  mmdet: {mmdet.__version__}\")\nexcept: print(\"  mmdet: $(RED)NOT INSTALLED$(NC)\")'" 2>/dev/null
	@bash -c "source $(ACTIVATE) && python -c 'try:\n    import mmpose; print(f\"  mmpose: {mmpose.__version__}\")\nexcept: print(\"  mmpose: $(RED)NOT INSTALLED$(NC)\")'" 2>/dev/null
	@echo ""

# Check Python version
check-python:
	@echo "$(BLUE)Checking Python version...$(NC)"
	@$(PYTHON) --version
	@$(PYTHON) -c "import sys; exit(0 if sys.version_info >= (3, 10) and sys.version_info < (3, 12) else 1)" || \
		(echo "$(RED)[ERROR] Python 3.10 or 3.11 required$(NC)" && exit 1)
	@echo "$(GREEN)[OK] Python version compatible$(NC)"

# Check CUDA
check-cuda:
	@echo "$(BLUE)Checking CUDA...$(NC)"
	@bash -c "source $(ACTIVATE) && python -c 'import torch; assert torch.cuda.is_available(), \"CUDA not available\"; print(f\"$(GREEN)[OK] CUDA {torch.version.cuda} available$(NC)\")'" || \
		echo "$(RED)[ERROR] CUDA not available$(NC)"

# Run tests
test:
	@echo "$(BLUE)Running tests...$(NC)"
	@bash -c "source $(ACTIVATE) && python -m pytest test_temp_file_cleanup.py -v" || echo "$(YELLOW)[WARNING] No tests found or pytest not installed$(NC)"

# Clean temp files
clean:
	@echo "$(BLUE)Cleaning temporary files...$(NC)"
	@if [ -d "__pycache__" ]; then $(RM) __pycache__; fi
	@if [ -d "*.pyc" ]; then find . -name "*.pyc" -delete 2>/dev/null || true; fi
	@if [ -d ".pytest_cache" ]; then $(RM) .pytest_cache; fi
	@echo "$(GREEN)[OK] Cleaned$(NC)"

# Remove virtual environment
clean-venv:
	@echo "$(BLUE)Removing virtual environment...$(NC)"
	@if [ -d "venv" ]; then \
		$(RM) venv; \
		echo "$(GREEN)[OK] venv removed$(NC)"; \
	else \
		echo "$(YELLOW)[WARNING] venv not found$(NC)"; \
	fi

# Full reinstall
reinstall: clean-venv install
	@echo "$(GREEN)[OK] Reinstallation complete$(NC)"

# Health check
health:
	@echo "$(BLUE)Checking GPU Worker health...$(NC)"
	@curl -f http://localhost:8001/health || echo "$(RED)[ERROR] Server not running$(NC)"

# Show server logs (if running in background)
logs:
	@if [ -f "server.log" ]; then \
		tail -f server.log; \
	else \
		echo "$(RED)[ERROR] server.log not found. Is server running in background?$(NC)"; \
	fi
