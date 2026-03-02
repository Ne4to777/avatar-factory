# Avatar Factory - Makefile
# Альтернатива Justfile для систем где Just не установлен

.PHONY: help install start stop test clean health info

# Colors
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m

# Default target
help:
	@echo "$(BLUE)Avatar Factory - Available Commands$(NC)"
	@echo ""
	@echo "$(GREEN)Setup:$(NC)"
	@echo "  make install          - Full installation (with Docker)"
	@echo "  make install-local    - Install without Docker"
	@echo "  make setup-db         - Setup database only"
	@echo "  make setup-docker     - Setup Docker containers"
	@echo ""
	@echo "$(GREEN)Run:$(NC)"
	@echo "  make start            - Start all services"
	@echo "  make dev              - Start dev server"
	@echo "  make worker           - Start worker"
	@echo "  make stop             - Stop all services"
	@echo ""
	@echo "$(GREEN)GPU Worker:$(NC)"
	@echo "  make build-gpu        - Build GPU Worker image"
	@echo "  make start-gpu        - Build & start GPU Worker"
	@echo ""
	@echo "$(GREEN)Test:$(NC)"
	@echo "  make test             - Run all tests"
	@echo "  make test-unit        - Run unit tests (172 tests)"
	@echo "  make test-integration - Run integration tests (requires DB)"
	@echo "  make test-basic       - Run basic tests"
	@echo "  make test-api         - Run API tests"
	@echo "  make health           - Check system health"
	@echo ""
	@echo "$(GREEN)Maintenance:$(NC)"
	@echo "  make clean            - Clean temporary files"
	@echo "  make clean-all        - Deep clean (removes volumes)"
	@echo "  make logs             - Show Docker logs"
	@echo "  make status           - Show service status"
	@echo ""
	@echo "$(GREEN)Database:$(NC)"
	@echo "  make db-migrate       - Apply migrations"
	@echo "  make db-reset         - Reset database"
	@echo "  make db-studio        - Open Prisma Studio"
	@echo ""
	@echo "$(GREEN)Development:$(NC)"
	@echo "  make build            - Build for production"
	@echo "  make format           - Format code"
	@echo "  make lint             - Lint code"

# Full installation (with Docker)
install: check-deps
	@echo -e "$(BLUE)Installing Avatar Factory...$(NC)"
	npm install
	@if docker ps >/dev/null 2>&1; then \
		$(MAKE) setup-docker; \
		$(MAKE) setup-db; \
	else \
		echo -e "$(YELLOW)[INFO] Docker not running - skipping setup-docker$(NC)"; \
		echo -e "$(YELLOW)[INFO] Run 'make setup-docker' after starting Docker$(NC)"; \
	fi
	@echo -e "$(GREEN)[OK] Installation complete$(NC)"

# Local installation (without Docker)
install-local: check-deps
	@echo -e "$(BLUE)Installing Avatar Factory (local mode)...$(NC)"
	npm install
	@echo -e "$(GREEN)[OK] Dependencies installed$(NC)"
	@echo -e "$(YELLOW)[INFO] To setup Docker: make setup-docker$(NC)"
	@echo -e "$(YELLOW)[INFO] To setup database: make setup-db$(NC)"

# Install Node.js dependencies
install-deps:
	@echo -e "$(BLUE)Installing npm dependencies...$(NC)"
	npm install
	@echo -e "$(GREEN)[OK] Dependencies installed$(NC)"

# Setup Docker infrastructure
setup-docker:
	@echo -e "$(BLUE)Setting up Docker infrastructure...$(NC)"
	@if ! docker ps >/dev/null 2>&1; then \
		echo -e "$(RED)[ERROR] Docker is not running$(NC)"; \
		echo -e "$(YELLOW)[WARNING] Please start Docker Desktop and try again$(NC)"; \
		exit 1; \
	fi
	docker-compose down || true
	docker-compose up -d
	@sleep 5
	docker-compose ps
	@echo -e "$(GREEN)[OK] Docker infrastructure ready$(NC)"
	@echo ""
	@echo -e "$(BLUE)Available profiles:$(NC)"
	@echo "  --profile app    # Add App + Worker"
	@echo "  --profile gpu    # Add GPU Worker"
	@echo "  --profile full   # Everything"

# Build GPU Worker
build-gpu:
	@echo -e "$(BLUE)Building GPU Worker Docker image...$(NC)"
	@echo -e "$(YELLOW)[INFO] First build: 15-20 minutes (~5GB downloads)$(NC)"
	@echo -e "$(YELLOW)[INFO] Cached build: 2-3 minutes (code changes only)$(NC)"
	DOCKER_BUILDKIT=1 docker build -f gpu-worker/Dockerfile -t avatar-gpu-worker:latest gpu-worker
	@echo -e "$(GREEN)[OK] GPU Worker image built$(NC)"

# Start GPU Worker
start-gpu: build-gpu
	@echo -e "$(BLUE)Starting GPU Worker container...$(NC)"
	docker stop avatar-gpu-worker 2>/dev/null || true
	docker rm avatar-gpu-worker 2>/dev/null || true
	docker run -d \
		--name avatar-gpu-worker \
		--gpus all \
		-p 8001:8001 \
		--env-file gpu-worker/.env \
		--restart unless-stopped \
		-v "$(PWD)/gpu-worker/checkpoints:/app/checkpoints" \
		-v "$(PWD)/gpu-worker/models:/app/models" \
		avatar-gpu-worker:latest
	@echo -e "$(GREEN)[OK] GPU Worker started$(NC)"
	@echo ""
	@echo "Health check: http://localhost:8001/health"

# Setup database
setup-db:
	@echo -e "$(BLUE)Setting up database...$(NC)"
	npx prisma generate
	npx prisma migrate deploy
	@echo -e "$(GREEN)[OK] Database ready$(NC)"

# Start dev server
dev:
	npm run dev

# Start worker
worker:
	npm run worker

# Stop all services
stop:
	@echo -e "$(YELLOW)Stopping services...$(NC)"
	docker-compose down
	@pkill -f "next dev" || true
	@pkill -f "video-worker" || true
	@echo -e "$(GREEN)[OK] Stopped$(NC)"

# Run all tests
test: test-unit test-integration test-basic test-api

# Unit tests (Vitest)
test-unit:
	@echo -e "$(BLUE)Running unit tests...$(NC)"
	npm run test:unit
	@echo -e "$(GREEN)[OK] Unit tests passed$(NC)"

# Integration tests (requires DB)
test-integration:
	@echo -e "$(BLUE)Running integration tests...$(NC)"
	@echo -e "$(YELLOW)[INFO] Requires: PostgreSQL running$(NC)"
	npm run test:integration
	@echo -e "$(GREEN)[OK] Integration tests passed$(NC)"

# Basic tests
test-basic:
	@echo -e "$(BLUE)Running basic tests...$(NC)"
	npx tsx test-basic.ts

# API tests
test-api:
	@echo -e "$(BLUE)Running API tests...$(NC)"
	npx tsx test-api-full.ts

# Health check
health:
	@echo -e "$(BLUE)System Health:$(NC)"
	@curl -s http://localhost:3000/api/health || echo "Server not running"

# Clean temporary files
clean:
	@echo -e "$(BLUE)Cleaning temporary files...$(NC)"
	rm -rf node_modules/.cache
	rm -rf .next
	rm -rf /tmp/avatar-factory/*
	@echo -e "$(GREEN)[OK] Cleaned$(NC)"

# Deep clean
clean-all: stop
	@echo -e "$(YELLOW)[WARNING] This will remove all data!$(NC)"
	@read -p "Continue? (y/n) " -n 1 -r && echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(MAKE) clean; \
		rm -rf node_modules; \
		docker-compose down -v; \
		echo -e "$(GREEN)[OK] Deep clean complete$(NC)"; \
	fi

# Service status
status:
	@echo -e "$(BLUE)=== Docker Services ===$(NC)"
	@docker-compose ps
	@echo ""
	@echo -e "$(BLUE)=== Node.js Processes ===$(NC)"
	@ps aux | grep -E "(next|worker)" | grep -v grep || echo "No processes"

# Show logs
logs:
	docker-compose logs -f

# Show specific service logs
logs-postgres:
	docker-compose logs -f postgres

logs-redis:
	docker-compose logs -f redis

logs-minio:
	docker-compose logs -f minio

# Database commands
db-migrate:
	npx prisma migrate dev

db-reset:
	npx prisma migrate reset

db-studio:
	npx prisma studio

db-seed:
	npx prisma db seed

# Build for production
build:
	@echo -e "$(BLUE)Building for production...$(NC)"
	npm run build
	@echo -e "$(GREEN)[OK] Build complete$(NC)"

# Start production
start-prod: build
	npm run start

# Check dependencies
check-deps:
	@echo -e "$(BLUE)Checking dependencies...$(NC)"
	@command -v node >/dev/null 2>&1 && echo -e "$(GREEN)[OK] Node.js$(NC)" || (echo -e "$(RED)[ERROR] Node.js not found$(NC)" && exit 1)
	@command -v npm >/dev/null 2>&1 && echo -e "$(GREEN)[OK] npm$(NC)" || (echo -e "$(RED)[ERROR] npm not found$(NC)" && exit 1)
	@command -v docker >/dev/null 2>&1 && echo -e "$(GREEN)[OK] Docker$(NC)" || echo -e "$(YELLOW)[INFO] Docker not found (optional for local dev)$(NC)"

# Open in browser
open:
	@open http://localhost:3000 || xdg-open http://localhost:3000 || echo "Open: http://localhost:3000"

# Project info
info:
	@echo -e "$(BLUE)=== Project Info ===$(NC)"
	@echo "Name:    Avatar Factory"
	@echo "Version: 1.0.0"
	@echo "Node:    $$(node --version)"
	@echo "npm:     $$(npm --version)"
	@echo ""
	@echo -e "$(BLUE)=== URLs ===$(NC)"
	@echo "UI:      http://localhost:3000"
	@echo "Adminer: http://localhost:8080"
	@echo "MinIO:   http://localhost:9001"

# Generate API key
generate-key:
	@openssl rand -base64 32

# Show documentation
docs:
	@echo -e "$(BLUE)Documentation:$(NC)"
	@echo "  README.md                         - Main documentation"
	@echo "  docs/API.md                       - API Reference (NEW!)"
	@echo "  docs/QUICKSTART.md                - Quick start guide"
	@echo "  docs/REFACTORING_COMPLETE.md      - Refactoring report (NEW!)"
	@echo "  docs/INSTALL_GUIDE.md             - Installation guide"
	@echo "  docs/PROJECT_SUMMARY.md           - Project overview"
	@echo "  docs/DEPLOYMENT.md                - Production deployment"
