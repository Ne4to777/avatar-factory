# Windows Native Installation (БЕЗ Docker)

## Требования

- Windows 10/11
- NVIDIA GPU (у вас RTX 4070 Ti - отлично!)
- NVIDIA драйверы установлены
- CUDA 11.8 установлена (уже есть в PATH)

## Шаг 1: Установите Miniconda (если еще нет)

Скачайте и установите:
https://docs.conda.io/en/latest/miniconda.html

**При установке поставьте галочку "Add to PATH"** (или используйте Anaconda Prompt)

## Шаг 2: Запустите установку

Откройте **Anaconda Prompt** (или обычный CMD если добавили в PATH):

```cmd
cd C:\path\to\avatar-factory\gpu-worker
setup-windows.bat
```

Скрипт автоматически:
- ✅ Создаст conda окружение
- ✅ Установит PyTorch 2.7.0 + CUDA 11.8
- ✅ Установит все зависимости
- ✅ Клонирует MuseTalk
- ✅ Создаст .env файл
- ✅ Проверит GPU

**Время: 10-15 минут** (скачивание ~3GB)

## Шаг 3: Запустите сервер

```cmd
start-windows.bat
```

Или вручную:
```cmd
conda activate avatar
python server.py
```

## Шаг 4: Проверьте

Откройте браузер: http://localhost:8001/health

Должно показать:
```json
{
  "status": "healthy",
  "gpu": {
    "name": "NVIDIA GeForce RTX 4070 Ti",
    "vram_total_gb": 12.88,
    ...
  },
  "models": {
    "musetalk": true,
    "stable_diffusion": true,
    "silero_tts": true
  }
}
```

## Если что-то не работает

### GPU not detected

Проверьте CUDA:
```cmd
nvcc --version
nvidia-smi
```

Должны показать CUDA 11.8 и вашу RTX 4070 Ti.

### MuseTalk failed to load

Клонируйте вручную:
```cmd
git clone https://github.com/TMElyralab/MuseTalk.git
```

### Другие ошибки

Покажите вывод:
```cmd
python server.py
```

## Преимущества Native Windows vs Docker

| Feature | Native Windows | Docker (WSL2) |
|---------|---------------|---------------|
| Установка | ⭐ 10 минут | ⭐⭐⭐ 1-2 часа + WSL2 проблемы |
| GPU доступ | ✅ Напрямую | ⚠️ Через WSL2 |
| Отладка | ✅ Простая | ❌ Сложная |
| Производительность | ✅ 100% | ⚠️ ~95% |

Для разработки **Native Windows намного проще!**
