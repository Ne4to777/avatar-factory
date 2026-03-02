# 🚀 Быстрый старт Avatar Factory

Запустите систему генерации видео с аватарами за 15 минут!

## Архитектура

```
НОУТБУК (Dev)         СТАЦИОНАРНЫЙ ПК (GPU)
├─ Next.js            ├─ Python FastAPI
├─ PostgreSQL         ├─ MuseTalk
├─ Redis              ├─ Stable Diffusion XL
├─ S3/MinIO           └─ Silero TTS
└─ Worker             
```

## Шаг 1: Запуск инфраструктуры (ноутбук)

### A. Установите зависимости

```bash
# macOS
brew install node postgresql redis

# Ubuntu
sudo apt install nodejs npm postgresql redis-server

# Windows
# Скачайте Node.js с nodejs.org
# Используйте Docker для PostgreSQL/Redis
```

### B. Клонируйте и установите

```bash
git clone https://github.com/Ne4to777/avatar-factory.git
cd avatar-factory
npm install
```

### C. Запустите инфраструктуру

```bash
# Запустите Docker Compose (PostgreSQL, Redis, MinIO)
docker-compose up -d

# Подождите 10 секунд для инициализации
sleep 10

# Примените миграции БД
npx prisma migrate dev
```

### D. Настройте .env

```bash
cp .env.example .env
```

Отредактируйте `.env`. Используйте S3_* переменные (поддерживаются также MINIO_* для обратной совместимости, S3_* имеет приоритет):

```env
# База данных (уже запущена в Docker)
DATABASE_URL="postgresql://avatar:avatar_password@localhost:5432/avatar_factory"

# Redis (уже запущен в Docker)
REDIS_HOST=localhost
REDIS_PORT=6379

# Storage (S3/MinIO — уже запущен в Docker)
S3_ENDPOINT=localhost
S3_PORT=9000
S3_ACCESS_KEY=minioadmin
S3_SECRET_KEY=minioadmin123
S3_BUCKET=avatar-videos

# GPU Server (укажите IP вашего стационарного ПК)
GPU_SERVER_URL="http://192.168.1.100:8001"
GPU_API_KEY="your-secret-gpu-key-change-this"
```

**Важно:** Узнайте IP вашего стационарного ПК:
```bash
# Windows
ipconfig

# macOS/Linux
ifconfig
```

## Шаг 2: Запуск GPU сервера (стационарный ПК)

### Windows — одна команда

```cmd
cd gpu-worker && install.bat
```

Или по шагам: `cd gpu-worker`, затем `install.bat`.

Запустите **от имени администратора** (ПКМ по `install.bat` → «Запуск от имени администратора»).  
После установки:

```cmd
start.bat
```

### Linux / macOS

```bash
cd gpu-worker && make install && make install-models && make start
```

Или по шагам: `make install` → `make install-models` (~10 GB) → `make start`.

### Проверка

Полное руководство: [gpu-worker/README.md](../gpu-worker/README.md)

Проверьте, что сервер работает:
```bash
curl http://localhost:8001/health
```

Ожидаемый ответ — JSON со статусом GPU и загруженными моделями.

## Шаг 3: Запуск приложения (ноутбук)

Откройте **3 терминала**:

### Терминал 1: Next.js (Frontend + API)
```bash
npm run dev
```

Откройте: http://localhost:3000

### Терминал 2: Worker (обработка видео)
```bash
npm run worker
```

### Терминал 3: Мониторинг (опционально)
```bash
# Логи Docker
docker-compose logs -f

# Или смотрите логи Worker
# Они будут в Терминале 2
```

## Шаг 4: Создайте первое видео!

1. Откройте http://localhost:3000
2. Загрузите фото вашего лица
3. Введите текст для озвучки (например: "Привет! Это моё первое видео с аватаром!")
4. Выберите стиль фона: `simple`, `professional`, `creative` или `minimalist`
5. Нажмите "Создать видео"
6. Подождите 1-3 минуты ⏳
7. Готово! 🎉

## Архитектура работы

```
1. Пользователь → Загружает фото + текст
                ↓
2. Next.js API → Сохраняет в S3/MinIO, создает задачу в Redis
                ↓
3. Worker → Забирает задачу из очереди
                ↓
4. Worker → Отправляет на GPU сервер:
            - Генерирует аудио (Silero TTS)
            - Создает lip-sync видео (MuseTalk)
            - Генерирует фон (Stable Diffusion)
                ↓
5. Worker → Композитинг через FFmpeg
                ↓
6. Worker → Загружает результат в S3/MinIO
                ↓
7. Пользователь ← Получает готовое видео!
```

## Проверка здоровья системы

### Dashboard здоровья
http://localhost:3000/api/health

Должен показать:
```json
{
  "status": "healthy",
  "checks": {
    "database": true,
    "redis": true,
    "gpu": true,
    "storage": true
  }
}
```

### Проверка GPU сервера
```bash
curl http://192.168.1.100:8001/health
```

### Мониторинг очереди
```bash
# Подключитесь к Redis
redis-cli

# Посмотрите задачи
LLEN bull:video-generation:wait
LLEN bull:video-generation:active
```

### Мониторинг GPU
```bash
# На стационарном ПК
nvidia-smi -l 1
```

## Troubleshooting

### ❌ "GPU Server unavailable"

1. Проверьте что GPU сервер запущен:
   ```bash
   curl http://192.168.1.100:8001/health
   ```

2. Проверьте IP в `.env`:
   ```env
   GPU_SERVER_URL="http://192.168.1.100:8001"
   ```

3. Проверьте firewall:
   ```bash
   # Windows
   netsh advfirewall firewall add rule name="Avatar Factory" dir=in action=allow protocol=TCP localport=8001
   
   # Linux
   sudo ufw allow 8001
   ```

### ❌ "Database connection failed"

```bash
# Перезапустите Docker
docker-compose restart postgres

# Проверьте что PostgreSQL работает
docker-compose ps
```

### ❌ "Redis connection failed"

```bash
# Перезапустите Redis
docker-compose restart redis

# Или локально
redis-server
```

### ❌ "Storage (S3/MinIO) not accessible"

```bash
# Откройте MinIO Console
http://localhost:9001

# Login: minioadmin
# Password: minioadmin123

# Проверьте что bucket существует
```

### ❌ Медленная генерация

1. Проверьте GPU нагрузку:
   ```bash
   nvidia-smi
   ```

2. Закройте другие приложения использующие GPU

3. Проверьте температуру GPU (должна быть < 85°C)

### ❌ CUDA out of memory

Уменьшите размер изображений в `gpu-worker/server.py`:
```python
width = 768  # вместо 1080
height = 1024  # вместо 1920
```

## Следующие шаги

### 1. Добавьте аутентификацию

```bash
npm install @clerk/nextjs
# Или
npm install next-auth
```

### 2. Настройте production

```bash
# Build
npm run build

# Deploy на Vercel
vercel

# Или используйте Docker
docker build -t avatar-factory .
```

### 3. Добавьте больше голосов

Отредактируйте `lib/config.ts` — `VOICE_CONFIG.SPEAKER_MAP`:
```typescript
SPEAKER_MAP: {
  'ru_speaker_female': 'xenia',
  'ru_speaker_male': 'eugene',
  'en_speaker_female': 'en_female',
  'en_speaker_male': 'en_male',
  // Добавьте свои голоса Silero
},
```

### 4. Добавьте свои стили фонов

В `lib/config.ts` — `BACKGROUND_STYLE_MAP` и `BACKGROUND_PROMPTS`:
```typescript
BACKGROUND_STYLE_MAP: {
  simple: 'modern-office',
  professional: 'corporate-meeting',
  creative: 'artistic-studio',
  minimalist: 'clean-workspace',
  cyberpunk: 'cyberpunk-style',  // добавьте новый стиль
},
BACKGROUND_PROMPTS: {
  // ...
  'cyberpunk-style': 'cyberpunk city, neon lights, futuristic, 4k',
},
```

## Полезные команды

```bash
# Очистить очередь
redis-cli FLUSHALL

# Очистить временные файлы
rm -rf /tmp/avatar-factory/*

# Пересоздать базу данных
npx prisma migrate reset

# Посмотреть логи Docker
docker-compose logs -f

# Остановить всё
docker-compose down
npm run worker  # Ctrl+C
npm run dev     # Ctrl+C
```

## Стоимость

- **Разработка:** $2,500-3,500
- **Ежемесячно:** $0-10 (электричество)
- **API costs:** $0 (всё локально!)

**vs D-ID/HeyGen:** $100-500/мес 💸

## Поддержка

- 📖 [API Reference](./API.md) | [Полная документация](../README.md)
- 🐛 [GitHub Issues](https://github.com/Ne4to777/avatar-factory/issues)
- 💬 [Telegram](https://t.me/yourusername)
- 📧 Email: your@email.com

## Лицензия

MIT License - используйте свободно!

---

**Готово!** Теперь у вас есть собственная фабрика аватаров 🎭

Создавайте видео и делитесь результатами! 🚀
