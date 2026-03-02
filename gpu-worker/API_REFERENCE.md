# 📚 API Reference - Avatar Factory GPU Server

Полная документация всех endpoints с примерами.

---

## 🔐 Аутентификация

Все endpoints требуют header:
```
x-api-key: your-secret-gpu-key-change-this
```

---

## 📡 Health & Monitoring

### `GET /health`

Статус сервера и загрузка моделей.

**Response:**
```json
{
  "status": "healthy",
  "gpu": {
    "name": "NVIDIA GeForce RTX 4070 Ti",
    "vram_total_gb": 12.0,
    "vram_used_gb": 8.5,
    "vram_free_gb": 3.5,
    "utilization_percent": 70.8
  },
  "models": {
    "musetalk": true,
    "stable_diffusion": true,
    "silero_tts": true,
    "whisper_stt": true,
    "text_llm": true
  }
}
```

---

## 🎙️ Speech-to-Text

### `POST /api/stt`

Распознавание речи из аудио файла.

**Parameters:**
- `audio` (file, required): Аудио файл (wav, mp3, m4a, flac, ogg)
- `language` (query, optional): Язык (`ru`, `en`, `auto`). Default: `ru`
- `model_size` (query, optional): Размер модели. Default: `large-v3`

**Example:**
```bash
curl -X POST http://localhost:8001/api/stt \
  -H "x-api-key: your-key" \
  -F "audio=@recording.wav" \
  -F "language=ru"
```

**Response:**
```json
{
  "text": "Привет, это тестовая запись для распознавания речи",
  "language": "ru",
  "segments": [
    {
      "start": 0.0,
      "end": 2.5,
      "text": "Привет, это тестовая запись"
    },
    {
      "start": 2.5,
      "end": 5.0,
      "text": "для распознавания речи"
    }
  ]
}
```

**Performance:**
- Large-v3: ~1x realtime (5 min audio = 5 min processing)
- VRAM: ~3-4GB
- Accuracy: 95%+ для русского языка

---

## ✍️ Text Improvement

### `POST /api/improve-text`

Улучшение текста с помощью LLM (Mistral 7B).

**Parameters:**
- `text` (query, required): Текст для улучшения
- `style` (query, optional): Стиль (`professional`, `casual`, `technical`, `creative`). Default: `professional`
- `max_tokens` (query, optional): Максимум токенов в ответе. Default: 512

**Example:**
```bash
curl -X POST "http://localhost:8001/api/improve-text" \
  -H "x-api-key: your-key" \
  -G \
  --data-urlencode "text=Короче надо сделать штуку которая работает" \
  --data-urlencode "style=professional"
```

**Response:**
```json
{
  "original_text": "Короче надо сделать штуку которая работает",
  "improved_text": "Необходимо разработать функциональное решение, отвечающее требованиям проекта",
  "style": "professional",
  "original_length": 44,
  "improved_length": 82
}
```

**Performance:**
- Speed: 8-15 tok/s на RTX 4070 Ti
- VRAM: ~7GB
- Quality: ⭐⭐⭐⭐ (хорошо для большинства задач)

---

## 🎨 Image Generation

### `POST /api/generate-background`

Генерация изображений (Stable Diffusion XL).

**Parameters:**
- `prompt` (query, required): Текстовое описание
- `negative_prompt` (query, optional): Что не включать. Default: "blurry, low quality"
- `width` (query, optional): Ширина. Default: 1080
- `height` (query, optional): Высота. Default: 1920

**Example:**
```bash
curl -X POST "http://localhost:8001/api/generate-background" \
  -H "x-api-key: your-key" \
  -G \
  --data-urlencode "prompt=modern office with plants" \
  --data-urlencode "width=1024" \
  --data-urlencode "height=1024" \
  --output background.png
```

**Performance:**
- Speed: ~20-30 секунд на 1024x1024
- VRAM: ~8GB
- Quality: ⭐⭐⭐⭐

---

## 🎤 Text-to-Speech

### `POST /api/tts`

Синтез речи (Silero TTS, русский).

**Parameters:**
- `text` (query, required): Текст для озвучивания
- `speaker` (query, optional): Голос (`xenia`, `aidar`, `baya`). Default: `xenia`

**Example:**
```bash
curl -X POST "http://localhost:8001/api/tts" \
  -H "x-api-key: your-key" \
  -G \
  --data-urlencode "text=Привет, это тестовое аудио" \
  --data-urlencode "speaker=xenia" \
  --output speech.wav
```

**Performance:**
- Speed: Real-time (1 sec audio = 1 sec processing)
- VRAM: ~1GB
- Quality: ⭐⭐⭐⭐ (отличное качество для русского)

---

## 💬 Lip-Sync Video

### `POST /api/lipsync`

Создание говорящего аватара (MuseTalk).

**Parameters:**
- `image` (file, required): Фото человека
- `audio` (file, required): Аудио файл
- `bbox_shift` (query, optional): Смещение bbox. Default: 0
- `batch_size` (query, optional): Размер батча. Default: 8
- `fps` (query, optional): FPS видео. Default: 25

**Example:**
```bash
curl -X POST http://localhost:8001/api/lipsync \
  -H "x-api-key: your-key" \
  -F "image=@avatar.png" \
  -F "audio=@speech.wav" \
  -F "fps=25" \
  --output lipsync_video.mp4
```

**Performance:**
- Speed: ~1-2x realtime
- VRAM: ~6GB
- Quality: ⭐⭐⭐⭐⭐ (реалистичная синхронизация губ)

---

## 💰 Cost Estimation

### `POST /api/estimate-cost`

Оценка стоимости выполнения пайплайна.

**Body (JSON):**
```json
{
  "steps": ["stt", "improve_text", "generate_images", "generate_video"],
  "audio_duration_minutes": 5,
  "num_images": 4,
  "video_duration_seconds": 300,
  "use_local": ["stt", "improve_text", "generate_images"],
  "use_api": ["generate_video"]
}
```

**Example:**
```bash
curl -X POST http://localhost:8001/api/estimate-cost \
  -H "x-api-key: your-key" \
  -H "Content-Type: application/json" \
  -d '{
    "steps": ["stt", "improve_text", "generate_images", "generate_video"],
    "audio_duration_minutes": 5,
    "num_images": 4,
    "video_duration_seconds": 300,
    "use_local": ["stt", "improve_text", "generate_images"],
    "use_api": ["generate_video"]
  }'
```

**Response:**
```json
{
  "total_cost_rub": 45.0,
  "total_cost_usd": 0.5,
  "breakdown": [
    {"step": "stt", "provider": "local", "cost": 0},
    {"step": "improve_text", "provider": "local", "cost": 0},
    {"step": "generate_images", "provider": "local", "cost": 0},
    {"step": "generate_video", "provider": "api", "cost": 45.0}
  ],
  "recommendations": [
    "Используйте локально: STT, Text, Images (экономия ~200₽)",
    "Используйте API: только Video (оптимальное качество)"
  ]
}
```

---

## 🎬 Video Generation (API)

### `POST /api/generate-video-api`

Генерация видео через Polza.ai API.

**Parameters:**
- `prompt` (query, required): Описание видео
- `keyframe` (file, optional): Референсное изображение (image-to-video)
- `duration` (query, optional): Длительность (5-10 сек). Default: 5
- `model` (query, optional): Модель (`veo-fast`, `veo-quality`, `kling`). Default: `veo-fast`

**Models:**
- `veo-fast`: Google Veo 3.1 Fast (45₽, быстро, качество ⭐⭐⭐⭐)
- `veo-quality`: Google Veo 3.1 Quality (187.5₽, медленно, качество ⭐⭐⭐⭐⭐)
- `kling`: Kling 2.6 (22.5₽, бюджет, качество ⭐⭐⭐)

**Example:**
```bash
curl -X POST "http://localhost:8001/api/generate-video-api" \
  -H "x-api-key: your-key" \
  -F "prompt=person walking in a park" \
  -F "keyframe=@reference.png" \
  -F "duration=5" \
  -F "model=veo-fast"
```

**Response:**
```json
{
  "status": "processing",
  "task_id": "task_abc123",
  "estimated_time_seconds": 60,
  "model": "veo-fast",
  "cost_estimate_rub": 45.0,
  "message": "Video generation started. Poll /api/video-status/{task_id}"
}
```

**⚠️ Требует:** `POLZA_API_KEY` в `.env`

---

## 🔄 Video Status Polling

### `GET /api/video-status/{task_id}`

Проверка статуса генерации видео (для async workflow).

**Parameters:**
- `task_id` (path, required): ID задачи из `/api/generate-video-api`

**Example:**
```bash
curl http://localhost:8001/api/video-status/task_abc123 \
  -H "x-api-key: your-key"
```

**Response (processing):**
```json
{
  "task_id": "task_abc123",
  "status": "processing",
  "progress_percent": 45,
  "estimated_time_remaining": 30
}
```

**Response (completed):**
```json
{
  "task_id": "task_abc123",
  "status": "completed",
  "progress_percent": 100,
  "video_url": "https://storage.polza.ai/videos/abc123.mp4"
}
```

**Response (failed):**
```json
{
  "task_id": "task_abc123",
  "status": "failed",
  "error": "Content policy violation / Invalid prompt"
}
```

**Statuses:**
- `processing` - В процессе генерации
- `completed` - Готово, можно скачать
- `failed` - Ошибка генерации

**Recommended polling interval:** 10-15 секунд

---

## 📥 Video Download

### `GET /api/video-download/{task_id}`

Скачивание готового видео.

**Prerequisites:** Status должен быть `completed`

**Example:**
```bash
curl http://localhost:8001/api/video-download/task_abc123 \
  -H "x-api-key: your-key" \
  --output video.mp4
```

**Response:** Видео файл (MP4)

**Errors:**
- `400` - Video not ready (status != completed)
- `404` - Task not found
- `500` - Download failed

---

## ⏳ Video Generation with Wait

### `POST /api/generate-video-wait`

Генерация видео с автоматическим polling (блокирующий endpoint).

**Parameters:**
- `prompt` (query, required): Описание видео
- `keyframe` (file, optional): Референсное изображение
- `duration` (query, optional): Длительность (5-10 сек). Default: 5
- `model` (query, optional): Модель. Default: `veo-fast`
- `max_wait_seconds` (query, optional): Максимум ожидания. Default: 300
- `poll_interval` (query, optional): Интервал проверки. Default: 10

**Example:**
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

**Response (success):** Видео файл сразу после готовности

**Response (timeout):**
```json
{
  "error": "timeout",
  "message": "Video generation exceeded 300s",
  "task_id": "task_abc123",
  "last_status": "processing",
  "suggestion": "Use /api/video-status/{task_id} to check manually"
}
```

**Use cases:**
- ✅ CLI scripts и автоматизация
- ✅ Простые одноразовые генерации
- ❌ Production с высокой нагрузкой (используйте async)

**Недостатки:**
- Блокирует HTTP соединение на 5+ минут
- Может упасть по timeout
- Не масштабируется

---

## 🔄 Hybrid Pipeline

### `POST /api/pipeline`

Полный гибридный пайплайн (локально + API).

**Этапы:**
1. STT (локально, Whisper)
2. Text improvement (локально, Mistral)
3. Image generation (локально, SDXL) - batch 4x
4. Video generation (API, Veo)

**Parameters:**
- `audio` (file, optional): Аудио для STT
- `text` (query, optional): Текст (если нет audio)
- `num_images` (query, optional): Количество изображений. Default: 4
- `generate_video` (query, optional): Генерировать видео. Default: true
- `style` (query, optional): Стиль текста. Default: `professional`
- `use_api_for_video` (query, optional): Использовать API для видео. Default: true

**Example:**
```bash
curl -X POST http://localhost:8001/api/pipeline \
  -H "x-api-key: your-key" \
  -F "audio=@recording.wav" \
  -F "num_images=4" \
  -F "style=professional" \
  -F "generate_video=true"
```

**Response:**
```json
{
  "steps_completed": [
    "stt_local",
    "text_improvement_local",
    "image_generation_local",
    "video_generation_api"
  ],
  "total_cost_rub": 45.0,
  "outputs": {
    "original_text": "короче надо сделать...",
    "improved_text": "Необходимо разработать...",
    "images": ["img1.png", "img2.png", "img3.png", "img4.png"],
    "video_task_id": "task_xyz789",
    "video_cost_rub": 45.0
  },
  "message": "Pipeline completed successfully",
  "recommendations": [
    "Review generated images and select best keyframe",
    "Consider batch video generation for better success rate"
  ]
}
```

**Преимущества:**
- ✅ Минимальная стоимость (~45₽ на 30 видео/месяц)
- ✅ Локально: STT, Text, Images (бесплатно)
- ✅ API: только Video (высокое качество)
- ✅ Batch generation снижает брак

---

## 🧹 Cleanup

### `POST /api/cleanup`

Очистка временных файлов.

**Example:**
```bash
curl -X POST http://localhost:8001/api/cleanup \
  -H "x-api-key: your-key"
```

**Response:**
```json
{
  "status": "ok",
  "message": "Temp files cleaned"
}
```

---

## 📊 Сравнение стоимости (30 видео/месяц)

| Подход | STT | Text | Image | Video | Итого |
|--------|-----|------|-------|-------|-------|
| **100% API** | 76₽ | 69₽ | 600₽ | 1350₽ | **2095₽** |
| **100% Local** | 0₽ | 0₽ | 0₽ | ❌ Не поддерживается | — |
| **Hybrid (рекомендуется)** | 0₽ | 0₽ | 0₽ | 1350₽ | **1350₽** ⭐ |

**Экономия:** 745₽/месяц (~35%)

---

## 🚨 Error Handling

Все endpoints возвращают ошибки в формате:

```json
{
  "detail": "Error message"
}
```

**Status codes:**
- `200` - Success
- `400` - Bad Request (неверные параметры)
- `403` - Forbidden (неверный API key)
- `500` - Internal Server Error
- `503` - Service Unavailable (модель не загружена)

---

## 🔧 Configuration

### Environment Variables (`.env`)

```bash
# Обязательные
GPU_API_KEY=your-secret-key

# Опциональные (для video API)
POLZA_API_KEY=your-polza-key

# Server config
HOST=0.0.0.0
PORT=8001
```

### Model Loading

Модели загружаются автоматически при старте сервера.
Первый запуск может занять 20-30 минут (загрузка моделей из HuggingFace).

**Размеры моделей:**
- Whisper Large V3: ~3GB
- Mistral 7B: ~14GB
- SDXL: ~7GB
- MuseTalk: ~5GB
- Silero TTS: ~50MB

**Итого:** ~30GB (кеш HuggingFace)

---

## 📖 Interactive Docs

Swagger UI доступен по адресу:
```
http://localhost:8001/docs
```

Здесь можно протестировать все endpoints в браузере.

---

## 💡 Best Practices

1. **Используйте batch generation** для images (4-8 вариантов)
2. **Keyframe preview** перед дорогой video generation
3. **Локально** для STT, Text, Images (экономия)
4. **API** только для Video (качество)
5. **Мониторьте VRAM** через `/health`
6. **Очищайте temp files** регулярно `/api/cleanup`

---

**Документация актуальна для версии:** 2.0.0 (с поддержкой Whisper, Mistral, Video API)
