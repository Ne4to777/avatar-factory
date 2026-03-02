# Avatar Factory - Startup Guide

Сводная таблица команд для запуска приложения на двух машинах.

---

## Архитектура

```
┌─────────────────────────────────┐       ┌─────────────────────────────────┐
│   MacBook (Ноутбук)             │       │   Windows PC (Стационарный)     │
│                                 │       │                                 │
│  • Next.js Frontend             │       │  • GPU Worker (FastAPI)         │
│  • API Routes                   │ HTTP  │  • SadTalker (Lip Sync)        │
│  • PostgreSQL                   │<─────>│  • Silero TTS                  │
│  • Redis                        │       │  • Stable Diffusion            │
│  • MinIO                        │       │  • NVIDIA GPU (CUDA)           │
│  • Video Worker (coordinator)   │       │                                │
└─────────────────────────────────┘       └─────────────────────────────────┘
```

---

## Сводная таблица команд

| Действие | MacBook (Ноутбук) | Windows PC (GPU) |
|----------|-------------------|------------------|
| **Первый запуск** | `make install` | `cd gpu-worker && python setup.py` |
| **Запуск инфраструктуры** | `make setup-docker` | Не требуется |
| **Применить миграции** | `make setup-db` | Не требуется |
| **Запуск приложения** | `make dev` (Terminal 1)<br>`make worker` (Terminal 2) | `python server.py` или<br>`uvicorn server:app --host 0.0.0.0 --port 8001` |
| **Проверка здоровья** | `make health` или<br>`curl localhost:3000/api/health` | `curl http://localhost:8001/health` |
| **Остановка** | `make stop` | `Ctrl+C` |
| **Тесты** | `make test-unit` (172 теста)<br>`make test-integration` (5 тестов) | `pytest test_temp_file_cleanup.py` |
| **Логи** | `make logs` | `tail -f logs/server.log` |
| **Очистка** | `make clean` | Не требуется |

---

## Детальные инструкции

### MacBook (Ноутбук) - Полная инструкция

#### Первый раз (setup):

```bash
# 1. Clone проекта (если ещё не сделал)
cd ~/projects
git clone https://github.com/Ne4to777/avatar-factory.git
cd avatar-factory

# 2. Pull последние изменения
git pull origin main

# 3. Установка (автоматически: npm install + docker + migrations)
make install

# Если Docker не запущен, сначала:
# - Запусти Docker Desktop через GUI
# - Затем: make install
```

#### Каждый день (запуск):

```bash
cd ~/projects/avatar-factory

# 1. Убедись что Docker Desktop запущен (иконка в меню)

# 2. Запусти инфраструктуру (если контейнеры не работают)
docker-compose up -d
# Или: make setup-docker

# 3. Запусти приложение в двух терминалах:

# Terminal 1: Next.js
make dev

# Terminal 2: Worker
make worker
```

#### Проверка:

```bash
# Health check
make health

# Открыть в браузере
open http://localhost:3000

# Статус сервисов
make status
```

#### Остановка:

```bash
# Остановить приложение
Ctrl+C в обоих терминалах

# Остановить Docker контейнеры
make stop
# Или: docker-compose down
```

---

### Windows PC (Стационарный) - GPU Worker

#### Первый раз (setup):

**Автоматическая установка (рекомендуется):**

```powershell
# 1. Clone проекта
cd C:\Projects
git clone https://github.com/Ne4to777/avatar-factory.git
cd avatar-factory\gpu-worker

# 2. Pull последние изменения
git pull origin main

# 3. Запустить автоматическую установку
# Для PowerShell:
.\install_windows.ps1

# Или для CMD:
install_windows.bat

# Скрипт автоматически:
# - Создаст venv
# - Установит PyTorch 2.1.0 + CUDA 11.8
# - Установит mmcv через mim (правильная версия)
# - Установит все остальные зависимости
# - Проверит установку

# 4. Первый запуск (скачает модели ~5GB)
python server.py
```

**Ручная установка (если автоматическая не работает):**

```powershell
# 1. Создать venv
python -m venv venv
venv\Scripts\activate

# 2. Обновить базовые инструменты
pip install --upgrade pip setuptools wheel

# 3. Установить PyTorch СНАЧАЛА
pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu118

# 4. Установить OpenMMLab пакеты через mim
pip install -U openmim
mim install mmcv==2.1.0
pip install mmdet mmpose

# 5. Установить остальные зависимости
pip install -r requirements.txt

# 6. Первый запуск
python server.py
```

#### Каждый день (запуск):

```powershell
cd C:\Projects\avatar-factory\gpu-worker

# Активировать venv
venv\Scripts\activate

# Запустить GPU Worker
python server.py

# Или с uvicorn
uvicorn server:app --host 0.0.0.0 --port 8001
```

#### Проверка:

```powershell
# Health check
curl http://localhost:8001/health

# Или в браузере
start http://localhost:8001/health
```

#### Остановка:

```powershell
# Остановить сервер
Ctrl+C
```

---

## Быстрая справка

### MacBook - Ежедневный запуск (3 команды)

```bash
cd ~/projects/avatar-factory
docker-compose up -d    # Запустить инфраструктуру
make dev               # Terminal 1
make worker            # Terminal 2
```

### Windows PC - Ежедневный запуск (2 команды)

```powershell
cd C:\Projects\avatar-factory\gpu-worker
venv\Scripts\activate
python server.py
```

---

## Порядок запуска

1. **Сначала:** Windows PC (GPU Worker)
2. **Потом:** MacBook (приложение)

**Почему:** Worker на MacBook делает HTTP запросы к GPU Worker, поэтому GPU должен быть запущен первым.

---

## URLs

### MacBook:
- Frontend: http://localhost:3000
- API: http://localhost:3000/api/health
- MinIO: http://localhost:9001
- Adminer: http://localhost:8080

### Windows PC:
- GPU Worker: http://192.168.0.128:8001 (твой IP)
- Health: http://192.168.0.128:8001/health

---

## Переменные окружения

### MacBook `.env`:

```bash
DATABASE_URL="postgresql://avatar:avatar_password@localhost:5432/avatar_factory"
REDIS_HOST=localhost
S3_ENDPOINT=localhost
GPU_SERVER_URL=http://192.168.0.128:8001  # IP Windows PC
GPU_API_KEY=your-secret-key
```

### Windows PC `gpu-worker/.env`:

```bash
API_KEY=your-secret-key
PORT=8001
HOST=0.0.0.0
```

---

## Troubleshooting

| Проблема | MacBook | Windows PC |
|----------|---------|------------|
| Docker not running | Запусти Docker Desktop (GUI) | Не требуется |
| Port 3000 занят | `lsof -ti:3000 \| xargs kill` | Не применимо |
| Port 8001 занят | Не применимо | `netstat -ano \| findstr :8001`<br>Останови процесс |
| PostgreSQL не стартует | `make logs-postgres` | Не применимо |
| GPU Worker недоступен | Проверь `GPU_SERVER_URL` в `.env` | Проверь firewall |
| Нет CUDA | Не применимо | Установи CUDA Toolkit 11.8+ |
| mmcv build error | Не применимо | Используй `install_windows.ps1` или<br>`mim install mmcv==2.1.0` |
| ModuleNotFoundError: pkg_resources | Не применимо | `pip install --upgrade setuptools` |

---

## Проверка связи

### С MacBook проверь GPU Worker:

```bash
curl http://192.168.0.128:8001/health
```

**Ожидается:**
```json
{
  "status": "healthy",
  "gpu_available": true,
  "models_loaded": {
    "tts": true,
    "lipsync": true,
    "background": true
  }
}
```

Если `gpu_available: false` - проблема с CUDA на Windows.

---

## Итого

**MacBook запускает:** Всё кроме GPU обработки  
**Windows PC запускает:** Только GPU Worker

**Вместе они образуют полное приложение!** 🚀
