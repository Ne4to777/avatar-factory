# 🔧 Build Tools - Что у нас есть

Полный обзор всех build tools и automation инструментов в Avatar Factory.

---

## 📋 Инвентаризация

### ✅ npm scripts (`package.json`)

**Расположение:** `/package.json`

**Команды:**

```bash
# Разработка
npm run dev           # Next.js dev server
npm run build         # Production build
npm run start         # Production server
npm run lint          # ESLint

# Worker
npm run worker        # Video worker
npm run start:dev     # UI + Worker одновременно (concurrently)

# Database
npm run prisma:generate  # Generate Prisma client
npm run prisma:migrate   # Run migrations
npm run prisma:studio    # Open Prisma Studio
npm run prisma:reset     # Reset database

# Docker
npm run docker:up     # Start containers
npm run docker:down   # Stop containers
npm run docker:logs   # View logs
npm run docker:ps     # Container status

# Testing
npm run test          # All tests
npm run test:basic    # Basic infrastructure tests
npm run test:api      # API tests

# Utilities
npm run setup         # Full setup (docker + migrations)
npm run install:full  # Complete installation
npm run health        # Health check
npm run clean         # Clean cache
npm run clean:all     # Deep clean

# Quality
npm run format        # Prettier
npm run type-check    # TypeScript check
```

**Зависимости:**
- `concurrently` - для параллельного запуска dev + worker
- `tsx` - для выполнения TypeScript
- `prisma` - ORM и миграции

---

### ✅ Makefile (Main App)

**Расположение:** `/Makefile`

**Основные команды:**

```bash
make help            # Показать все команды

# Setup
make install         # Полная установка
make install-deps    # Только npm dependencies
make setup-docker    # Настройка Docker
make setup-db        # Настройка базы данных

# Run
make dev             # Dev server
make worker          # Worker
make start-prod      # Production server
make stop            # Остановить все

# Test
make test            # Все тесты
make test-basic      # Базовые тесты
make test-api        # API тесты
make health          # Health check

# Database
make db-migrate      # Применить миграции
make db-reset        # Сброс базы
make db-studio       # Prisma Studio
make db-seed         # Seed data

# Monitoring
make status          # Статус сервисов
make logs            # Docker логи
make logs-postgres   # Логи PostgreSQL
make logs-redis      # Логи Redis

# Maintenance
make clean           # Очистка
make clean-all       # Глубокая очистка
make update          # Обновление зависимостей

# Utilities
make check-deps      # Проверка зависимостей
make open            # Открыть в браузере
make info            # Информация о проекте
make generate-key    # Генерация API ключа
```

**Преимущества:**
- ✅ Управление зависимостями между задачами
- ✅ Проверка системы перед выполнением
- ✅ Цветной вывод
- ✅ Стандарт индустрии

---

### ✅ Justfile (Main App)

**Расположение:** `/Justfile`

**Основные команды:**

```bash
just                 # Показать все команды

# Setup
just install         # Полная установка
just install-node-deps    # npm install
just setup-infrastructure # Docker setup
just setup-database       # DB setup

# Run
just dev             # Dev server
just worker          # Worker
just dev-all         # UI + Worker в tmux
just start           # Стартовое меню
just stop            # Остановить все

# Test
just test            # Все тесты
just test-basic      # Базовые тесты
just test-api        # API тесты
just health          # Health check
just health-gpu      # GPU server check

# Database
just setup-database  # Настройка
just reset-database  # Сброс (с подтверждением)

# Monitoring
just status          # Статус сервисов
just logs            # Логи
just metrics         # Метрики (БД, очереди)

# Maintenance
just clean           # Очистка
just clean-all       # Глубокая очистка (с подтверждением)
just update          # Обновление зависимостей

# Utilities
just check-deps      # Проверка зависимостей
just open            # Открыть в браузере
just info            # Информация
just generate-key    # API ключ
just studio          # Prisma Studio
```

**Преимущества:**
- ✅ Проще синтаксис чем Make
- ✅ Встроенная поддержка .env
- ✅ Лучше error messages
- ✅ Cross-platform
- ✅ Bash scripts внутри рецептов

---

### ✅ Makefile (GPU Worker)

**Расположение:** `/gpu-worker/Makefile`

**Основные команды:**

```bash
make help            # Показать все команды

# Setup
make install         # Полная установка
make setup-venv      # Virtual environment
make install-pytorch # PyTorch + CUDA
make install-deps    # Python dependencies
make setup-sadtalker # SadTalker setup
make install-models  # Скачивание моделей (~10GB)
make create-env      # Создание .env

# Run
make start           # Запуск сервера
make dev             # Debug режим
make restart         # Перезапуск

# Test
make test            # Все тесты
make test-gpu        # Тест GPU
make test-health     # Health check
make test-full       # Полный test suite

# Monitoring
make health          # Health check
make gpu-info        # GPU информация
make info            # System info

# Maintenance
make clean           # Очистка temp файлов
make clean-all       # Глубокая очистка (venv, models)
make update          # Обновление dependencies
make requirements    # Список установленных пакетов
```

**Преимущества:**
- ✅ Управление Python venv
- ✅ Автоматическая установка CUDA/PyTorch
- ✅ Проверка GPU
- ✅ Скачивание больших моделей

---

### ✅ Shell Scripts (Main App)

**Расположение:** `/`

#### `quick-start.sh`
Универсальный установщик, определяет тип машины:

```bash
./quick-start.sh

# Интерактивно выбирает:
# 1. GPU Worker
# 2. Main Application
# 3. Full Stack (оба)
```

#### `install.sh`
Полная установка Main App:

```bash
./install.sh

# Включает:
# - Проверку зависимостей (node, npm, docker)
# - npm install
# - Docker setup (postgres, redis, minio)
# - Prisma migrations
# - Создание .env
# - Тесты
```

#### `start.sh`
Запуск приложения:

```bash
./start.sh

# Интерактивное меню:
# 1. Development (UI + Worker)
# 2. Production
# 3. Worker only
# 4. Development (UI only)
```

**Преимущества:**
- ✅ Интерактивные prompts
- ✅ Проверка всех зависимостей
- ✅ Подробные инструкции
- ✅ Цветной вывод
- ✅ Error handling

---

### ✅ Shell Scripts (GPU Worker)

**Расположение:** `/gpu-worker/`

#### `install.sh` (Linux/macOS)
Полная установка GPU Worker:

```bash
cd gpu-worker
./install.sh

# Включает:
# - Проверку Python, git, GPU
# - Создание venv
# - Установку PyTorch + CUDA
# - Установку зависимостей
# - Setup SadTalker
# - Скачивание моделей
# - Создание .env с API ключом
```

#### `install.bat` (Windows)
То же самое для Windows:

```cmd
cd gpu-worker
install.bat
```

#### `start.sh` (Linux/macOS)
Запуск GPU сервера:

```bash
./start.sh

# - Активация venv
# - Загрузка .env
# - Определение IP адреса
# - Запуск FastAPI сервера
```

#### `start.bat` (Windows)
То же самое для Windows:

```cmd
start.bat
```

**Преимущества:**
- ✅ Cross-platform (Linux/macOS/Windows)
- ✅ Полностью автоматизированы
- ✅ Проверка GPU
- ✅ Automatic IP discovery
- ✅ API key generation

---

### ✅ Docker

**Расположение:** `/docker-compose.yml`, `/docker-compose.full.yml`, `/gpu-worker/docker-compose.yml`

#### `docker-compose.yml` (Infrastructure only)
PostgreSQL, Redis, MinIO, Adminer:

```bash
docker-compose up -d           # Запуск
docker-compose down            # Остановка
docker-compose logs -f         # Логи
docker-compose ps              # Статус
```

#### `docker-compose.full.yml` (Full Stack)
Весь стек включая App, Worker, GPU:

```bash
docker-compose -f docker-compose.full.yml up -d
docker-compose -f docker-compose.full.yml --profile production up -d  # С nginx
```

#### `gpu-worker/docker-compose.yml`
Только GPU Worker:

```bash
cd gpu-worker
docker-compose up -d
```

#### `gpu-worker/Dockerfile`
Multi-stage build для GPU Worker:

```bash
cd gpu-worker
docker build -t avatar-factory-gpu-worker .
docker run --gpus all -p 8001:8001 avatar-factory-gpu-worker
```

**Преимущества:**
- ✅ Полная изоляция
- ✅ Reproducible builds
- ✅ GPU passthrough (nvidia-docker)
- ✅ Health checks
- ✅ Volume management
- ✅ Network isolation

---

### ✅ Python Package Configuration

**Расположение:** `/gpu-worker/`

#### `pyproject.toml`
Modern Python configuration:

```toml
[project]
name = "avatar-factory-gpu-worker"
dependencies = [...]

[tool.black]
line-length = 100

[tool.ruff]
...
```

#### `setup.py`
Classic setuptools:

```python
setup(
    name="avatar-factory-gpu-worker",
    version="1.0.0",
    ...
)
```

**Установка как пакет:**

```bash
cd gpu-worker
pip install -e .              # Editable install
pip install -e ".[gpu]"       # С GPU extras
pip install -e ".[dev]"       # С dev tools
```

**Преимущества:**
- ✅ Modern Python standards
- ✅ Dependency management
- ✅ Optional dependencies (gpu, dev)
- ✅ Console scripts
- ✅ Editable install для разработки

---

## 🎯 Какой инструмент использовать?

### По задаче:

| Задача | Инструмент | Команда |
|--------|------------|---------|
| **Первая установка** | Shell Script | `./install.sh` |
| **Ежедневная разработка** | Make/Just | `make dev` / `just dev` |
| **Быстрые команды** | npm | `npm run dev` |
| **Production** | Docker | `docker-compose up` |
| **CI/CD** | Make + Docker | `make test && docker build` |
| **Тестирование** | Make/npm | `make test` / `npm test` |
| **GPU Worker** | Make/Shell | `make start` / `./start.sh` |

### По опыту:

| Уровень | Рекомендуется | Альтернатива |
|---------|---------------|--------------|
| **Новичок** | Shell Scripts | npm scripts |
| **Средний** | Make | npm scripts |
| **Опытный** | Just / Make | Docker |
| **DevOps** | Docker | Make + Docker |

---

## 📊 Матрица функций

| Функция | npm | Make | Just | Shell | Docker |
|---------|-----|------|------|-------|--------|
| **Auto-dependency check** | ❌ | ✅ | ✅ | ✅ | N/A |
| **Parallel execution** | ✅ | ✅ | ✅ | ❌ | ✅ |
| **Interactive prompts** | ❌ | ❌ | ❌ | ✅ | ❌ |
| **Cross-platform** | ✅ | ⚠️ | ✅ | ⚠️ | ✅ |
| **TypeScript support** | ✅ | ✅ | ✅ | ❌ | ✅ |
| **Python support** | ❌ | ✅ | ✅ | ✅ | ✅ |
| **No additional install** | ✅ | ⚠️ | ❌ | ✅ | ❌ |
| **Self-documenting** | ⚠️ | ✅ | ✅ | ❌ | ❌ |
| **IDE integration** | ✅ | ✅ | ⚠️ | ❌ | ⚠️ |

---

## 🔧 Практические рекомендации

### Комбинированный подход (лучший):

**Для первой установки:**
```bash
./quick-start.sh     # или ./install.sh
```

**Для ежедневной работы:**
```bash
make dev             # Простой и быстрый
make worker
make test
```

**Для быстрых команд:**
```bash
npm run health       # Quick health check
npm run docker:ps    # Docker status
```

**Для production:**
```bash
docker-compose -f docker-compose.full.yml up -d
```

---

## 📚 Документация

| Инструмент | Документация | Команда help |
|------------|--------------|--------------|
| **npm** | `package.json` | `npm run` (без аргументов) |
| **Make** | `Makefile` | `make help` |
| **Just** | `Justfile` | `just` или `just --list` |
| **Shell** | `SCRIPTS_README.md` | `-h` или `--help` |
| **Docker** | `DEPLOYMENT.md` | `docker-compose help` |

---

## 🎓 Обучающие ресурсы

### Make:
- [GNU Make Manual](https://www.gnu.org/software/make/manual/)
- [Makefile Tutorial](https://makefiletutorial.com/)

### Just:
- [Official docs](https://just.systems/)
- [GitHub](https://github.com/casey/just)

### npm scripts:
- [npm docs](https://docs.npmjs.com/cli/v9/using-npm/scripts)

### Docker:
- [Docker docs](https://docs.docker.com/)
- [Docker Compose](https://docs.docker.com/compose/)

---

## ✅ Выводы

### У нас есть:

1. ✅ **npm scripts** - для Node.js экосистемы
2. ✅ **Makefile** - для общих задач (рекомендуется)
3. ✅ **Justfile** - современная альтернатива Make
4. ✅ **Shell scripts** - для автоматизации и первой установки
5. ✅ **Docker** - для production deployment
6. ✅ **pyproject.toml** - для Python части

### Рекомендация:

**Используйте Make как основной инструмент:**
- ✅ Стандарт индустрии
- ✅ Работает везде
- ✅ Управление зависимостями
- ✅ Простой и понятный

**Shell scripts - для first-time setup:**
- ✅ Интерактивная установка
- ✅ Проверка системы
- ✅ Подробные инструкции

**npm scripts - как дополнение:**
- ✅ Быстрые команды
- ✅ Node.js задачи
- ✅ Интеграция с IDE

**Docker - для production:**
- ✅ Изолированная среда
- ✅ Легкий deploy
- ✅ Масштабируемость

---

**Теперь у вас есть полный набор инструментов для любой ситуации!** 🎉
