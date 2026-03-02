# 🎬 Video API Integration Guide

Полное руководство по работе с video generation через Polza.ai API.

---

## 🔧 Настройка

### 1. Получить API ключ

1. Зарегистрироваться на https://polza.ai
2. Перейти в Dashboard → API Keys
3. Создать новый ключ

### 2. Настроить .env

```bash
POLZA_API_KEY=your-polza-api-key-here
```

---

## 📡 Три способа генерации видео

### Вариант 1: Async (рекомендуется для production)

**Запуск генерации:**
```bash
curl -X POST "http://localhost:8001/api/generate-video-api" \
  -H "x-api-key: your-key" \
  -F "prompt=person walking in a park" \
  -F "duration=5" \
  -F "model=veo-fast"
```

**Response:**
```json
{
  "status": "processing",
  "task_id": "task_abc123xyz",
  "estimated_time_seconds": 60,
  "model": "veo-fast",
  "cost_estimate_rub": 45.0,
  "message": "Video generation started. Poll /api/video-status/{task_id}"
}
```

**Проверка статуса (polling):**
```bash
# Проверять каждые 10 секунд
curl http://localhost:8001/api/video-status/task_abc123xyz \
  -H "x-api-key: your-key"
```

**Response (processing):**
```json
{
  "task_id": "task_abc123xyz",
  "status": "processing",
  "progress_percent": 45,
  "estimated_time_remaining": 30
}
```

**Response (completed):**
```json
{
  "task_id": "task_abc123xyz",
  "status": "completed",
  "progress_percent": 100,
  "video_url": "https://storage.polza.ai/videos/abc123.mp4"
}
```

**Скачивание готового видео:**
```bash
curl http://localhost:8001/api/video-download/task_abc123xyz \
  -H "x-api-key: your-key" \
  --output video.mp4
```

**Преимущества:**
- ✅ Не блокирует сервер
- ✅ Можно обрабатывать много видео параллельно
- ✅ Нет timeout проблем
- ✅ Production-ready

---

### Вариант 2: Sync (блокирующий, для простых случаев)

```bash
curl -X POST "http://localhost:8001/api/generate-video-wait" \
  -H "x-api-key: your-key" \
  -F "prompt=person walking in a park" \
  -F "duration=5" \
  -F "model=veo-fast" \
  -F "max_wait_seconds=300" \
  -F "poll_interval=10" \
  --output video.mp4
```

**Что происходит:**
1. Запускает генерацию
2. Автоматически проверяет статус каждые 10 секунд
3. Когда готово → сразу возвращает видео
4. Если timeout (300 сек) → возвращает task_id для ручного polling

**Response (success):**
- HTTP 200 + видео файл

**Response (timeout):**
```json
{
  "error": "timeout",
  "message": "Video generation exceeded 300s",
  "task_id": "task_abc123xyz",
  "last_status": "processing",
  "suggestion": "Use /api/video-status/{task_id} to check status manually"
}
```

**Преимущества:**
- ✅ Простота (один запрос)
- ✅ Подходит для CLI/scripts

**Недостатки:**
- ❌ Блокирует соединение (5 минут)
- ❌ Может упасть по timeout
- ❌ Не масштабируется

---

### Вариант 3: Python client (автоматизация)

```python
import requests
import time

API_KEY = "your-key"
BASE_URL = "http://localhost:8001"

def generate_video(prompt, model="veo-fast", keyframe_path=None):
    """Генерация видео с автоматическим polling"""
    
    # 1. Запуск генерации
    files = {}
    if keyframe_path:
        files["keyframe"] = open(keyframe_path, "rb")
    
    response = requests.post(
        f"{BASE_URL}/api/generate-video-api",
        headers={"x-api-key": API_KEY},
        params={"prompt": prompt, "model": model, "duration": 5},
        files=files
    )
    response.raise_for_status()
    
    task_id = response.json()["task_id"]
    print(f"Task started: {task_id}")
    
    # 2. Polling статуса
    while True:
        time.sleep(10)  # Проверять каждые 10 секунд
        
        status_response = requests.get(
            f"{BASE_URL}/api/video-status/{task_id}",
            headers={"x-api-key": API_KEY}
        )
        status_response.raise_for_status()
        
        status_data = status_response.json()
        current_status = status_data["status"]
        progress = status_data.get("progress_percent", 0)
        
        print(f"Status: {current_status} ({progress}%)")
        
        if current_status == "completed":
            break
        elif current_status == "failed":
            raise Exception(f"Generation failed: {status_data.get('error')}")
        
        # Timeout protection (5 минут)
        if time.time() - start_time > 300:
            print(f"Warning: Timeout, but task still running: {task_id}")
            return task_id  # Можно проверить позже
    
    # 3. Скачивание
    video_response = requests.get(
        f"{BASE_URL}/api/video-download/{task_id}",
        headers={"x-api-key": API_KEY}
    )
    video_response.raise_for_status()
    
    output_path = f"video_{task_id}.mp4"
    with open(output_path, "wb") as f:
        f.write(video_response.content)
    
    print(f"✅ Video saved: {output_path}")
    return output_path

# Использование
video_path = generate_video("person walking in a park", model="veo-fast")
```

---

## 🎯 Модели и цены

| Модель | API ID | Скорость | Качество | Цена | Рекомендация |
|--------|--------|----------|----------|------|--------------|
| **Veo Fast** | `veo-fast` | ~60s | ⭐⭐⭐⭐ | 45₽ | ✅ Оптимально |
| **Veo Quality** | `veo-quality` | ~180s | ⭐⭐⭐⭐⭐ | 187.5₽ | Production |
| **Kling 2.6** | `kling` | ~45s | ⭐⭐⭐ | 22.5₽ | Бюджет |

---

## 🔄 Image-to-Video (keyframe)

Использование референсного изображения для video generation:

```bash
curl -X POST "http://localhost:8001/api/generate-video-api" \
  -H "x-api-key: your-key" \
  -F "prompt=smooth camera movement, cinematic" \
  -F "keyframe=@reference.png" \
  -F "duration=5" \
  -F "model=veo-fast"
```

**Преимущества:**
- ✅ Выше success rate (70-80% vs 50-60%)
- ✅ Больше контроля над результатом
- ✅ Предсказуемая композиция

**Workflow:**
1. Генерируете 4 keyframe локально (SDXL)
2. Выбираете лучший
3. Отправляете на video generation
4. Success rate 70-80%!

---

## ⚠️ Обработка ошибок

### Timeout (408)

```json
{
  "error": "timeout",
  "task_id": "task_abc123",
  "suggestion": "Use /api/video-status/{task_id}"
}
```

**Решение:** Проверить статус вручную через `/api/video-status/{task_id}`

### Video not ready (400)

```json
{
  "detail": "Video not ready yet. Status: processing"
}
```

**Решение:** Подождать и повторить запрос

### Generation failed (500)

```json
{
  "status": "failed",
  "error": "Invalid prompt / Content policy violation"
}
```

**Решение:** Изменить промт, проверить keyframe

---

## 📊 Monitoring

### Health check

```bash
curl http://localhost:8001/health
```

Проверяет:
- ✅ Все модели загружены
- ✅ VRAM usage
- ✅ API connection

### Logs

```bash
# Windows
type logs\server.log | findstr "Video"

# Linux/Mac
tail -f logs/server.log | grep Video
```

**Что смотреть:**
- `Task started: task_xyz` - генерация началась
- `Status: completed` - готово
- `Status: failed` - ошибка
- `Timeout after Xs` - timeout

---

## 💡 Best Practices

### 1. Используйте keyframe preview

**Плохо:**
```bash
# Text-to-video напрямую → 50-60% success rate
curl -X POST /api/generate-video-api \
  -F "prompt=person walking"
```

**Хорошо:**
```bash
# 1. Генерируете 4 keyframe локально (SDXL)
curl -X POST /api/generate-background \
  -F "prompt=person walking in park"

# 2. Выбираете лучший

# 3. Image-to-video → 70-80% success rate
curl -X POST /api/generate-video-api \
  -F "keyframe=@best_keyframe.png" \
  -F "prompt=smooth movement"
```

### 2. Batch generation для снижения брака

```python
# Генерируем 2-3 видео параллельно
task_ids = []
for i in range(3):
    response = requests.post(...)
    task_ids.append(response.json()["task_id"])

# Ждем все
for task_id in task_ids:
    while True:
        status = check_status(task_id)
        if status == "completed":
            download_video(task_id)
            break

# Выбираем лучшее из 3
# Success rate: 95%+
```

### 3. Правильные таймауты

| Модель | Типичное время | Timeout | Poll interval |
|--------|----------------|---------|---------------|
| Kling | 30-60s | 120s | 10s |
| Veo Fast | 45-90s | 180s | 15s |
| Veo Quality | 120-240s | 360s | 30s |

### 4. Retry logic

```python
def generate_with_retry(prompt, max_retries=3):
    for attempt in range(max_retries):
        try:
            return generate_video(prompt)
        except TimeoutError:
            if attempt < max_retries - 1:
                print(f"Retry {attempt + 1}/{max_retries}")
                time.sleep(30)
            else:
                raise
```

---

## 🧪 Testing

### Test basic generation

```bash
# 1. Start generation
TASK_ID=$(curl -X POST "http://localhost:8001/api/generate-video-api" \
  -H "x-api-key: your-key" \
  -F "prompt=test" \
  -F "model=veo-fast" | jq -r '.task_id')

echo "Task ID: $TASK_ID"

# 2. Poll status (every 10s)
while true; do
  STATUS=$(curl -s "http://localhost:8001/api/video-status/$TASK_ID" \
    -H "x-api-key: your-key" | jq -r '.status')
  
  echo "Status: $STATUS"
  
  if [ "$STATUS" = "completed" ]; then
    break
  fi
  
  sleep 10
done

# 3. Download
curl "http://localhost:8001/api/video-download/$TASK_ID" \
  -H "x-api-key: your-key" \
  --output test_video.mp4

echo "✅ Video saved: test_video.mp4"
```

### Test timeout handling

```bash
# Используйте короткий timeout для теста
curl -X POST "http://localhost:8001/api/generate-video-wait" \
  -H "x-api-key: your-key" \
  -F "prompt=test" \
  -F "max_wait_seconds=30" \
  -F "poll_interval=5"

# Ожидаемый результат: timeout через 30s с task_id
```

---

## 🚀 Production Deployment

### Queue system (опционально)

Для production с высокой нагрузкой добавьте:

```python
# Celery task
@celery.task
def generate_video_task(prompt, model, keyframe_path=None):
    response = requests.post(
        f"{API_URL}/api/generate-video-api",
        ...
    )
    task_id = response.json()["task_id"]
    
    # Store task_id in Redis/DB
    redis.set(f"video_job:{job_id}", task_id)
    
    # Background polling
    while True:
        status = check_status(task_id)
        if status == "completed":
            video_path = download_video(task_id)
            # Notify user / save to storage
            break
        time.sleep(15)
```

### Webhook (альтернатива polling)

Если Polza.ai поддерживает webhooks:

```python
@app.post("/webhooks/polza-video")
async def polza_webhook(data: dict):
    task_id = data["task_id"]
    status = data["status"]
    
    if status == "completed":
        # Download and notify user
        await download_and_notify(task_id)
```

---

## 📞 Troubleshooting

### Проблема: "POLZA_API_KEY not configured"

**Решение:**
```bash
# Проверить .env
type .env | findstr POLZA_API_KEY

# Добавить если нет
echo POLZA_API_KEY=your-key >> .env

# Перезапустить сервер
```

### Проблема: Постоянные timeouts

**Причины:**
1. Медленная сеть → увеличьте `max_wait_seconds`
2. Сложный промт → упростите или используйте keyframe
3. API перегружен → используйте batch с задержкой

**Решение:**
```bash
# Увеличить timeout
curl ... -F "max_wait_seconds=600"

# Или использовать async approach
curl -X POST /api/generate-video-api  # Без wait
# Проверять вручную
```

### Проблема: "Generation failed"

**Частые причины:**
- Промт нарушает content policy
- Keyframe некачественный (размытый, артефакты)
- Недостаточно credits в Polza.ai

**Решение:**
1. Проверить balance в Polza.ai dashboard
2. Изменить промт
3. Улучшить keyframe (больше inference steps)

---

**Готово!** Полная интеграция с video API с правильным polling и timeout handling.
