# Avatar Factory - Main Application Justfile
# https://github.com/casey/just
#
# Использование:
#   just install    - Полная установка
#   just start      - Запуск приложения
#   just test       - Запуск тестов
#   just clean      - Очистка

set shell := ["bash", "-c"]
set dotenv-load := true

# Переменные
node_version := "18"
docker_compose := "docker-compose"

# Цвета для вывода
RED := '\033[0;31m'
GREEN := '\033[0;32m'
YELLOW := '\033[1;33m'
BLUE := '\033[0;34m'
NC := '\033[0m'

# Default recipe (показывает help)
default:
    @just --list

# 🎯 Полная установка системы
install: check-deps install-node-deps setup-infrastructure setup-database test-basic
    @echo -e "{{GREEN}}✓ Installation complete!{{NC}}"
    @echo ""
    @echo -e "{{BLUE}}Next steps:{{NC}}"
    @echo "  1. Update .env with GPU server URL"
    @echo "  2. Run: just start"
    @echo "  3. Open: http://localhost:3000"

# 🚀 Запуск приложения (UI + Worker)
start: check-docker
    @echo -e "{{BLUE}}Starting Avatar Factory...{{NC}}"
    {{docker_compose}} up -d
    @sleep 3
    @echo -e "{{GREEN}}✓ Infrastructure started{{NC}}"
    @echo ""
    @echo -e "{{BLUE}}Starting services:{{NC}}"
    @echo "  Terminal 1: just dev"
    @echo "  Terminal 2: just worker"
    @echo ""
    @echo "Or run: just dev-all"

# 🖥️ Запуск только UI
dev:
    @echo -e "{{BLUE}}Starting Next.js dev server...{{NC}}"
    npm run dev

# ⚙️ Запуск только Worker
worker:
    @echo -e "{{BLUE}}Starting video worker...{{NC}}"
    npm run worker

# 🎬 Запуск UI + Worker одновременно (требует tmux)
dev-all:
    #!/usr/bin/env bash
    if command -v tmux &> /dev/null; then
        tmux new-session -d -s avatar-factory 'just dev'
        tmux split-window -h 'just worker'
        tmux attach-session -t avatar-factory
    else
        echo -e "{{YELLOW}}⚠ tmux not installed{{NC}}"
        echo "Install: brew install tmux (macOS) or apt install tmux (Linux)"
        echo "Or run in separate terminals:"
        echo "  Terminal 1: just dev"
        echo "  Terminal 2: just worker"
    fi

# 🛑 Остановка всех сервисов
stop:
    @echo -e "{{YELLOW}}Stopping services...{{NC}}"
    {{docker_compose}} down
    @pkill -f "next dev" || true
    @pkill -f "video-worker" || true
    @echo -e "{{GREEN}}✓ Services stopped{{NC}}"

# 🧪 Запуск всех тестов
test: test-basic test-api

# 🧪 Базовые тесты
test-basic:
    @echo -e "{{BLUE}}Running basic tests...{{NC}}"
    npx tsx test-basic.ts

# 🧪 Тесты API
test-api:
    @echo -e "{{BLUE}}Running API tests...{{NC}}"
    npx tsx test-api-full.ts

# 🏥 Health check
health:
    @echo -e "{{BLUE}}Checking system health...{{NC}}"
    @curl -s http://localhost:3000/api/health | jq '.' || echo "Server not running"

# 🏥 Health check GPU сервера
health-gpu:
    @echo -e "{{BLUE}}Checking GPU server health...{{NC}}"
    @curl -s ${GPU_SERVER_URL}/health | jq '.' || echo "GPU server not running"

# 📦 Установка Node.js зависимостей
install-node-deps:
    @echo -e "{{BLUE}}Installing npm dependencies...{{NC}}"
    npm install
    @echo -e "{{GREEN}}✓ Dependencies installed{{NC}}"

# 🐳 Настройка инфраструктуры (Docker)
setup-infrastructure: check-docker
    @echo -e "{{BLUE}}Setting up infrastructure...{{NC}}"
    {{docker_compose}} down || true
    {{docker_compose}} up -d
    @echo -e "{{BLUE}}Waiting for services...{{NC}}"
    @sleep 5
    @{{docker_compose}} ps
    @echo -e "{{GREEN}}✓ Infrastructure ready{{NC}}"

# 🗄️ Настройка базы данных
setup-database:
    @echo -e "{{BLUE}}Setting up database...{{NC}}"
    npx prisma generate
    npx prisma migrate deploy
    @echo -e "{{GREEN}}✓ Database ready{{NC}}"

# 🔄 Пересоздание базы данных
reset-database:
    @echo -e "{{YELLOW}}⚠ This will delete all data!{{NC}}"
    @read -p "Continue? (y/n) " -n 1 -r && echo
    @if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
        npx prisma migrate reset --force; \
        echo -e "{{GREEN}}✓ Database reset{{NC}}"; \
    fi

# 🧹 Очистка временных файлов
clean:
    @echo -e "{{BLUE}}Cleaning temporary files...{{NC}}"
    rm -rf node_modules/.cache
    rm -rf .next
    rm -rf /tmp/avatar-factory/*
    @echo -e "{{GREEN}}✓ Cleaned{{NC}}"

# 🗑️ Глубокая очистка
clean-all: stop
    @echo -e "{{YELLOW}}⚠ This will remove all data including Docker volumes!{{NC}}"
    @read -p "Continue? (y/n) " -n 1 -r && echo
    @if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
        just clean; \
        rm -rf node_modules; \
        rm -rf venv; \
        {{docker_compose}} down -v; \
        echo -e "{{GREEN}}✓ All cleaned{{NC}}"; \
    fi

# 📊 Показать статус сервисов
status:
    @echo -e "{{BLUE}}=== Docker Services ==={{NC}}"
    @{{docker_compose}} ps
    @echo ""
    @echo -e "{{BLUE}}=== Node.js Processes ==={{NC}}"
    @ps aux | grep -E "(next|worker)" | grep -v grep || echo "No processes running"
    @echo ""
    @echo -e "{{BLUE}}=== Queue Status ==={{NC}}"
    @redis-cli LLEN bull:video-generation:wait 2>/dev/null | xargs echo "Waiting:" || echo "Redis not accessible"
    @redis-cli LLEN bull:video-generation:active 2>/dev/null | xargs echo "Active:" || echo "Redis not accessible"

# 📦 Обновление зависимостей
update:
    @echo -e "{{BLUE}}Updating dependencies...{{NC}}"
    npm update
    npx prisma generate
    @echo -e "{{GREEN}}✓ Dependencies updated{{NC}}"

# 🔍 Проверка зависимостей
check-deps:
    @echo -e "{{BLUE}}Checking dependencies...{{NC}}"
    @command -v node >/dev/null 2>&1 && echo -e "{{GREEN}}✓ Node.js{{NC}}" || echo -e "{{RED}}✗ Node.js not found{{NC}}"
    @command -v npm >/dev/null 2>&1 && echo -e "{{GREEN}}✓ npm{{NC}}" || echo -e "{{RED}}✗ npm not found{{NC}}"
    @command -v docker >/dev/null 2>&1 && echo -e "{{GREEN}}✓ Docker{{NC}}" || echo -e "{{RED}}✗ Docker not found{{NC}}"
    @docker ps >/dev/null 2>&1 && echo -e "{{GREEN}}✓ Docker running{{NC}}" || echo -e "{{YELLOW}}⚠ Docker not running{{NC}}"

# 🐳 Проверка Docker
check-docker:
    @docker ps >/dev/null 2>&1 || (echo -e "{{RED}}✗ Docker is not running{{NC}}" && exit 1)

# 📝 Показать логи
logs service="":
    @if [ -z "{{service}}" ]; then \
        {{docker_compose}} logs -f; \
    else \
        {{docker_compose}} logs -f {{service}}; \
    fi

# 🔧 Открыть Prisma Studio
studio:
    npx prisma studio

# 🌐 Открыть UI в браузере
open:
    @open http://localhost:3000 || xdg-open http://localhost:3000 || echo "Open manually: http://localhost:3000"

# 🔐 Сгенерировать новый API ключ
generate-key:
    @openssl rand -base64 32

# 📊 Показать информацию о проекте
info:
    @echo -e "{{BLUE}}=== Project Info ==={{NC}}"
    @echo "Name: Avatar Factory"
    @echo "Version: 1.0.0"
    @echo "Node: $(node --version)"
    @echo "npm: $(npm --version)"
    @echo ""
    @echo -e "{{BLUE}}=== URLs ==={{NC}}"
    @echo "UI:      http://localhost:3000"
    @echo "Adminer: http://localhost:8080"
    @echo "MinIO:   http://localhost:9001"
    @echo ""
    @echo -e "{{BLUE}}=== Documentation ==={{NC}}"
    @echo "Quick Start:  QUICKSTART.md"
    @echo "Install:      INSTALL_GUIDE.md"
    @echo "Scripts:      SCRIPTS_README.md"
    @echo "Deployment:   DEPLOYMENT.md"

# 🔄 Перезагрузка при изменениях (watch mode)
watch:
    @echo -e "{{BLUE}}Starting in watch mode...{{NC}}"
    npm run dev

# 📦 Build для production
build:
    @echo -e "{{BLUE}}Building for production...{{NC}}"
    npm run build
    @echo -e "{{GREEN}}✓ Build complete{{NC}}"

# 🚀 Запуск production build
start-prod: build
    npm run start

# 🐛 Debug mode
debug:
    DEBUG=* npm run dev

# 📈 Показать метрики
metrics:
    @echo -e "{{BLUE}}=== Database ==={{NC}}"
    @echo "Videos: $(npx prisma db execute --stdin <<< 'SELECT COUNT(*) FROM \"Video\"' 2>/dev/null || echo 'N/A')"
    @echo "Users:  $(npx prisma db execute --stdin <<< 'SELECT COUNT(*) FROM \"User\"' 2>/dev/null || echo 'N/A')"
    @echo ""
    @echo -e "{{BLUE}}=== Queue ==={{NC}}"
    @redis-cli LLEN bull:video-generation:wait 2>/dev/null | xargs echo "Waiting:" || echo "Redis not accessible"
    @redis-cli LLEN bull:video-generation:active 2>/dev/null | xargs echo "Active:" || echo "Redis not accessible"
