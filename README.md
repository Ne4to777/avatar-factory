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
│  • MuseTalk (real-time lip-sync)    │
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
- **MuseTalk** - Real-time lip-sync анимация (высокая скорость и качество)
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

| Метод | Команда | Когда использовать |
|-------|---------|-------------------|
| **Make** | `make install` | Рекомендуется для разработки ⭐ |
| **npm** | `npm run install:full` | Быстрый старт |
| **Shell Script** | `./install.sh` | Первая установка (интерактивно) |
| **Docker** | `docker-compose up` | Production deployment |

**Документация:** [docs/](./docs/)

### 🎯 Рекомендуемая установка

```bash
# 1. Клонируйте репозиторий
git clone https://github.com/Ne4to777/avatar-factory.git
cd avatar-factory

# 2. Установка через Make (рекомендуется)
make install
make dev      # Terminal 1: UI
make worker   # Terminal 2: Worker

# Или через npm
npm run install:full
npm run start:dev

# Или интерактивно
./install.sh
```

**GPU Worker (стационарный ПК):**

Одна команда на Windows — установка и запуск:
```cmd
cd gpu-worker
install.bat
```
После установки: `start.bat`. Подробности: [gpu-worker/README.md](./gpu-worker/README.md)

**Linux/macOS:** `cd gpu-worker && make install && make install-models && make start`

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
# Запустите инфраструктуру через Docker
docker-compose up -d

# Примените миграции
npm run prisma:migrate
```

**Docker Compose Profiles:**
```bash
# Только инфраструктура (default)
docker-compose up -d

# + Приложение и Worker
docker-compose --profile app up -d

# + GPU Worker (если на той же машине)
docker-compose --profile gpu up -d

# Все вместе
docker-compose --profile full up -d
```

### 4. Настройте GPU Worker (стационарный ПК)

**Windows (одна команда):**
```cmd
cd gpu-worker
install.bat
```
Запустите от имени администратора. После установки: `start.bat`

Полное руководство и ручная установка: [gpu-worker/README.md](./gpu-worker/README.md)

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

## 🧪 Тестирование на ноутбуке (без GPU)

**Можно протестировать систему полностью автоматически с реальными моделями на CPU!**

### CPU Server - облегченная версия

Использует:
- ✅ **Silero TTS** - реальная русская озвучка (работает на CPU!)
- ✅ **FFmpeg lip-sync** - простая анимация без нейросетей
- ⚠️ **Без генерации фона** - используется solid color

### Запуск

```bash
# 1. Установите зависимости
pip install -r cpu-requirements.txt

# 2. Запустите CPU server (вместо GPU worker)
python3 cpu-server.py
# Загрузка Silero TTS занимает ~40 секунд при первом запуске

# 3. В другом терминале - запустите воркер и тест
npm run dev
npm run worker
npm test
```

**Результат:** Полнофункциональное видео с реальным русским TTS создается за ~3 секунды!

## 🎬 Как это работает

1. **Пользователь загружает фото и вводит текст**
2. **Backend добавляет задачу в очередь BullMQ**
3. **Worker обрабатывает задачу:**
   - Генерирует аудио через Silero TTS (локально)
   - Отправляет фото + аудио на GPU сервер
   - GPU сервер создает говорящий аватар (MuseTalk)
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
- MuseTalk: ~10-15 сек на 10-сек видео
- Stable Diffusion XL: ~5-10 сек на изображение
- Silero TTS: ~1-2 сек на предложение
- Композитинг FFmpeg: ~10-20 сек

**Итого:** ~60-90 секунд на видео (15-30 сек)

## 📚 Документация

| Документ | Описание |
|----------|----------|
| **[docs/QUICKSTART.md](./docs/QUICKSTART.md)** | 🚀 Быстрый старт за 15 минут |
| **[docs/INSTALL_GUIDE.md](./docs/INSTALL_GUIDE.md)** | 📦 Полное руководство по установке |
| **[docs/PROJECT_SUMMARY.md](./docs/PROJECT_SUMMARY.md)** | 📊 Обзор проекта и архитектуры |
| **[docs/DEPLOYMENT.md](./docs/DEPLOYMENT.md)** | 🚢 Production deployment |

**[→ Документация](./docs/)**

## 📝 Лицензия

MIT License

## 🤝 Поддержка

- GitHub Issues
- Telegram: @yourusername
