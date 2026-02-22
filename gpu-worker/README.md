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

- [Python 3.10 или 3.11](https://www.python.org/downloads/release/python-31011/) — **рекомендуется 3.10** (Python 3.12 несовместим с AI библиотеками!)
- [CUDA Toolkit 11.8](https://developer.nvidia.com/cuda-11-8-0-download-archive) — рекомендуется установить вручную
- Запуск `install.bat` **от имени администратора** (для Python, firewall и т.д.)

## 3. One-Command Installation

### Windows — одна команда

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

### Что делает install.bat

- Проверяет систему (Python 3.10-3.11, CUDA, GPU)
- При необходимости устанавливает Python 3.10 через winget
- Создаёт виртуальное окружение
- Устанавливает PyTorch с поддержкой CUDA
- Устанавливает зависимости (FastAPI, diffusers и др.)
- Клонирует SadTalker и настраивает его
- Скачивает AI-модели (~10 GB, по запросу)
- Создаёт `.env` с API-ключом
- Настраивает firewall
- Проверяет установку

**Важно:** Если у вас Python 3.12, установщик остановится с ошибкой и попросит установить Python 3.10.

## 4. Что устанавливается

| Компонент | Описание |
|-----------|----------|
| **Python venv** | Изолированное окружение в `venv/` |
| **PyTorch + CUDA** | Глубокое обучение на GPU |
| **FastAPI + Uvicorn** | HTTP API сервер |
| **SadTalker** | Lip-sync анимация лица |
| **Stable Diffusion XL** | Генерация фонов |
| **Silero TTS** | Русская озвучка |
| **Real-ESRGAN** | Улучшение качества |
| **FFmpeg** | Обработка видео |

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

## 6. Запуск сервера

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
🚀 Loading AI models...
✅ GPU: NVIDIA GeForce RTX 4070 Ti (12.0GB VRAM)
✅ SadTalker loaded
✅ Stable Diffusion XL loaded
✅ Silero TTS loaded
🎉 All models loaded successfully!
🚀 Starting GPU Server on 0.0.0.0:8001
```

### Windows Service (автозапуск)

Чтобы сервер запускался при загрузке Windows:

```powershell
.\service-install.ps1
```

## 7. Windows Service

### Установка службы

Запустите **от имени администратора**:

```powershell
.\service-install.ps1
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

```powershell
.\service-uninstall.ps1
```

## 8. Troubleshooting

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

## 9. Ручная установка (для опытных пользователей)

Если автоматическая установка не подходит:

1. Python 3.10+, CUDA 11.8 — установите вручную
2. Создайте venv: `python -m venv venv`
3. Активируйте: `venv\Scripts\activate`
4. PyTorch: `pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118`
5. Зависимости: `pip install -r requirements.txt`
6. SadTalker: `git clone https://github.com/OpenTalker/SadTalker.git` + `pip install -r SadTalker/requirements.txt`
7. Модели: `python download_models.py`
8. `.env`: скопируйте из примера и задайте `GPU_API_KEY`

**Linux/macOS:**

```bash
cd gpu-worker
make install
make install-models   # ~10 GB, первый раз
make start
```

## 10. Разработка

Для разработки и отладки:

```cmd
venv\Scripts\activate
python server.py
```

Изменения в коде требуют перезапуска сервера.

## 11. API и документация

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
| SadTalker (10 сек видео) | 30–60 сек |
| Stable Diffusion XL | 5–10 сек |

**Итого:** ~40–70 сек на одно видео (15–30 сек).

## Поддержка

- [GitHub Issues](https://github.com/Ne4to777/avatar-factory/issues)
- Telegram: @yourusername
