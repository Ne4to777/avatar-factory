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
	@echo "  make install          - Full installation"
	@echo "  make setup-db         - Setup database only"
	@echo "  make setup-docker     - Setup Docker containers"
	@echo ""
	@echo "$(GREEN)Run:$(NC)"
	@echo "  make start            - Start all services"
	@echo "  make dev              - Start dev server"
	@echo "  make worker           - Start worker"
	@echo "  make stop             - Stop all services"
	@echo ""
	@echo "$(GREEN)Test:$(NC)"
	@echo "  make test             - Run all tests"
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

# 🎯 Полная установка
install: check-deps
	@echo -e "$(BLUE)Installing Avatar Factory...$(NC)"
	npm install
	@$(MAKE) setup-docker
	@$(MAKE) setup-db
	@$(MAKE) test-basic
	@echo -e "$(GREEN)✓ Installation complete!$(NC)"

# 📦 Установка Node.js зависимостей
install-deps:
	@echo -e "$(BLUE)Installing npm dependencies...$(NC)"
	npm install
	@echo -e "$(GREEN)✓ Dependencies installed$(NC)"

# 🐳 Настройка Docker
setup-docker:
	@echo -e "$(BLUE)Setting up Docker infrastructure...$(NC)"
	@if ! docker ps >/dev/null 2>&1; then \
		echo -e "$(RED)✗ Docker is not running$(NC)"; \
		exit 1; \
	fi
	docker-compose down || true
	docker-compose up -d
	@sleep 5
	docker-compose ps
	@echo -e "$(GREEN)✓ Docker infrastructure ready$(NC)"
	@echo ""
	@echo -e "$(BLUE)Available profiles:$(NC)"
	@echo "  --profile app    # Add App + Worker"
	@echo "  --profile gpu    # Add GPU Worker"
	@echo "  --profile full   # Everything"

# 🗄️ Настройка базы данных
setup-db:
	@echo -e "$(BLUE)Setting up database...$(NC)"
	npx prisma generate
	npx prisma migrate deploy
	@echo -e "$(GREEN)✓ Database ready$(NC)"

# 🚀 Запуск dev сервера
dev:
	npm run dev

# ⚙️ Запуск worker
worker:
	npm run worker

# 🛑 Остановка
stop:
	@echo -e "$(YELLOW)Stopping services...$(NC)"
	docker-compose down
	@pkill -f "next dev" || true
	@pkill -f "video-worker" || true
	@echo -e "$(GREEN)✓ Stopped$(NC)"

# 🧪 Все тесты
test: test-basic test-api

# 🧪 Базовые тесты
test-basic:
	@echo -e "$(BLUE)Running basic tests...$(NC)"
	npx tsx test-basic.ts

# 🧪 API тесты
test-api:
	@echo -e "$(BLUE)Running API tests...$(NC)"
	npx tsx test-api-full.ts

# 🏥 Health check
health:
	@echo -e "$(BLUE)System Health:$(NC)"
	@curl -s http://localhost:3000/api/health || echo "Server not running"

# 🧹 Очистка
clean:
	@echo -e "$(BLUE)Cleaning temporary files...$(NC)"
	rm -rf node_modules/.cache
	rm -rf .next
	rm -rf /tmp/avatar-factory/*
	@echo -e "$(GREEN)✓ Cleaned$(NC)"

# 🗑️ Глубокая очистка
clean-all: stop
	@echo -e "$(YELLOW)⚠ This will remove all data!$(NC)"
	@read -p "Continue? (y/n) " -n 1 -r && echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(MAKE) clean; \
		rm -rf node_modules; \
		docker-compose down -v; \
		echo -e "$(GREEN)✓ Deep clean complete$(NC)"; \
	fi

# 📊 Статус сервисов
status:
	@echo -e "$(BLUE)=== Docker Services ===$(NC)"
	@docker-compose ps
	@echo ""
	@echo -e "$(BLUE)=== Node.js Processes ===$(NC)"
	@ps aux | grep -E "(next|worker)" | grep -v grep || echo "No processes"

# 📝 Логи
logs:
	docker-compose logs -f

# 📝 Логи конкретного сервиса
logs-postgres:
	docker-compose logs -f postgres

logs-redis:
	docker-compose logs -f redis

logs-minio:
	docker-compose logs -f minio

# 🗄️ Database команды
db-migrate:
	npx prisma migrate dev

db-reset:
	npx prisma migrate reset

db-studio:
	npx prisma studio

db-seed:
	npx prisma db seed

# 📦 Build для production
build:
	@echo -e "$(BLUE)Building for production...$(NC)"
	npm run build
	@echo -e "$(GREEN)✓ Build complete$(NC)"

# 🚀 Запуск production
start-prod: build
	npm run start

# 🔍 Проверка зависимостей
check-deps:
	@echo -e "$(BLUE)Checking dependencies...$(NC)"
	@command -v node >/dev/null 2>&1 && echo -e "$(GREEN)✓ Node.js$(NC)" || (echo -e "$(RED)✗ Node.js not found$(NC)" && exit 1)
	@command -v npm >/dev/null 2>&1 && echo -e "$(GREEN)✓ npm$(NC)" || (echo -e "$(RED)✗ npm not found$(NC)" && exit 1)
	@command -v docker >/dev/null 2>&1 && echo -e "$(GREEN)✓ Docker$(NC)" || (echo -e "$(RED)✗ Docker not found$(NC)" && exit 1)

# 🌐 Открыть в браузере
open:
	@open http://localhost:3000 || xdg-open http://localhost:3000 || echo "Open: http://localhost:3000"

# 📊 Информация о проекте
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

# 🔐 Генерация API ключа
generate-key:
	@openssl rand -base64 32

# 📚 Показать документацию
docs:
	@echo -e "$(BLUE)Documentation:$(NC)"
	@echo "  README.md                  - Main documentation"
	@echo "  docs/QUICKSTART.md         - Quick start guide"
	@echo "  docs/INSTALL_GUIDE.md      - Installation guide"
	@echo "  docs/PROJECT_SUMMARY.md    - Project overview"
	@echo "  docs/DEPLOYMENT.md         - Production deployment"
