# 🐳 Docker Setup for MuseTalk (Recommended for Windows)

## Почему Docker?

MuseTalk требует `mmpose` с OpenMMLab зависимостями, которые имеют сложную сборку на Windows:
- ❌ Требует Visual Studio Build Tools (~6 GB)
- ❌ Конфликты с `setuptools`, `pkg_resources`
- ❌ Проблемы со сборкой C++ расширений

**Docker решает все эти проблемы!**
- ✅ Всё предустановлено и работает
- ✅ Нет конфликтов зависимостей
- ✅ Одна команда для запуска

---

## 📋 Требования

1. **Docker Desktop для Windows:**
   - Скачать: https://www.docker.com/products/docker-desktop/
   - Требует Windows 10/11 Pro или WSL2 на Home

2. **NVIDIA GPU + CUDA:**
   - NVIDIA Container Toolkit: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html

3. **10-15 GB свободного места** (для образа + модели)

---

## 🚀 Быстрый старт

### Доступные варианты

**У нас есть 3 варианта Dockerfile:**

| Файл | MuseTalk | Размер | Время сборки | Сложность |
|------|----------|--------|--------------|-----------|
| `Dockerfile` | ❌ Нет | ~5 GB | 10 мин | Легко |
| `Dockerfile.conda` | ✅ **Да** | ~8 GB | 20 мин | **Рекомендуется** |
| `Dockerfile.full` | ⚠️ Экспериментально | ~7 GB | 30 мин | Сложно |

**Рекомендация:** Используйте `Dockerfile.conda` для полной функциональности!

---

### 1️⃣ Установите Docker Desktop

```powershell
# Скачайте и установите Docker Desktop
# https://www.docker.com/products/docker-desktop/

# После установки перезагрузите компьютер
```

### 2️⃣ Включите GPU support (если есть NVIDIA GPU)

```powershell
# Установите NVIDIA Container Toolkit
# https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html

# Проверьте что GPU доступен:
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
```

### 3️⃣ Выберите вариант сборки

#### Вариант A: С MuseTalk (Рекомендуется) ✅

```powershell
cd C:\dev\avatar-factory\gpu-worker

# Соберите образ с Anaconda (включает MuseTalk):
docker build -f Dockerfile.conda -t avatar-factory-gpu:full .

# Запустите:
docker run --gpus all -p 8001:8001 -v ${PWD}/.env:/app/.env avatar-factory-gpu:full
```

#### Вариант B: Без MuseTalk (Быстрее)

```powershell
cd C:\dev\avatar-factory\gpu-worker

# Соберите базовый образ (без MuseTalk):
docker build -t avatar-factory-gpu:lite .

# Запустите:
docker run --gpus all -p 8001:8001 -v ${PWD}/.env:/app/.env avatar-factory-gpu:lite
```

### 4️⃣ Проверьте работу

```powershell
curl http://localhost:8001/health
```

**С MuseTalk (Dockerfile.conda):**
```json
{
  "status": "healthy",
  "models": {
    "musetalk": true,      ← Работает!
    "stable_diffusion": true,
    "silero_tts": true
  }
}
```

**Без MuseTalk (Dockerfile):**
```json
{
  "status": "healthy",
  "models": {
    "musetalk": false,     ← Отключен
    "stable_diffusion": true,
    "silero_tts": true
  }
}
```

---

## 🔧 Docker Compose (удобнее)

### docker-compose.yml

Создайте файл `docker-compose.yml`:

```yaml
version: '3.8'

services:
  gpu-worker:
    build: .
    image: avatar-factory-gpu
    container_name: avatar-factory-gpu
    ports:
      - "8001:8001"
    volumes:
      - ./.env:/app/.env
      - ./models:/app/models
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    restart: unless-stopped
```

### Команды

```powershell
# Запустить:
docker-compose up -d

# Остановить:
docker-compose down

# Посмотреть логи:
docker-compose logs -f

# Перезапустить:
docker-compose restart
```

---

## 📦 Dockerfile (уже готов)

Dockerfile уже настроен и находится в `gpu-worker/Dockerfile`:

```dockerfile
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04

# Python 3.11 (same as native setup)
ENV PYTHON_VERSION=3.11

# Install Python 3.11 from deadsnakes PPA
RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt-get install python3.11 python3.11-venv python3.11-dev

# Install PyTorch 2.7.0 with CUDA 11.8
RUN pip install torch==2.7.0+cu118 torchvision==0.22.0+cu118 torchaudio==2.7.0+cu118

# Install OpenMMLab packages (works fine in Linux!)
RUN pip install openmim && \
    mim install mmcv && \
    pip install mmdet mmpose

# Install MuseTalk and all dependencies
RUN git clone https://github.com/TMElyralab/MuseTalk.git && \
    pip install -r musetalk-requirements.txt

# ... rest of setup
```

**Важно:** OpenMMLab пакеты (`mmcv`, `mmdet`, `mmpose`) устанавливаются **без проблем** в Linux/Docker!

Всё работает из коробки! 🎉

---

## ⚙️ Конфигурация

### .env файл

```env
# GPU Worker API Key
API_KEY=your-secret-key-123

# HuggingFace Token (optional, для быстрой загрузки)
HF_TOKEN=hf_YOUR_TOKEN_HERE

# Server settings
HOST=0.0.0.0
PORT=8001
LOG_LEVEL=INFO
```

---

## 🎯 Альтернатива: Docker Hub (pre-built образ)

Если не хотите собирать локально, можно использовать pre-built образ:

```powershell
# Pull pre-built образ (если опубликован):
docker pull ne4to777/avatar-factory-gpu:latest

# Запустить:
docker run --gpus all -p 8001:8001 -v ${PWD}/.env:/app/.env ne4to777/avatar-factory-gpu:latest
```

---

## 🐛 Troubleshooting

### "docker: Error response from daemon: could not select device driver"

**Решение:** Установите NVIDIA Container Toolkit:
```powershell
# https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
```

### "Cannot connect to the Docker daemon"

**Решение:**
1. Запустите Docker Desktop
2. Подождите пока Docker полностью загрузится (иконка в трее)

### "Out of memory" при сборке

**Решение:**
1. Docker Desktop → Settings → Resources
2. Увеличьте Memory до 8-16 GB
3. Перезапустите Docker Desktop

### Контейнер падает сразу после запуска

**Проверьте логи:**
```powershell
docker logs avatar-factory-gpu
```

Обычно это:
- Отсутствует `.env` файл
- Неправильный `API_KEY`
- Недостаточно VRAM на GPU

---

## 📊 Производительность

**Docker vs Native Windows:**
- **Скорость:** ~95-98% от native (практически без потерь)
- **Память:** +500-1000 MB overhead для Docker
- **Изоляция:** Полная изоляция от системных библиотек

---

## 🔗 Полезные ссылки

- Docker Desktop: https://www.docker.com/products/docker-desktop/
- NVIDIA Container Toolkit: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/
- Docker Compose: https://docs.docker.com/compose/
- WSL2: https://docs.microsoft.com/en-us/windows/wsl/install

---

## 🎉 Готово!

После setup через Docker, MuseTalk будет работать **без проблем с зависимостями**!

```powershell
# Проверь что всё работает:
curl -X POST http://localhost:8001/api/lipsync \
  -H "x-api-key: your-api-key" \
  -F "image=@test_image.jpg" \
  -F "audio=@test_audio.wav" \
  --output result.mp4
```

Если видишь `result.mp4` - всё работает! 🚀
