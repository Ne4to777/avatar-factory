# API Testing Guide

Руководство по тестированию API эндпоинтов GPU Worker.

## Перед тестированием

1. Убедитесь что сервер запущен:
   ```cmd
   start.bat
   ```

2. Проверьте что сервер отвечает:
   ```bash
   curl http://localhost:8001/health
   ```

3. Получите ваш API ключ из `.env` файла:
   ```cmd
   type .env
   ```
   Скопируйте значение `GPU_API_KEY`.

## 1. Health Check

Проверка статуса GPU и загруженных моделей:

```bash
curl http://localhost:8001/health
```

Ожидаемый ответ:
```json
{
  "status": "healthy",
  "gpu": {
    "name": "NVIDIA GeForce RTX 4070 Ti",
    "vram_total_gb": 12.88,
    "vram_used_gb": 8.7,
    "vram_free_gb": 4.18,
    "utilization_percent": 67.5
  },
  "models": {
    "musetalk": true,
    "stable_diffusion": true,
    "silero_tts": true
  }
}
```

**Важно:** Если `musetalk: false`, запустите:
```powershell
powershell -ExecutionPolicy Bypass -File install-musetalk.ps1
```

## 2. Text-to-Speech (TTS)

Генерация русской речи из текста:

```bash
curl -X POST http://localhost:8001/api/tts \
  -H "x-api-key: YOUR_API_KEY_HERE" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "text=Привет! Это тестовое сообщение." \
  -d "speaker=xenia" \
  --output test_tts.wav
```

**Доступные голоса:**
- `xenia` - женский голос
- `aidar` - мужской голос
- `baya` - женский голос
- `eugene` - мужской голос

**Проверка:**
```cmd
test_tts.wav
```
Должен воспроизвестись WAV файл с русской речью.

## 3. Lip-Sync Video Generation (MuseTalk)

Создание говорящего аватара с синхронизацией губ:

### Подготовка тестовых файлов

1. **Изображение лица** (`test_face.jpg` или `.png`)
   - Фото с четко видимым лицом
   - Рекомендуется: фронтальная камера, хорошее освещение
   - Разрешение: от 512x512 до 2048x2048

2. **Аудио** (`test_audio.wav` или `.mp3`)
   - Можно использовать аудио из предыдущего теста TTS
   - Или записать свой голос / использовать готовый файл

### Запрос

```bash
curl -X POST http://localhost:8001/api/lipsync \
  -H "x-api-key: YOUR_API_KEY_HERE" \
  -F "image=@test_face.jpg" \
  -F "audio=@test_audio.wav" \
  -F "bbox_shift=0" \
  -F "batch_size=8" \
  -F "fps=25" \
  --output test_lipsync.mp4
```

**Параметры:**
- `bbox_shift` (int, 0-10): сдвиг области лица, используется для подгонки
- `batch_size` (int, 4-16): размер батча для inference, больше = быстрее но больше VRAM
- `fps` (int, 15-30): FPS выходного видео

**Проверка:**
```cmd
test_lipsync.mp4
```
Должно воспроизвестись видео где лицо говорит в синхронизацию с аудио.

**Время генерации (RTX 4070 Ti):**
- 10 сек видео: ~10-15 сек
- 30 сек видео: ~30-45 сек

## 4. Background Generation (Stable Diffusion XL)

Генерация фоновых изображений:

```bash
curl -X POST http://localhost:8001/api/generate-background \
  -H "x-api-key: YOUR_API_KEY_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Professional office with modern furniture, natural lighting, 8k, photorealistic",
    "negative_prompt": "blurry, low quality, distorted, ugly",
    "width": 1024,
    "height": 1024,
    "num_inference_steps": 30,
    "guidance_scale": 7.5
  }' \
  --output test_background.png
```

**Параметры:**
- `prompt` (str): описание желаемого изображения (английский)
- `negative_prompt` (str): что НЕ должно быть на изображении
- `width/height` (int, 512-2048): разрешение (кратно 64)
- `num_inference_steps` (int, 20-50): количество шагов диффузии (больше = качественнее но медленнее)
- `guidance_scale` (float, 5-15): насколько строго следовать промпту

**Проверка:**
```cmd
test_background.png
```
Должно открыться сгенерированное изображение.

**Время генерации (RTX 4070 Ti):**
- 1024x1024, 30 steps: ~5-10 сек

## 5. Cleanup

Очистка временных файлов:

```bash
curl -X POST http://localhost:8001/api/cleanup \
  -H "x-api-key: YOUR_API_KEY_HERE"
```

Ожидаемый ответ:
```json
{
  "status": "ok",
  "message": "Temporary files cleaned",
  "files_removed": 42,
  "space_freed_mb": 128.5
}
```

## Полный Workflow Test

Тест полного рабочего процесса генерации аватара:

```bash
# 1. Генерируем речь
curl -X POST http://localhost:8001/api/tts \
  -H "x-api-key: YOUR_API_KEY" \
  -d "text=Привет! Меня зовут Алиса. Я ваш виртуальный помощник." \
  -d "speaker=xenia" \
  --output speech.wav

# 2. Генерируем фон
curl -X POST http://localhost:8001/api/generate-background \
  -H "x-api-key: YOUR_API_KEY" \
  -d '{"prompt":"Modern office background, professional, clean"}' \
  --output background.png

# 3. Создаём говорящий аватар
curl -X POST http://localhost:8001/api/lipsync \
  -H "x-api-key: YOUR_API_KEY" \
  -F "image=@avatar_face.jpg" \
  -F "audio=@speech.wav" \
  --output final_video.mp4

# 4. Очистка
curl -X POST http://localhost:8001/api/cleanup \
  -H "x-api-key: YOUR_API_KEY"
```

## PowerShell версии (для Windows)

Если curl не работает в cmd, используйте PowerShell:

### Health Check
```powershell
Invoke-RestMethod -Uri "http://localhost:8001/health" -Method Get
```

### TTS
```powershell
$headers = @{"x-api-key" = "YOUR_API_KEY"}
$body = @{
    text = "Привет! Это тестовое сообщение."
    speaker = "xenia"
}
Invoke-RestMethod -Uri "http://localhost:8001/api/tts" `
  -Method Post -Headers $headers -Body $body `
  -OutFile "test_tts.wav"
```

### Lip-Sync
```powershell
$headers = @{"x-api-key" = "YOUR_API_KEY"}
$form = @{
    image = Get-Item -Path "test_face.jpg"
    audio = Get-Item -Path "test_audio.wav"
    bbox_shift = "0"
    batch_size = "8"
    fps = "25"
}
Invoke-RestMethod -Uri "http://localhost:8001/api/lipsync" `
  -Method Post -Headers $headers -Form $form `
  -OutFile "test_lipsync.mp4"
```

## Troubleshooting

### Error: 403 Invalid API Key
- Проверьте что вы используете правильный API ключ из `.env`
- Убедитесь что заголовок `x-api-key` написан строчными буквами

### Error: 503 MuseTalk not available
- MuseTalk не установлен, запустите:
  ```powershell
  powershell -ExecutionPolicy Bypass -File install-musetalk.ps1
  ```

### Error: Connection refused
- Сервер не запущен, запустите `start.bat`
- Проверьте что порт 8001 не занят другим приложением

### Error: CUDA out of memory
- Закройте другие приложения использующие GPU
- Уменьшите `batch_size` в запросе lip-sync
- Уменьшите разрешение изображения

### Медленная генерация
- Проверьте `nvidia-smi` - утилизация GPU должна быть >80%
- Обновите драйверы NVIDIA
- Убедитесь что CUDA 11.8 установлена

## Мониторинг

Во время тестирования можно мониторить GPU:

```cmd
nvidia-smi -l 1
```

Или через PowerShell:
```powershell
while ($true) { nvidia-smi; Start-Sleep -Seconds 1; Clear-Host }
```

## Логи

Проверьте логи сервера для детальной информации:

```cmd
type logs\service.log
type logs\service-error.log
```

Или в реальном времени:
```powershell
Get-Content logs\service.log -Wait -Tail 20
```
