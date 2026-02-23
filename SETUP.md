# Avatar Factory - Setup Guide

## ✅ Что уже работает

### 1. GPU Worker (Windows)
- ✅ MuseTalk (lip-sync) - РАБОТАЕТ
- ✅ Stable Diffusion XL (backgrounds) - РАБОТАЕТ  
- ✅ Silero TTS (text-to-speech) - РАБОТАЕТ
- ✅ GPU: NVIDIA GeForce RTX 4070 Ti (12.68 GB VRAM)
- ✅ Сервер запущен: http://192.168.1.100:8001

### 2. Frontend (Next.js)
- ✅ Красивый UI (app/page.tsx)
- ✅ API Routes (app/api/*)
- ✅ GPU Client (lib/gpu-client.ts)
- ✅ Database (Prisma + PostgreSQL)
- ✅ Job Queue (BullMQ + Redis)
- ✅ Real-time updates (Socket.io)

## 🚀 Запуск приложения

### Шаг 1: GPU Worker (уже запущен)
```bash
# На Windows машине
cd C:\dev\avatar-factory\gpu-worker
venv\Scripts\python.exe server.py
```

Проверка: http://192.168.1.100:8001/health

### Шаг 2: Docker Services (на ноутбуке)
```bash
cd avatar-factory
npm run docker:up
```

Это запустит:
- PostgreSQL (база данных)
- Redis (очереди задач)

### Шаг 3: Database Setup (первый раз)
```bash
npm run prisma:generate
npm run prisma:migrate
```

### Шаг 4: Запуск Next.js + Worker
```bash
npm run start:dev
```

Это запустит:
- Next.js dev server (http://localhost:3000)
- Video worker (обработка видео в фоне)

## 🔧 Конфигурация

Создайте `.env` файл в корне проекта:

```env
# Database
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/avatar-factory"

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379

# GPU Server
GPU_SERVER_URL=http://192.168.1.100:8001
GPU_API_KEY=your-secret-gpu-key-change-this
GPU_TIMEOUT_MS=300000

# Storage (опционально, для S3)
S3_BUCKET=avatar-factory
S3_REGION=us-east-1
S3_ACCESS_KEY=your-access-key
S3_SECRET_KEY=your-secret-key

# App
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

## 📝 Полезные команды

```bash
# Разработка
npm run dev              # Только Next.js
npm run worker           # Только worker
npm run start:dev        # Next.js + worker вместе

# Docker
npm run docker:up        # Запустить services
npm run docker:down      # Остановить services
npm run docker:logs      # Логи services
npm run docker:ps        # Статус services

# Database
npm run prisma:studio    # Открыть Prisma Studio
npm run prisma:migrate   # Запустить миграции
npm run prisma:reset     # Сбросить базу

# Testing
npm run test             # Запустить все тесты
npm run test:api         # Тестировать API
npm run health           # Проверить здоровье

# Production
npm run build            # Собрать для production
npm run start            # Запустить production
```

## 🎨 Использование UI

1. Откройте http://localhost:3000
2. Загрузите фото лица
3. Введите текст для озвучки
4. Выберите стиль фона и формат
5. Нажмите "Создать видео"
6. Ждите 1-3 минуты
7. Скачайте готовое видео!

## 🐛 Troubleshooting

### GPU Server недоступен
```bash
# Проверьте, запущен ли GPU server
curl http://192.168.1.100:8001/health

# На Windows машине перезапустите
cd C:\dev\avatar-factory\gpu-worker
venv\Scripts\python.exe server.py
```

### Database connection failed
```bash
# Проверьте Docker services
npm run docker:ps

# Перезапустите services
npm run docker:down
npm run docker:up
```

### Worker not processing jobs
```bash
# Проверьте Redis
npm run docker:logs

# Перезапустите worker
npm run worker
```

## 📊 Мониторинг

- **Next.js**: http://localhost:3000
- **Prisma Studio**: `npm run prisma:studio`
- **GPU Server**: http://192.168.1.100:8001/health
- **Docker logs**: `npm run docker:logs`

## 🎉 Готово!

Всё настроено и работает. Приложение готово к использованию!
