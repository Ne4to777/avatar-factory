# GPU Worker — Руководство по установке

Сервер AI-моделей для Avatar Factory, работающий на стационарном ПК с NVIDIA GPU.

## 1. Обзор

**GPU Worker** — отдельный компонент Avatar Factory, который выполняет тяжёлые AI-задачи (генерация видео, TTS, Stable Diffusion) на компьютере с видеокартой NVIDIA.

**Почему отдельно?**

- AI-модели требуют 12+ GB VRAM и эффективно работают только на GPU
- Можно использовать мощный стационарный ПК, пока ноутбук остаётся для разработки
- Сервер принимает запросы по HTTP с основного приложения

## 2. Системные требования

| Требование | Минимум |
|------------|---------|
| **ОС** | Windows 10/11 (64-bit) |
| **GPU** | NVIDIA с поддержкой CUDA (рекомендуется RTX 3070+ / 8GB+ VRAM) |
| **RAM** | 16 GB |
| **Место на диске** | ~30 GB (модели + зависимости) |
| **Сеть** | Доступен в LAN для подключения ноутбука |

**Перед установкой:**

- [Python 3.11](https://www.python.org/downloads/release/python-3119/) — **строго 3.11** (Python 3.12 несовместим, 3.10 устарел)
- [CUDA Toolkit 11.8](https://developer.nvidia.com/cuda-11-8-0-download-archive) — рекомендуется установить вручную
- Запуск `install.bat` **от имени администратора** (для Python, firewall и т.д.)

## 3. Установка

### ⚡ Docker — РЕКОМЕНДУЕТСЯ для Windows

**Единственный надежный способ запустить MuseTalk на Windows.**

Полное руководство: **[DOCKER-WINDOWS.md](DOCKER-WINDOWS.md)** 📘

**Быстрый старт:**

```cmd
# 1. Установите Docker Desktop + WSL 2 + NVIDIA Container Toolkit
# (см. DOCKER-WINDOWS.md)

# 2. Запустите одним скриптом
docker-start.bat

# 3. Проверьте
curl http://localhost:8001/health
```

**Почему Docker:**
- ✅ MuseTalk работает из коробки (OpenMMLab установлен автоматически)
- ✅ Изолированная среда (не засоряет систему)
- ✅ Легкие обновления
- ✅ Работает на любой Windows (Home/Pro/Enterprise)

---

### 🪟 Windows — Native установка (БЕЗ MuseTalk)

**Ограничение:** Lip-sync (MuseTalk) не работает на Windows без Docker.

**Что работает:** TTS (Silero) + Image Generation (Stable Diffusion)

1. Клонируйте репозиторий (если ещё не сделали):

   ```cmd
   git clone https://github.com/Ne4to777/avatar-factory.git
   cd avatar-factory\gpu-worker
   ```

2. Запустите установщик **от имени администратора**:

   ```cmd
   install.bat
   ```

3. Следуйте инструкциям на экране. Установка займёт 15–30 минут (в зависимости от скорости интернета).

4. После установки запустите сервер:

   ```cmd
   start.bat
   ```

**Важно:** правая кнопка по `install.bat` → «Запуск от имени администратора».

### (Опционально) Ускорение загрузки моделей

Перед установкой MuseTalk можно настроить HuggingFace токен для более быстрой загрузки:

1. Создайте файл `.env` в папке `gpu-worker`:
   ```cmd
   notepad .env
   ```

2. Добавьте:
   ```env
   HF_TOKEN=your_token_here
   API_KEY=your-secret-key-123
   ```

3. Получите токен на https://huggingface.co/settings/tokens

Это увеличит скорость загрузки моделей в 2-3 раза (authenticated vs unauthenticated requests).

### Что делает install.bat

- Проверяет систему (Python 3.11, CUDA, GPU)
- При необходимости устанавливает Python 3.11 через winget
- Создаёт виртуальное окружение
- Устанавливает PyTorch 2.7.0 с поддержкой CUDA 11.8
- Устанавливает зависимости (FastAPI, diffusers, transformers и др.)
- Скачивает AI-модели (~8 GB, по запросу)
- Создаёт `.env` с API-ключом
- Настраивает firewall для порта 8001
- Проверяет установку

**Важно:** Если у вас Python 3.12, установщик остановится с ошибкой и попросит установить Python 3.11. Если у вас Python 3.10, запустите `upgrade-to-py311.bat` для обновления.

## 4. Что устанавливается

| Компонент | Описание |
|-----------|----------|
| **Python venv** | Изолированное окружение в `venv/` |
| **PyTorch 2.7.0 + CUDA** | Глубокое обучение на GPU (последняя версия) |
| **FastAPI + Uvicorn** | HTTP API сервер |
| **MuseTalk** | Real-time lip-sync анимация лица |
| **Stable Diffusion XL** | Генерация фонов |
| **Silero TTS** | Русская озвучка |
| **Real-ESRGAN** | Улучшение качества |
| **FFmpeg** | Обработка видео |

**Примечание:** Для MuseTalk используйте Docker (см. раздел 6).

## 5. Конфигурация

Файл `.env` создаётся автоматически при установке. В нём:

```env
GPU_API_KEY=<сгенерированный ключ>
HOST=0.0.0.0
PORT=8001
```

**Сохраните `GPU_API_KEY`** и укажите его в `.env` на ноутбуке вместе с адресом GPU сервера:

```env
GPU_SERVER_URL="http://192.168.1.100:8001"
GPU_API_KEY=<ваш ключ из gpu-worker>
```

Узнать IP ПК: `ipconfig` (Windows) или `ifconfig` (macOS/Linux).

## 6. Docker Setup (РЕКОМЕНДУЕТСЯ)

MuseTalk требует OpenMMLab пакеты (mmcv, mmpose) которые **практически невозможно** установить на Windows через pip.

### 📘 Полное руководство: [DOCKER-WINDOWS.md](DOCKER-WINDOWS.md)

### Быстрый старт

```cmd
# Автоматическая установка и запуск
docker-start.bat

# Или вручную:
docker build -t avatar-gpu-worker:latest .
docker run -d --name avatar-gpu-worker --gpus all -p 8001:8001 --env-file .env avatar-gpu-worker:latest
```

### Требования

1. **Docker Desktop** для Windows
2. **WSL 2** backend
3. **NVIDIA Container Toolkit** (для GPU)
4. **30+ GB** свободного места

### Управление

```cmd
docker-start.bat      # Запустить
docker-stop.bat       # Остановить
docker-restart.bat    # Перезапустить
docker-logs.bat       # Посмотреть логи
docker-shell.bat      # Зайти в контейнер
docker-check.bat      # Проверить требования
```

Docker образ включает:
- ✅ Python 3.11 + PyTorch 2.7.0
- ✅ CUDA 11.8 + cuDNN
- ✅ MuseTalk + OpenMMLab (mmcv, mmpose, mmdet)
- ✅ Stable Diffusion XL
- ✅ Silero TTS
- ✅ Все зависимости

**Без Docker:** Сервер работает, но lip-sync отключен (только TTS + Stable Diffusion).

## 7. Запуск сервера

### Ручной запуск

```cmd
cd gpu-worker
start.bat
```

Или:

```cmd
cd gpu-worker
venv\Scripts\activate
python server.py
```

Ожидаемый вывод:

```
[>] Loading AI models...
[OK] GPU: NVIDIA GeForce RTX 4070 Ti (12.0GB VRAM)
[OK] MuseTalk initialized successfully - real-time lip-sync ready
[OK] Stable Diffusion XL loaded
[OK] Silero TTS ready
[OK] All models loaded successfully!
[>] Starting GPU Server on 0.0.0.0:8001
```

**Важно:** Если MuseTalk показывает `DISABLED`, используйте Docker (см. раздел 6).

### Windows Service (автозапуск)

Чтобы сервер запускался при загрузке Windows:

```cmd
install-service.bat
```

## 8. Windows Service

### Установка службы

Запустите **от имени администратора**:

```cmd
install-service.bat
```

Преимущества:

- Автозапуск при загрузке Windows
- Работает в фоне
- Автоматический перезапуск при сбое
- Логи в `logs\service.log`

### Управление службой

```cmd
net start AvatarFactoryGPU   # Запуск
net stop AvatarFactoryGPU    # Остановка
```

Или через `stop.bat` / `start.bat` — они учитывают наличие службы.

Перезапуск:

```powershell
Restart-Service AvatarFactoryGPU
```

Или: `net stop AvatarFactoryGPU` затем `net start AvatarFactoryGPU`

Удаление службы:

```cmd
uninstall-service.bat
```

## 9. Troubleshooting

### «Not running as Administrator»

Запустите `install.bat` от имени администратора (ПКМ → «Запуск от имени администратора»).

### «CUDA out of memory»

Уменьшите разрешение в `server.py`:

```python
width = 768   # вместо 1080
height = 1024 # вместо 1920
```

### «GPU Server unavailable» (на ноутбуке)

1. Проверьте, запущен ли сервер: `curl http://192.168.1.100:8001/health`
2. Убедитесь, что `GPU_SERVER_URL` и `GPU_API_KEY` в `.env` ноутбука совпадают с настройками на ПК
3. Откройте порт в firewall:
   ```cmd
   netsh advfirewall firewall add rule name="Avatar Factory" dir=in action=allow protocol=TCP localport=8001
   ```

### Медленная генерация

1. Проверьте нагрузку: `nvidia-smi`
2. Закройте другие приложения, использующие GPU
3. Обновите драйверы NVIDIA

### Ошибки импорта / «module not found»

```cmd
venv\Scripts\activate
pip install --upgrade pip
pip install -r requirements.txt --force-reinstall
```

### Сервер не стартует

Логи установки: `logs\install.log`

Логи службы: `logs\service.log`, `logs\service-error.log`

### Silero TTS показывает DISABLED

**Ошибка:** `FileNotFoundError: hubconf.py`

**Причина:** Поврежденный кеш torch.hub

**Быстрое решение:**
```cmd
fix-and-restart.bat
```

**Ручное решение:**
```cmd
rd /s /q "%USERPROFILE%\.cache\torch\hub\snakers4_silero-models_master"
stop.bat
start.bat
```

Проверка: `curl http://localhost:8001/health` должен показать `"silero_tts": true`

### Старый код после обновления

**Симптом:** Лог показывает старые названия моделей

**Решение:** Перезапустите сервер для загрузки обновленного кода:
```cmd
stop.bat
start.bat
```

### MuseTalk показывает DISABLED

**Причина:** MuseTalk не установлен (требует OpenMMLab пакеты)

**Решение:** Используйте Docker (см. раздел 6).

### Тестирование компонентов

Запустите диагностику всех компонентов:
```cmd
test-components.bat
```

Этот скрипт проверит:
- Python version
- PyTorch и CUDA
- Core dependencies (FastAPI, diffusers, transformers)
- Silero TTS
- MuseTalk

Покажет какие компоненты работают, а какие требуют исправления.

## 10. Ручная установка (для опытных пользователей)

Если автоматическая установка не подходит:

1. Python 3.11, CUDA 11.8 — установите вручную
2. Создайте venv: `python -m venv venv`
3. Активируйте: `venv\Scripts\activate`
4. PyTorch 2.7.0: `pip install torch==2.7.0+cu118 torchvision==0.22.0+cu118 torchaudio==2.7.0+cu118 --index-url https://download.pytorch.org/whl/cu118`
5. Зависимости: `pip install -r requirements.txt`
6. Модели: `python download_models.py`
7. `.env`: скопируйте из примера и задайте `GPU_API_KEY`

**Примечание:** MuseTalk не работает через pip на Windows. Используйте Docker.

**Linux/macOS:**

```bash
cd gpu-worker
make install
make install-models   # ~10 GB, первый раз
make start
```

## 11. Разработка

Для разработки и отладки:

```cmd
venv\Scripts\activate
python server.py
```

Изменения в коде требуют перезапуска сервера.

## 12. API и документация

GPU сервер предоставляет REST API для генерации видео с аватарами:

- `GET /health` — статус GPU и моделей
- `POST /api/tts` — синтез речи
- `POST /api/lipsync` — lip-sync видео
- `POST /api/generate-background` — генерация фона

Полная документация API: [docs/PROJECT_SUMMARY.md](../docs/PROJECT_SUMMARY.md)

---

## Производительность (RTX 4070 Ti)

| Задача | Время |
|--------|-------|
| TTS (10 сек текста) | 1–2 сек |
| **MuseTalk (10 сек видео)** | **10–15 сек** |
| Stable Diffusion XL | 5–10 сек |

**Итого:** ~15–25 сек на полное видео.

**MuseTalk** обеспечивает высокую скорость благодаря real-time архитектуре и оптимизированному inference.

## Поддержка

- [GitHub Issues](https://github.com/Ne4to777/avatar-factory/issues)
- Telegram: @yourusername
