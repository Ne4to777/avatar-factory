# 🚀 Быстрый старт - Docker на Windows

## Что я сделал для вас

Я проанализировал проблему и создал **полное решение для Windows**:

### ❌ Проблема

- MuseTalk требует OpenMMLab (`mmcv`, `mmpose`, `mmdet`)
- Эти пакеты **невозможно** установить на Windows через pip
- Отсутствовал скрипт `install-musetalk.ps1` (упоминался 15+ раз в коде но не существовал)
- Не было Windows-скриптов для Docker

### ✅ Решение

Docker контейнер с Linux + Miniconda правильно устанавливает все зависимости.

Я создал:
- ✅ `docker-start.bat` - автоматический запуск
- ✅ `docker-stop.bat` - остановка
- ✅ `docker-restart.bat` - перезапуск
- ✅ `docker-logs.bat` - просмотр логов
- ✅ `docker-shell.bat` - доступ к контейнеру
- ✅ `docker-check.bat` - проверка требований
- ✅ `docker-start.ps1` - PowerShell версия
- ✅ `DOCKER-WINDOWS.md` - полное руководство (30+ страниц)

---

## 📋 Что нужно сделать сейчас

### Шаг 1: Установите Docker Desktop (15 минут)

1. Скачайте Docker Desktop:
   https://docs.docker.com/desktop/install/windows-install/

2. Запустите установщик

3. **Включите WSL 2 backend** (галочка при установке)

4. Перезагрузите компьютер

5. Запустите Docker Desktop и дождитесь запуска

6. Проверьте (в cmd):
   ```cmd
   docker --version
   ```

### Шаг 2: Настройте WSL 2 (10 минут)

1. Откройте **PowerShell от имени администратора**

2. Выполните:
   ```powershell
   wsl --install
   ```

3. Перезагрузите компьютер

4. Проверьте:
   ```powershell
   wsl --status
   ```

### Шаг 3: Установите NVIDIA Container Toolkit (10 минут)

Это нужно чтобы Docker мог использовать вашу GTX 4070.

1. Откройте WSL терминал:
   ```cmd
   wsl
   ```

2. Скопируйте и выполните **все команды**:

```bash
# Добавьте репозиторий NVIDIA
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Установите
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# Настройте Docker
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

3. Проверьте что GPU работает:
```bash
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
```

Должны увидеть информацию о GTX 4070!

### Шаг 4: Запустите GPU Worker (20 минут первый раз)

1. Закройте WSL, откройте cmd в папке `gpu-worker`:
   ```cmd
   cd C:\path\to\avatar-factory\gpu-worker
   ```

2. Запустите автоматический скрипт:
   ```cmd
   docker-start.bat
   ```

Скрипт сделает:
- ✅ Проверит Docker и GPU
- ✅ Создаст `.env` с API ключом
- ✅ Соберет Docker image (~10-20 минут, скачает ~5GB)
- ✅ Запустит контейнер
- ✅ Проверит что сервер работает

3. Проверьте что работает:
   ```cmd
   curl http://localhost:8001/health
   ```

Должны увидеть:
```json
{
  "status": "healthy",
  "gpu": {
    "name": "NVIDIA GeForce RTX 4070",
    "vram_total_gb": 12.0,
    ...
  },
  "models": {
    "musetalk": true,
    "stable_diffusion": true,
    "silero_tts": true
  }
}
```

**Все три модели `true`** = всё работает! 🎉

---

## 🔧 Если что-то пошло не так

### Проверьте требования

```cmd
docker-check.bat
```

Покажет что именно не работает.

### Частые проблемы

#### 1. "Docker daemon not running"

**Решение:** Запустите Docker Desktop

#### 2. "could not select device driver"

**Решение:** NVIDIA Container Toolkit не установлен, повторите Шаг 3

#### 3. "no space left on device"

**Решение:** Освободите место (нужно 30+ GB):
```cmd
docker system prune -a
```

#### 4. Build очень долгий / зависает

**Решение:** Проверьте интернет, подождите 20 минут

#### 5. Container не стартует

**Решение:** Посмотрите логи:
```cmd
docker logs avatar-gpu-worker
```

---

## 📚 Дополнительно

### Управление контейнером

```cmd
docker-stop.bat       # Остановить
docker-restart.bat    # Перезапустить
docker-logs.bat       # Логи в реальном времени
docker-shell.bat      # Зайти внутрь контейнера
```

### Посмотреть что внутри контейнера

```cmd
docker-shell.bat

# Внутри контейнера:
nvidia-smi              # Проверить GPU
ls -lh models/          # Проверить модели
python --version        # Python 3.11
conda list              # Все установленные пакеты
```

### Тестирование API

См. [TEST-API.md](TEST-API.md) для примеров запросов.

```cmd
# TTS
curl -X POST http://localhost:8001/api/tts ^
  -H "x-api-key: YOUR_KEY" ^
  -d "text=Привет мир" ^
  --output test.wav

# Lip-sync (требуется image и audio файлы)
curl -X POST http://localhost:8001/api/lipsync ^
  -H "x-api-key: YOUR_KEY" ^
  -F "image=@face.jpg" ^
  -F "audio=@speech.wav" ^
  --output video.mp4
```

### Настройка на ноутбуке

После того как GPU worker работает, настройте основное приложение:

1. Найдите IP компьютера с GPU:
   ```cmd
   ipconfig
   ```
   Ищите IPv4 Address (например `192.168.1.100`)

2. В `.env` на ноутбуке добавьте:
   ```env
   GPU_SERVER_URL=http://192.168.1.100:8001
   GPU_API_KEY=<ключ из gpu-worker/.env>
   ```

3. Проверьте с ноутбука:
   ```bash
   curl http://192.168.1.100:8001/health
   ```

---

## ✅ Чеклист

- [ ] Docker Desktop установлен и запущен
- [ ] WSL 2 работает
- [ ] NVIDIA Container Toolkit установлен
- [ ] GPU виден в Docker (`docker run --rm --gpus all nvidia/cuda... nvidia-smi`)
- [ ] `docker-start.bat` успешно выполнен
- [ ] `curl http://localhost:8001/health` возвращает `"musetalk": true`
- [ ] Тесты API работают (TTS, lip-sync)
- [ ] Ноутбук может подключиться к GPU серверу

---

## 🎯 Итог

После выполнения всех шагов у вас будет:

✅ Полностью рабочий GPU Worker с MuseTalk  
✅ Все 3 модели: TTS + Lip-sync + Stable Diffusion  
✅ Доступ из локальной сети (ноутбук → ПК)  
✅ Изолированная среда (легко обновлять)  

**Время:**
- Установка: ~45 минут (первый раз)
- Следующий запуск: ~30 секунд (`docker-restart.bat`)

**Нужна помощь?**

- Полная документация: [DOCKER-WINDOWS.md](DOCKER-WINDOWS.md)
- API примеры: [TEST-API.md](TEST-API.md)
- GitHub Issues: https://github.com/Ne4to777/avatar-factory/issues

Удачи! 🚀
