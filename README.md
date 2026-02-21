# Avatar Factory - Open Source Video Generator

Полностью локальная система генерации видео с говорящими аватарами.

## 🎯 Особенности

- ✅ **100% Open Source** - никаких платных API
- ✅ **Полностью локально** - все модели работают на вашем железе
- ✅ **Русский язык** - отличная поддержка через Silero TTS
- ✅ **TypeScript First** - 95% кода на TS/JS
- ✅ **Self-hosted** - полный контроль над данными

## 🏗️ Архитектура

```
┌─────────────────────────────────────┐
│  НОУТБУК (Development & API)        │
│                                     │
│  • Next.js 14 (Frontend + API)     │
│  • PostgreSQL (Database)            │
│  • Redis (Queue)                    │
│  • MinIO (S3-compatible storage)    │
│  • BullMQ (Job queue)               │
└─────────────────────────────────────┘
              ↓ HTTP
┌─────────────────────────────────────┐
│  СТАЦИОНАРНЫЙ ПК (GPU Worker)       │
│     RTX 4070 Ti 12GB                │
│                                     │
│  Open-Source AI Models:             │
│  • SadTalker (lip-sync)             │
│  • Silero TTS (русская озвучка)     │
│  • Stable Diffusion XL (фоны)       │
│  • Real-ESRGAN (upscaling)          │
│  • FFmpeg (обработка видео)         │
└─────────────────────────────────────┘
```

## 🚀 Технологический стек

### Frontend + Backend (TypeScript)
- **Next.js 14** - App Router, Server Actions
- **Prisma** - Type-safe ORM
- **BullMQ** - Очереди задач
- **Socket.io** - Real-time обновления
- **Shadcn/ui** - UI компоненты
- **Tailwind CSS** - Стилизация

### AI Models (Python - минимум)
- **SadTalker** - Анимация лица с lip-sync
- **Silero Models** - Русский TTS (отличное качество)
- **Stable Diffusion XL** - Генерация фонов
- **Real-ESRGAN** - Улучшение качества

### Infrastructure (Self-hosted)
- **PostgreSQL** - Основная БД
- **Redis** - Кэш и очереди
- **MinIO** - S3-compatible хранилище файлов
- **Nginx** - Reverse proxy (опционально)

## 📦 Установка

### ⚡ Выбор метода установки

У нас есть **5 способов** установки на выбор:

| Метод | Команда | Когда использовать |
|-------|---------|-------------------|
| **Make** | `make install` | Ежедневная разработка (рекомендуется ⭐) |
| **npm** | `npm run install:full` | Быстрый старт без доп. инструментов |
| **Shell Script** | `./install.sh` | Первая установка (интерактивно) |
| **Just** | `just install` | Современная альтернатива Make |
| **Docker** | `docker-compose up` | Production deployment |

**Не знаете что выбрать?** → [WHICH_METHOD.md](./docs/WHICH_METHOD.md)  
**Полное сравнение:** → [INSTALLATION_METHODS.md](./docs/INSTALLATION_METHODS.md)

### 🎯 Рекомендуемая установка

```bash
# 1. Клонируйте репозиторий
git clone https://github.com/Ne4to777/avatar-factory.git
cd avatar-factory

# 2a. Установка через Make (рекомендуется)
make install
make dev      # Terminal 1: UI
make worker   # Terminal 2: Worker

# 2b. Или через npm (проще)
npm run install:full
npm run start:dev

# 2c. Или интерактивный shell script
./install.sh
./start.sh
```

**GPU Worker (стационарный ПК):**

```bash
cd gpu-worker

# Windows
install.bat && start.bat

# Linux/macOS
make install && make start
```

### 📖 Детальная установка

### 1. Клонируйте репозиторий
```bash
git clone https://github.com/Ne4to777/avatar-factory.git
cd avatar-factory
```

### 2. Установите зависимости (ноутбук)
```bash
npm install
```

### 3. Настройте базу данных
```bash
# Запустите PostgreSQL, Redis, MinIO через Docker
docker-compose up -d postgres redis minio

# Примените миграции
npm run prisma:migrate
```

### 4. Настройте GPU Worker (стационарный ПК)
```bash
cd gpu-worker
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Установите PyTorch с CUDA
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

# Установите зависимости
pip install -r requirements.txt

# Скачайте модели (единоразово, ~10GB)
python scripts/download_models.py
```

### 5. Запустите приложение

**Терминал 1 (ноутбук - Next.js):**
```bash
npm run dev
# http://localhost:3000
```

**Терминал 2 (ноутбук - Worker):**
```bash
npm run worker
```

**Терминал 3 (стационарный ПК - GPU Server):**
```bash
cd gpu-worker
python server.py
# http://192.168.1.100:8001
```

## 🎬 Как это работает

1. **Пользователь загружает фото и вводит текст**
2. **Backend добавляет задачу в очередь BullMQ**
3. **Worker обрабатывает задачу:**
   - Генерирует аудио через Silero TTS (локально)
   - Отправляет фото + аудио на GPU сервер
   - GPU сервер создает говорящий аватар (SadTalker)
   - Композитинг видео с фоном (FFmpeg)
   - Сохраняет в MinIO
4. **Пользователь получает уведомление через WebSocket**

## 💰 Стоимость

- **Разработка:** $2,500-3,500 (единоразово)
- **Инфраструктура:** $0-10/мес (электричество)
- **API:** $0/мес (всё локально!)

Vs платные решения (D-ID, HeyGen): **$100-500/мес**

## 🔧 Конфигурация

См. `.env.example` для полного списка переменных окружения.

## 📊 Производительность

С RTX 4070 Ti:
- SadTalker: ~30-60 сек на 10-сек видео
- Stable Diffusion XL: ~5-10 сек на изображение
- Silero TTS: ~1-2 сек на предложение
- Композитинг FFmpeg: ~10-20 сек

**Итого:** ~60-90 секунд на видео (15-30 сек)

## 📚 Документация

Вся документация находится в папке [`docs/`](./docs/):

| Документ | Описание |
|----------|----------|
| **[docs/QUICKSTART.md](./docs/QUICKSTART.md)** | 🚀 Быстрый старт за 15 минут |
| **[docs/INSTALL_GUIDE.md](./docs/INSTALL_GUIDE.md)** | 📦 Полное руководство по установке |
| **[docs/WHICH_METHOD.md](./docs/WHICH_METHOD.md)** | 🤔 Какой метод установки выбрать? |
| **[docs/INSTALLATION_METHODS.md](./docs/INSTALLATION_METHODS.md)** | 📊 Сравнение всех методов установки |
| **[docs/BUILD_TOOLS.md](./docs/BUILD_TOOLS.md)** | 🔧 Обзор build инструментов |
| **[docs/SCRIPTS_README.md](./docs/SCRIPTS_README.md)** | 📜 Документация по shell скриптам |
| **[docs/DEPLOYMENT.md](./docs/DEPLOYMENT.md)** | 🚢 Production deployment |
| **[docs/PROJECT_SUMMARY.md](./docs/PROJECT_SUMMARY.md)** | 📊 Обзор проекта и архитектуры |
| **[docs/TEST_RESULTS.md](./docs/TEST_RESULTS.md)** | 🧪 Результаты тестирования |

**[→ Перейти к полной документации](./docs/)**

## 📝 Лицензия

MIT License

## 🤝 Поддержка

- GitHub Issues
- Telegram: @yourusername
