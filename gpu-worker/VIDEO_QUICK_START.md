# 🎬 Video API - Quick Start

Исправлена проблема с timeout! Теперь два способа работы с video API.

---

## ❌ Проблема (было):

```bash
# Timeout после 5 минут
curl -X POST /api/generate-video-api ...
# → HTTP 408 Timeout
```

---

## ✅ Решение 1: Async Polling (рекомендуется)

### Шаг 1: Запустить генерацию

```bash
curl -X POST "http://localhost:8001/api/generate-video-api" \
  -H "x-api-key: your-key" \
  -F "prompt=person walking in a park" \
  -F "model=veo-fast"
```

**Response:**
```json
{
  "status": "processing",
  "task_id": "task_abc123",
  "estimated_time_seconds": 60
}
```

### Шаг 2: Проверять статус (каждые 10-15 сек)

```bash
curl "http://localhost:8001/api/video-status/task_abc123" \
  -H "x-api-key: your-key"
```

**Response:**
```json
{
  "status": "processing",  // или "completed" или "failed"
  "progress_percent": 45
}
```

### Шаг 3: Скачать когда готово

```bash
curl "http://localhost:8001/api/video-download/task_abc123" \
  -H "x-api-key: your-key" \
  --output video.mp4
```

**✅ Преимущества:**
- Не блокирует соединение
- Нет timeout проблем
- Production-ready
- Можно обрабатывать много видео параллельно

---

## ✅ Решение 2: Auto-polling (простой)

```bash
curl -X POST "http://localhost:8001/api/generate-video-wait" \
  -H "x-api-key: your-key" \
  -F "prompt=person walking in a park" \
  -F "model=veo-fast" \
  -F "max_wait_seconds=300" \
  -F "poll_interval=10" \
  --output video.mp4
```

**Что делает:**
1. Запускает генерацию
2. Автоматически проверяет статус каждые 10 сек
3. Возвращает видео когда готово

**Если timeout:**
```json
{
  "error": "timeout",
  "task_id": "task_abc123",
  "suggestion": "Use /api/video-status/{task_id}"
}
```

**✅ Преимущества:**
- Одна команда
- Автоматический polling
- Подходит для scripts

**⚠️ Ограничения:**
- Блокирует HTTP на 5+ минут
- Может timeout (но возвращает task_id)

---

## 🐍 Python Example

```python
import requests
import time

API_KEY = "your-key"
BASE_URL = "http://localhost:8001"

def generate_video(prompt, model="veo-fast"):
    # 1. Старт генерации
    response = requests.post(
        f"{BASE_URL}/api/generate-video-api",
        headers={"x-api-key": API_KEY},
        params={"prompt": prompt, "model": model, "duration": 5}
    )
    task_id = response.json()["task_id"]
    print(f"✅ Task started: {task_id}")
    
    # 2. Polling
    while True:
        time.sleep(10)  # Проверка каждые 10 сек
        
        status_response = requests.get(
            f"{BASE_URL}/api/video-status/{task_id}",
            headers={"x-api-key": API_KEY}
        )
        status = status_response.json()
        
        print(f"Status: {status['status']} ({status.get('progress_percent', 0)}%)")
        
        if status["status"] == "completed":
            break
        elif status["status"] == "failed":
            raise Exception(f"Generation failed: {status.get('error')}")
    
    # 3. Download
    video_response = requests.get(
        f"{BASE_URL}/api/video-download/{task_id}",
        headers={"x-api-key": API_KEY}
    )
    
    with open(f"video_{task_id}.mp4", "wb") as f:
        f.write(video_response.content)
    
    print(f"✅ Video saved: video_{task_id}.mp4")

# Использование
generate_video("person walking in a park", model="veo-fast")
```

---

## 📊 Что изменилось

| Было | Стало |
|------|-------|
| ❌ Один endpoint с timeout | ✅ Три endpoint'а (start, status, download) |
| ❌ Timeout через 5 минут | ✅ Нет timeout при polling |
| ❌ Потеря task_id при timeout | ✅ Всегда возвращается task_id |
| ❌ Невозможность проверить статус | ✅ `/video-status/{task_id}` |
| ❌ Блокирующий запрос | ✅ Async workflow |

---

## 🎯 Рекомендации

### Production:
```
✅ Используйте Async (3 endpoint'а)
✅ Polling interval: 10-15 сек
✅ Max wait: 300-600 сек
```

### Development/Testing:
```
✅ Используйте Auto-polling (1 endpoint)
✅ Max wait: 120-180 сек
```

### CLI/Scripts:
```
✅ Используйте Auto-polling с fallback на manual check
```

---

## 🔧 Настройка

### .env
```bash
POLZA_API_KEY=your-polza-key
```

### Получить ключ
https://polza.ai/dashboard/api-keys

---

## 📚 Полная документация

- **VIDEO_API_GUIDE.md** - Детальное руководство
- **API_REFERENCE.md** - Все endpoints с примерами
- `http://localhost:8001/docs` - Swagger UI

---

**✅ Проблема с timeout исправлена!**

Git commit: `632646e`
