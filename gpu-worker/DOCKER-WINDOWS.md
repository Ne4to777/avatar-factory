# Docker Setup для Windows (GTX 4070)

Полное руководство по запуску Avatar Factory GPU Worker через Docker на Windows.

## 🎯 Почему Docker?

**Проблема:** MuseTalk требует OpenMMLab пакеты (`mmcv`, `mmpose`, `mmdet`), которые **невозможно** установить на Windows через pip.

**Решение:** Docker контейнер с Linux + Miniconda правильно устанавливает все зависимости.

---

## ✅ Требования

### 1. Windows 10/11 Pro, Enterprise, или Education

Docker Desktop требует Hyper-V, который доступен только в этих версиях.

**Windows Home:** Работает с WSL 2 backend (см. ниже).

### 2. Минимум 30 GB свободного места

- Docker images: ~5-8 GB
- AI models: ~10-15 GB
- Рабочие файлы: ~5 GB

### 3. NVIDIA GPU с драйверами

- GTX 1660+ или RTX 2060+
- 8+ GB VRAM (рекомендуется 12+ GB для SDXL)
- Актуальные драйверы NVIDIA

---

## 📦 Установка

### Шаг 1: Установите Docker Desktop

1. Скачайте Docker Desktop для Windows:
   https://docs.docker.com/desktop/install/windows-install/

2. Запустите установщик

3. **Включите WSL 2 backend** (рекомендуется)

4. Перезагрузите компьютер

5. Запустите Docker Desktop

6. Проверьте установку:
   ```cmd
   docker --version
   ```

### Шаг 2: Настройте WSL 2 (если используется)

1. Откройте PowerShell **от имени администратора**:

2. Установите WSL 2:
   ```powershell
   wsl --install
   ```

3. Перезагрузите компьютер

4. Проверьте версию:
   ```powershell
   wsl --status
   ```

### Шаг 3: Установите NVIDIA Container Toolkit

**Важно:** Это нужно для доступа к GPU из Docker контейнера.

#### Вариант A: WSL 2 (рекомендуется)

1. Откройте WSL 2 терминал:
   ```cmd
   wsl
   ```

2. Выполните команды:
   ```bash
   # Добавьте NVIDIA репозиторий
   curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

   distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
   curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
       sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
       sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

   # Установите toolkit
   sudo apt-get update
   sudo apt-get install -y nvidia-container-toolkit

   # Настройте Docker
   sudo nvidia-ctk runtime configure --runtime=docker
   
   # Перезапустите Docker (в WSL)
   sudo systemctl restart docker
   ```

3. Проверьте что GPU работает:
   ```bash
   docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
   ```

   Должны увидеть информацию о вашей GPU.

#### Вариант B: Native Windows (без WSL)

**Примечание:** Поддержка GPU без WSL ограничена. Рекомендуется использовать WSL 2.

---

## 🚀 Запуск GPU Worker

### Автоматический запуск (рекомендуется)

Просто запустите скрипт:

```cmd
docker-start.bat
```

Или PowerShell версию:

```powershell
powershell -ExecutionPolicy Bypass -File docker-start.ps1
```

Скрипт автоматически:
1. ✅ Проверит Docker
2. ✅ Проверит GPU support
3. ✅ Создаст .env если нужно
4. ✅ Соберет Docker image
5. ✅ Запустит контейнер
6. ✅ Проверит что сервер работает

### Ручной запуск

Если предпочитаете делать вручную:

```cmd
cd gpu-worker

# Создайте .env (если нужно)
copy .env.example .env

# Соберите image
docker build -t avatar-gpu-worker:latest .

# Запустите контейнер с GPU
docker run -d ^
    --name avatar-gpu-worker ^
    --gpus all ^
    -p 8001:8001 ^
    --env-file .env ^
    --restart unless-stopped ^
    -v "%cd%\checkpoints:/app/checkpoints" ^
    -v "%cd%\models:/app/models" ^
    avatar-gpu-worker:latest
```

### Проверка

```cmd
# Проверьте что контейнер запущен
docker ps

# Проверьте логи
docker logs -f avatar-gpu-worker

# Проверьте health endpoint
curl http://localhost:8001/health
```

Должны увидеть:
```json
{
  "status": "healthy",
  "gpu": {
    "name": "NVIDIA GeForce RTX 4070",
    "vram_total_gb": 12.0,
    "vram_used_gb": 8.5,
    "vram_free_gb": 3.5,
    "utilization_percent": 70.8
  },
  "models": {
    "musetalk": true,
    "stable_diffusion": true,
    "silero_tts": true
  }
}
```

---

## 🛠️ Управление

### Остановить сервер

```cmd
docker-stop.bat
```

Или:
```cmd
docker stop avatar-gpu-worker
```

### Перезапустить сервер

```cmd
docker-restart.bat
```

Или:
```cmd
docker restart avatar-gpu-worker
```

### Посмотреть логи

```cmd
docker-logs.bat
```

Или:
```cmd
docker logs -f avatar-gpu-worker
```

### Зайти в контейнер

```cmd
docker-shell.bat
```

Или:
```cmd
docker exec -it avatar-gpu-worker /bin/bash
```

Внутри контейнера можете:
- Проверить Python: `python --version`
- Проверить GPU: `nvidia-smi`
- Проверить модели: `ls -lh models/`
- Запустить тесты: `python -m pytest`

### Удалить контейнер

```cmd
docker stop avatar-gpu-worker
docker rm avatar-gpu-worker
```

### Удалить image (освободить место)

```cmd
docker rmi avatar-gpu-worker:latest
```

### Полная очистка

```cmd
docker-compose --profile gpu down -v
docker system prune -a --volumes
```

⚠️ **Внимание:** Это удалит все данные, включая скачанные модели!

---

## 🐛 Troubleshooting

### Проверка требований

Запустите:
```cmd
docker-check.bat
```

Он проверит:
- ✅ Docker Desktop
- ✅ WSL 2
- ✅ NVIDIA GPU
- ✅ NVIDIA Container Toolkit
- ✅ Disk space

### Error: "docker: Error response from daemon: could not select device driver"

**Проблема:** NVIDIA Container Toolkit не установлен или не настроен.

**Решение:**
1. Следуйте инструкциям в Шаг 3 выше
2. Или запустите без GPU (только TTS + SD):
   ```cmd
   docker run -d --name avatar-gpu-worker -p 8001:8001 --env-file .env avatar-gpu-worker:latest
   ```

### Error: "Cannot connect to the Docker daemon"

**Проблема:** Docker Desktop не запущен.

**Решение:**
1. Откройте Docker Desktop
2. Дождитесь пока он запустится (whale icon в tray)
3. Попробуйте снова

### Build failed: "no space left on device"

**Проблема:** Недостаточно места на диске.

**Решение:**
1. Очистите старые Docker images:
   ```cmd
   docker system prune -a
   ```
2. Освободите место на диске (30+ GB рекомендуется)

### Container keeps restarting

**Проблема:** Ошибка при запуске сервера внутри контейнера.

**Решение:**
```cmd
# Посмотрите логи
docker logs avatar-gpu-worker

# Общие причины:
# - CUDA out of memory → закройте другие приложения
# - Model download failed → проверьте интернет
# - Port 8001 busy → освободите порт
```

### GPU not detected in container

**Проблема:** `nvidia-smi` не работает внутри контейнера.

**Решение:**
```cmd
# Проверьте что GPU работает в WSL:
wsl
nvidia-smi

# Проверьте что NVIDIA runtime настроен:
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi

# Если не работает - переустановите NVIDIA Container Toolkit
```

### Models not loading / FileNotFoundError

**Проблема:** AI модели не скачаны или volumes не смонтированы.

**Решение:**
```cmd
# Зайдите в контейнер
docker exec -it avatar-gpu-worker /bin/bash

# Проверьте модели
ls -lh models/
ls -lh checkpoints/

# Скачайте модели вручную (внутри контейнера)
python download_models.py
```

### Very slow performance

**Проблема:** GPU не используется или перегружен.

**Решение:**
```cmd
# Проверьте GPU utilization
nvidia-smi -l 1

# Должно быть >80% во время генерации
# Если низкое:
# 1. Проверьте что --gpus all используется
# 2. Проверьте логи на ошибки CUDA
# 3. Обновите драйверы NVIDIA
```

---

## 📊 Производительность

**RTX 4070 (12GB VRAM) в Docker:**

| Задача | Время |
|--------|-------|
| TTS (10 сек текста) | 1-2 сек |
| MuseTalk (10 сек видео) | 10-15 сек |
| Stable Diffusion XL (1024x1024) | 5-10 сек |

**Overhead Docker:** ~5-10% по сравнению с native установкой.

---

## 🎓 Docker Команды (шпаргалка)

```cmd
# Список контейнеров
docker ps -a

# Логи
docker logs -f avatar-gpu-worker

# Статистика (CPU, RAM, GPU)
docker stats avatar-gpu-worker

# Зайти в контейнер
docker exec -it avatar-gpu-worker /bin/bash

# Перезапустить
docker restart avatar-gpu-worker

# Остановить
docker stop avatar-gpu-worker

# Удалить контейнер
docker rm avatar-gpu-worker

# Удалить image
docker rmi avatar-gpu-worker:latest

# Показать используемое место
docker system df

# Очистка (осторожно!)
docker system prune -a
```

---

## 📚 Дополнительные ресурсы

- [Docker Desktop for Windows](https://docs.docker.com/desktop/install/windows-install/)
- [WSL 2 Installation](https://learn.microsoft.com/en-us/windows/wsl/install)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
- [Docker GPU Support](https://docs.docker.com/config/containers/resource_constraints/#gpu)

---

## ✅ Итог

**Теперь у вас есть:**

✅ Полностью рабочий GPU Worker с MuseTalk  
✅ Все модели (TTS + Lip-sync + Stable Diffusion)  
✅ Изолированная среда (не засоряет систему)  
✅ Легкие обновления (просто rebuild image)  
✅ Автоматический перезапуск при сбоях  

**Следующие шаги:**

1. Запустите: `docker-start.bat`
2. Проверьте: `curl http://localhost:8001/health`
3. Протестируйте API: см. [TEST-API.md](TEST-API.md)
4. Настройте на ноутбуке: [README.md](../README.md)

Готово! 🎉
