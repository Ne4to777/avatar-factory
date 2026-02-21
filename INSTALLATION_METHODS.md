# 🛠️ Методы установки - Сравнение и рекомендации

Avatar Factory поддерживает **5 разных способов установки** в зависимости от ваших потребностей и опыта.

---

## 📊 Сравнение методов

| Метод | Сложность | Время | Гибкость | Рекомендуется для |
|-------|-----------|-------|----------|-------------------|
| **1. npm scripts** | ⭐ Легко | 10 мин | ⭐⭐ | Новички |
| **2. Make** | ⭐⭐ Средне | 10 мин | ⭐⭐⭐ | Unix-системы |
| **3. Just** | ⭐ Легко | 10 мин | ⭐⭐⭐⭐ | Современный подход |
| **4. Shell Scripts** | ⭐ Легко | 10 мин | ⭐⭐ | Автоматизация |
| **5. Docker** | ⭐⭐⭐ Сложно | 30 мин | ⭐⭐⭐⭐⭐ | Production |

---

## 1️⃣ npm scripts (Самый простой) ⭐ Рекомендуется для новичков

**Преимущества:**
- ✅ Не требует дополнительных инструментов
- ✅ npm уже установлен
- ✅ Кроссплатформенность
- ✅ Встроен в проект

**Использование:**

```bash
# Установка
npm install
npm run setup

# Запуск
npm run dev          # Terminal 1: UI
npm run worker       # Terminal 2: Worker

# Или одной командой
npm run start:dev    # UI + Worker одновременно

# Тесты
npm run test

# Утилиты
npm run health       # Health check
npm run docker:ps    # Docker статус
npm run clean        # Очистка
```

**Минусы:**
- ❌ Только для Node.js части
- ❌ Нет управления Python зависимостями
- ❌ Ограниченная параллельность

---

## 2️⃣ Makefile (Классика) ⭐⭐ Рекомендуется для Unix

**Преимущества:**
- ✅ Стандарт индустрии (30+ лет)
- ✅ Отличное управление зависимостями
- ✅ Параллельное выполнение
- ✅ Работает везде (Linux, macOS, Windows с WSL)
- ✅ Self-documenting (`make help`)

**Использование:**

```bash
# Main App (ноутбук)
make install         # Полная установка
make start           # Запуск
make test            # Тесты
make clean           # Очистка

# GPU Worker (стационарный ПК)
cd gpu-worker
make install         # Установка GPU worker
make install-models  # Скачивание моделей
make start           # Запуск сервера
make gpu-info        # Информация о GPU
```

**Специальные команды:**

```bash
# Database
make db-migrate      # Применить миграции
make db-reset        # Сброс базы
make db-studio       # Открыть Prisma Studio

# Monitoring
make status          # Статус всех сервисов
make logs            # Docker логи
make health          # Health check

# Advanced
make build           # Production build
make update          # Обновление зависимостей
```

**Минусы:**
- ❌ Синтаксис может быть сложным
- ❌ Tabs vs Spaces (частая ошибка)
- ❌ Ограниченная кроссплатформенность

---

## 3️⃣ Justfile (Современная альтернатива Make) ⭐⭐⭐ Рекомендуется

**Преимущества:**
- ✅ Проще синтаксис чем Make
- ✅ Лучше error messages
- ✅ Встроенная поддержка .env
- ✅ Цветной вывод
- ✅ Cross-platform (включая Windows)
- ✅ Modern features (variables, functions)

**Установка Just:**

```bash
# macOS
brew install just

# Linux
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash

# Windows (Scoop)
scoop install just

# Windows (Cargo)
cargo install just
```

**Использование:**

```bash
# Показать все команды
just

# Main App
just install         # Полная установка
just start           # Запуск
just dev-all         # UI + Worker в tmux
just test            # Все тесты

# GPU Worker
cd gpu-worker
just install         # Установка
just start           # Запуск
just test-full       # Полный тест
```

**Особенности Justfile:**
- ✅ `set dotenv-load := true` - автозагрузка .env
- ✅ Переменные с значениями по умолчанию
- ✅ Conditions и loops
- ✅ Функции и рецепты

**Минусы:**
- ❌ Требует установку Just
- ❌ Менее распространен чем Make

---

## 4️⃣ Shell Scripts (Автоматизация) ⭐

**Преимущества:**
- ✅ Не требует установки инструментов
- ✅ Полный контроль
- ✅ Можно запускать удаленно (curl | bash)
- ✅ Интерактивные prompts

**Использование:**

```bash
# Универсальная установка
./quick-start.sh

# Или специфичные скрипты
./install.sh         # Main app
./start.sh           # Запуск

cd gpu-worker
./install.sh         # GPU worker install
./start.sh           # GPU worker start
```

**Когда использовать:**
- ✅ Первая установка на чистой системе
- ✅ CI/CD pipelines
- ✅ Удаленная установка
- ✅ Автоматизация без user interaction

**Минусы:**
- ❌ Сложнее поддерживать
- ❌ Менее структурированы
- ❌ Дублирование логики

---

## 5️⃣ Docker (Production-ready) ⭐⭐⭐⭐⭐

**Преимущества:**
- ✅ Полная изоляция
- ✅ Reproducible builds
- ✅ Легкий деплой
- ✅ Масштабируемость
- ✅ Не зависит от системы

**GPU Worker с Docker:**

```bash
cd gpu-worker

# Build image
docker build -t avatar-factory-gpu-worker .

# Run с GPU
docker run --gpus all \
  -p 8001:8001 \
  -e GPU_API_KEY=your-key \
  -v $(pwd)/checkpoints:/app/checkpoints \
  avatar-factory-gpu-worker

# Или через Docker Compose
docker-compose up -d
```

**Full Stack Docker Compose:**

```bash
# Весь стек в одном compose file
docker-compose -f docker-compose.full.yml up -d
```

**Минусы:**
- ❌ Требует Docker
- ❌ Большие образы (~15GB с моделями)
- ❌ Сложнее для разработки
- ❌ GPU passthrough может быть сложным

---

## 🎯 Рекомендации по выбору

### Для новичков:
```bash
# Самый простой способ
npm run install:full
npm run start:dev
```

### Для разработчиков:
```bash
# Make или Just (на ваш выбор)
make install && make start
# или
just install && just dev-all
```

### Для production:
```bash
# Docker для полной изоляции
docker-compose -f docker-compose.full.yml up -d
```

### Для автоматизации/CI/CD:
```bash
# Shell scripts
./quick-start.sh
```

---

## 🏆 Лучшие практики

### Комбинированный подход (рекомендуется):

**На стационарном ПК (GPU Worker):**
```bash
# Первая установка
make install              # или: ./install.sh

# Ежедневное использование
make start                # или: ./start.sh

# Обслуживание
make clean                # Очистка
make update               # Обновление
make test-full            # Тесты
```

**На ноутбуке (Main App):**
```bash
# Первая установка
make install              # или: npm run install:full

# Разработка
make dev                  # Terminal 1
make worker               # Terminal 2

# Или одной командой
just dev-all              # Запуск в tmux
# или
npm run start:dev         # Через concurrently

# Maintenance
make test                 # Тесты
make health               # Health check
make db-studio            # Prisma Studio
```

---

## 📋 Feature Matrix

| Функция | npm | Make | Just | Shell | Docker |
|---------|-----|------|------|-------|--------|
| **Auto-install** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Dependency check** | ❌ | ✅ | ✅ | ✅ | N/A |
| **Parallel execution** | ✅ | ✅ | ✅ | ❌ | ✅ |
| **Cross-platform** | ✅ | ⚠️ | ✅ | ⚠️ | ✅ |
| **Interactive** | ❌ | ❌ | ❌ | ✅ | ❌ |
| **Self-documenting** | ⚠️ | ✅ | ✅ | ❌ | ❌ |
| **Error handling** | ⚠️ | ✅ | ✅ | ✅ | ✅ |
| **TypeScript support** | ✅ | ✅ | ✅ | ❌ | ✅ |
| **Python support** | ❌ | ✅ | ✅ | ✅ | ✅ |
| **Learning curve** | Easy | Medium | Easy | Easy | Hard |

---

## 💡 Рекомендации по ситуациям

### Ситуация 1: Первая установка (без опыта)
```bash
# Используйте shell script
./quick-start.sh
```

### Ситуация 2: Ежедневная разработка
```bash
# Make или Just
make dev              # или: just dev
make worker           # или: just worker
```

### Ситуация 3: Быстрый старт
```bash
# npm scripts
npm run start:dev
```

### Ситуация 4: Production deployment
```bash
# Docker
docker-compose -f docker-compose.prod.yml up -d
```

### Ситуация 5: CI/CD Pipeline
```bash
# Make + Docker
make test && docker build . && docker push ...
```

---

## 🔧 Установка инструментов

### Make (обычно уже установлен)

```bash
# macOS
xcode-select --install

# Ubuntu/Debian
sudo apt install build-essential

# Windows
# Используйте WSL или установите Make через chocolatey
choco install make
```

### Just (современная альтернатива)

```bash
# macOS
brew install just

# Linux
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash

# Windows (Scoop)
scoop install just

# Windows (Cargo)
cargo install just
```

### Task (еще одна альтернатива)

```bash
# macOS
brew install go-task/tap/go-task

# Linux/Windows
# См. https://taskfile.dev
```

---

## 🎯 Наша рекомендация

### Для Avatar Factory используйте:

**1. Для первой установки:**
```bash
# Самый простой - shell script с интерактивными prompts
./quick-start.sh
```

**2. Для разработки:**
```bash
# Make - стандарт индустрии
make install
make dev
make worker

# Или Just - если хотите современный подход
just install
just dev-all  # Автоматически запустит UI + Worker в tmux
```

**3. Для быстрых команд:**
```bash
# npm scripts - быстрый доступ
npm run dev
npm run test
npm run health
```

**4. Для production:**
```bash
# Docker - изолированная среда
docker-compose -f docker-compose.prod.yml up -d
```

---

## 📚 Документация

Каждый метод задокументирован:

| Метод | Файл документации |
|-------|-------------------|
| npm scripts | `package.json` (см. scripts раздел) |
| Make | `Makefile` (run `make help`) |
| Just | `Justfile` (run `just` or `just --list`) |
| Shell Scripts | `SCRIPTS_README.md` |
| Docker | `DEPLOYMENT.md` |

---

## 🎓 Обучение

### Новичок в командной строке?
→ **Используйте:** `npm run` команды

### Знаком с Unix/Linux?
→ **Используйте:** `make` (стандарт)

### Хотите современные инструменты?
→ **Используйте:** `just` (лучше чем Make)

### Нужна полная автоматизация?
→ **Используйте:** shell scripts (`./install.sh`)

### Готовы к production?
→ **Используйте:** Docker

---

## 🚀 Quick Start по методам

### Метод 1: npm (Node.js only)
```bash
npm install
npm run docker:up
npm run prisma:generate
npm run prisma:migrate
npm run start:dev
```

### Метод 2: Make
```bash
make install
make dev  # Terminal 1
make worker  # Terminal 2
```

### Метод 3: Just
```bash
just install
just dev-all  # Автоматически в tmux
```

### Метод 4: Shell Scripts
```bash
./install.sh
./start.sh
```

### Метод 5: Docker
```bash
docker-compose up -d
```

---

## 🔍 Детальное сравнение

### npm scripts

**Пример workflow:**
```json
{
  "scripts": {
    "setup": "npm run docker:up && npm run prisma:migrate",
    "dev": "next dev",
    "worker": "tsx watch workers/video-worker.ts",
    "start:dev": "concurrently \"npm run dev\" \"npm run worker\""
  }
}
```

**Плюсы:**
- Простота
- Кроссплатформенность
- Не нужно ничего устанавливать

**Минусы:**
- Только для Node.js экосистемы
- Сложно управлять зависимостями задач
- Нет параллельного выполнения (без concurrently)

---

### Makefile

**Пример workflow:**
```makefile
install: check-deps install-node-deps setup-docker setup-db
    @echo "Installation complete"

dev: check-docker
    npm run dev

test: test-basic test-api
    @echo "All tests passed"
```

**Плюсы:**
- Управление зависимостями между задачами
- Параллельное выполнение (`make -j4`)
- Стандарт индустрии
- Работает с любыми языками

**Минусы:**
- Tabs vs Spaces (source of errors)
- Сложный синтаксис для новичков
- Разный синтаксис на разных системах

---

### Justfile

**Пример workflow:**
```just
# Modern, clean syntax
install: check-deps install-node-deps setup-docker setup-db
    echo "Installation complete"

# Easy conditionals
dev:
    #!/usr/bin/env bash
    if command -v tmux; then
        tmux new-session 'just dev-server'
    else
        npm run dev
    fi
```

**Плюсы:**
- Современный синтаксис (легче чем Make)
- Отличные error messages
- Cross-platform
- Встроенная поддержка .env
- Функции и условия

**Минусы:**
- Требует установку Just
- Менее распространен

---

### Shell Scripts

**Пример workflow:**
```bash
#!/bin/bash
set -e

check_deps() {
    command -v node || install_node
}

install() {
    check_deps
    npm install
    setup_docker
}
```

**Плюсы:**
- Полный контроль
- Интерактивные prompts
- Можно запускать удаленно (curl | bash)
- Не требует дополнительных инструментов

**Минусы:**
- Сложнее поддерживать
- Дублирование логики
- Разный синтаксис (bash/sh/zsh)

---

### Docker

**Пример workflow:**
```yaml
services:
  app:
    build: .
    depends_on:
      - postgres
      - redis
  
  gpu-worker:
    build: ./gpu-worker
    deploy:
      resources:
        reservations:
          devices:
            - capabilities: [gpu]
```

**Плюсы:**
- Полная изоляция
- Reproducible environment
- Easy deployment
- Масштабируемость

**Минусы:**
- Большие образы
- Сложность setup
- Overhead

---

## 🏁 Финальная рекомендация

### Для Avatar Factory используйте:

**Метод установки:**
1. **Первый раз:** Shell scripts (`./quick-start.sh`)
2. **Разработка:** Make или Just (на выбор)
3. **Production:** Docker

**Практический workflow:**

```bash
# === УСТАНОВКА (один раз) ===

# На стационарном ПК
git clone https://github.com/Ne4to777/avatar-factory.git
cd avatar-factory/gpu-worker
./install.sh              # Или: make install

# На ноутбуке
git clone https://github.com/Ne4to777/avatar-factory.git
cd avatar-factory
./install.sh              # Или: make install


# === ЕЖЕДНЕВНОЕ ИСПОЛЬЗОВАНИЕ ===

# Стационарный ПК
cd gpu-worker
make start                # Или: ./start.sh

# Ноутбук
make dev                  # Terminal 1
make worker               # Terminal 2
# Или: just dev-all       # Одна команда в tmux
# Или: npm run start:dev  # Через concurrently


# === MAINTENANCE ===

# Тесты
make test                 # Или: npm run test

# Очистка
make clean                # Или: npm run clean

# Health check
make health               # Или: npm run health

# Статус
make status               # Или: docker-compose ps
```

---

## 🎉 Вывод

Вы **правы** - использование специализированных инструментов (Make/Just) + npm scripts **лучше** чем только shell скрипты!

**Теперь у нас есть:**
- ✅ **npm scripts** - для Node.js задач
- ✅ **Makefile** - для сложных workflows
- ✅ **Justfile** - современная альтернатива
- ✅ **Shell scripts** - для первой установки
- ✅ **Docker** - для production
- ✅ **pyproject.toml** - для Python части

**Используйте то, что вам удобнее!** Все методы работают и хорошо задокументированы.

---

**Рекомендация:** `make` или `just` для ежедневного использования, shell scripts для первой установки.
