# 📜 Скрипты установки и запуска

Полный список всех скриптов для быстрой установки и запуска Avatar Factory.

---

## 🚀 Универсальные скрипты

### `quick-start.sh` - Универсальный установщик

**Автоматически определяет тип машины и устанавливает нужные компоненты.**

```bash
# Запуск из интернета
curl -sSL https://raw.githubusercontent.com/Ne4to777/avatar-factory/main/quick-start.sh | bash

# Или локально
./quick-start.sh
```

**Что делает:**
- ✅ Определяет наличие GPU
- ✅ Спрашивает что установить (GPU Worker / Main App / Full Stack)
- ✅ Запускает соответствующий установщик
- ✅ Выводит инструкции по запуску

**Время:** 25-50 минут (в зависимости от выбора и скорости интернета)

---

## 🖥️ GPU Worker (Стационарный ПК)

### `gpu-worker/install.sh` (Linux/macOS)

**Установка GPU сервера на Linux или macOS.**

```bash
cd gpu-worker
./install.sh
```

**Что делает:**
1. Проверяет prerequisites (Python, pip, git, CUDA)
2. Устанавливает недостающие зависимости
3. Создает Python virtual environment
4. Устанавливает PyTorch с CUDA
5. Устанавливает Python зависимости (FastAPI, Diffusers, etc.)
6. Клонирует и настраивает SadTalker
7. Предлагает скачать AI модели (~10GB)
8. Создает `.env` файл с случайным API ключом
9. Запускает тесты

**Требования:**
- Python 3.10+
- NVIDIA GPU + CUDA 11.8+
- ~20GB свободного места
- Интернет для скачивания моделей

**Время:** 30-45 минут

---

### `gpu-worker/install.bat` (Windows)

**Установка GPU сервера на Windows.**

```cmd
cd gpu-worker
install.bat
```

**Что делает:**
- То же самое что `install.sh`, но для Windows
- Использует Windows-специфичные команды
- Проверяет права администратора
- Генерирует API ключ без openssl

**Требования:**
- Python 3.10+ (добавлен в PATH)
- NVIDIA GPU + CUDA 11.8+
- ~20GB свободного места

**Время:** 30-45 минут

---

### `gpu-worker/start.sh` / `gpu-worker/start.bat`

**Запуск GPU сервера.**

```bash
# Linux/macOS
cd gpu-worker
./start.sh

# Windows
cd gpu-worker
start.bat
```

**Что делает:**
1. Активирует Python virtual environment
2. Проверяет наличие `.env`
3. Определяет IP адрес машины
4. Запускает FastAPI сервер
5. Выводит URL для доступа

**Сервер запустится на:**
- `http://localhost:8001`
- `http://YOUR_IP:8001`

---

## 💻 Main Application (Ноутбук)

### `install.sh` (Linux/macOS)

**Установка главного приложения.**

```bash
./install.sh
```

**Что делает:**
1. Проверяет Node.js (устанавливает если нет)
2. Проверяет Docker (просит установить если нет)
3. Устанавливает npm зависимости
4. Запускает Docker Compose (PostgreSQL, Redis, MinIO)
5. Применяет Prisma миграции
6. Создает `.env` из `.env.example`
7. Запускает базовые тесты

**Требования:**
- Node.js 18+
- Docker Desktop
- ~2GB свободного места

**Время:** 10-15 минут

---

### `start.sh` (Linux/macOS)

**Запуск главного приложения.**

```bash
./start.sh
```

**Что делает:**
1. Проверяет и запускает Docker
2. Запускает Docker Compose
3. Спрашивает режим работы:
   - **Development** - только UI
   - **Production** - UI + Worker
   - **Worker only** - только Worker
4. Запускает выбранные сервисы
5. Выводит URLs и логи

**Сервисы запустятся на:**
- UI: `http://localhost:3000`
- Adminer: `http://localhost:8080`
- MinIO: `http://localhost:9001`

---

## 🧪 Тестовые скрипты

### `test-basic.ts`

**Базовые тесты инфраструктуры.**

```bash
npx tsx test-basic.ts
```

**Тестирует:**
- ✅ PostgreSQL connection
- ✅ Redis connection
- ✅ MinIO health
- ✅ BullMQ queue system

**Время:** ~5 секунд

---

### `test-api-full.ts`

**Полный тест API endpoints.**

```bash
npx tsx test-api-full.ts
```

**Тестирует:**
- ✅ Root page
- ✅ File upload API
- ✅ Video creation API
- ✅ Video status API

**Время:** ~5 секунд

---

### `test-api.sh`

**Быстрый shell-тест API.**

```bash
./test-api.sh
```

**Тестирует:**
- ✅ Root page (curl)
- ✅ Upload endpoint
- ✅ Videos create endpoint

**Время:** ~3 секунды

---

### `gpu-worker/test_server.py`

**Тест GPU сервера.**

```bash
cd gpu-worker
source venv/bin/activate
python test_server.py
```

**Тестирует:**
- ✅ Health endpoint
- ✅ TTS generation
- ✅ Lip-sync (если есть тестовые файлы)
- ✅ Background generation

**Время:** 30-60 секунд (в зависимости от GPU)

---

## 📋 Сводная таблица

| Скрипт | Платформа | Назначение | Время |
|--------|-----------|------------|-------|
| `quick-start.sh` | Linux/macOS | Универсальная установка | 25-50 мин |
| `install.sh` | Linux/macOS | Main App установка | 10-15 мин |
| `start.sh` | Linux/macOS | Main App запуск | 10 сек |
| `gpu-worker/install.sh` | Linux/macOS | GPU Worker установка | 30-45 мин |
| `gpu-worker/install.bat` | Windows | GPU Worker установка | 30-45 мин |
| `gpu-worker/start.sh` | Linux/macOS | GPU Worker запуск | 5 сек |
| `gpu-worker/start.bat` | Windows | GPU Worker запуск | 5 сек |
| `test-basic.ts` | Any | Тест инфраструктуры | 5 сек |
| `test-api-full.ts` | Any | Тест API | 5 сек |
| `test-api.sh` | Linux/macOS | Быстрый тест API | 3 сек |

---

## 🎯 Рекомендуемый workflow

### Первая установка (стационарный ПК с GPU)

```bash
# 1. Клонировать репозиторий
git clone https://github.com/Ne4to777/avatar-factory.git
cd avatar-factory

# 2. Запустить универсальный установщик
./quick-start.sh
# Выбрать опцию 1 (GPU Worker)

# 3. Дождаться завершения (30-45 минут)
# Скопировать API ключ из вывода

# 4. Запустить сервер
cd gpu-worker
./start.sh
```

### Первая установка (ноутбук)

```bash
# 1. Клонировать репозиторий
git clone https://github.com/Ne4to777/avatar-factory.git
cd avatar-factory

# 2. Запустить универсальный установщик
./quick-start.sh
# Выбрать опцию 2 (Main Application)

# 3. Дождаться завершения (10-15 минут)

# 4. Обновить .env с GPU сервером
nano .env
# GPU_SERVER_URL=http://192.168.1.XXX:8001
# GPU_API_KEY=<ключ-со-стационарного-пк>

# 5. Запустить приложение
./start.sh
# Выбрать режим 2 (Production - UI + Worker)
```

---

## 🔄 Ежедневное использование

### Стационарный ПК

```bash
cd avatar-factory/gpu-worker
./start.sh

# Остановить: Ctrl+C
```

### Ноутбук

```bash
cd avatar-factory
./start.sh

# Выбрать режим (обычно 2)
# Остановить: Ctrl+C
```

---

## 🛠️ Продвинутое использование

### Установка с пропуском скачивания моделей

```bash
cd gpu-worker
SKIP_MODELS=1 ./install.sh

# Скачать модели позже
python download_models.py
```

### Установка в тихом режиме

```bash
# Принять все defaults
yes | ./install.sh
```

### Запуск с конкретным портом

```bash
# GPU Worker
PORT=8002 ./start.sh

# Main App - отредактируйте .env
```

### Параллельный запуск (tmux/screen)

```bash
# Terminal 1
tmux new -s gpu-worker
cd avatar-factory/gpu-worker
./start.sh

# Terminal 2 (detach: Ctrl+B, D)
tmux new -s main-app
cd avatar-factory
./start.sh
```

---

## 🐛 Troubleshooting

### Скрипт не запускается

```bash
# Проверить права
ls -la *.sh

# Сделать исполняемым
chmod +x install.sh start.sh quick-start.sh

# Запустить напрямую через bash
bash install.sh
```

### Python venv не активируется

```bash
# Пересоздать venv
rm -rf venv
python3 -m venv venv
source venv/bin/activate
```

### Docker not running

```bash
# macOS
open -a Docker

# Linux
sudo systemctl start docker

# Проверить статус
docker ps
```

---

## 📝 Логи и отладка

### Где найти логи

```bash
# Main App dev server
tail -f /tmp/avatar-factory-dev.log

# Main App worker
tail -f /tmp/avatar-factory-worker.log

# Docker services
docker-compose logs -f

# GPU server
# Выводится прямо в терминал
```

### Debug mode

```bash
# GPU Worker
DEBUG=1 ./start.sh

# Main App
DEBUG=1 npm run dev
```

---

## 💡 Советы

1. **Используйте `quick-start.sh`** для первой установки - он всё сделает автоматически

2. **Сохраните API ключ** из GPU сервера - он нужен для подключения

3. **Запускайте тесты** после установки:
   ```bash
   npx tsx test-basic.ts
   ```

4. **Проверяйте health endpoints:**
   ```bash
   curl http://localhost:8001/health  # GPU Server
   curl http://localhost:3000/api/health  # Main App
   ```

5. **Используйте screen/tmux** для запуска в фоне на серверах

---

**Документация:** [INSTALL_GUIDE.md](./INSTALL_GUIDE.md) для детальных инструкций

**Support:** GitHub Issues или см. [README.md](./README.md)
