# 🚀 Установка за одну команду

Avatar Factory можно установить буквально **одной командой**!

## 📋 Быстрый старт

### Вариант 1: Универсальный установщик (рекомендуется)

```bash
curl -sSL https://raw.githubusercontent.com/Ne4to777/avatar-factory/main/quick-start.sh | bash
```

Скрипт автоматически:
- ✅ Определит тип вашей машины (GPU/без GPU)
- ✅ Установит нужные компоненты
- ✅ Проверит зависимости
- ✅ Настроит окружение
- ✅ Запустит тесты

### Вариант 2: Прямая установка

#### На стационарном ПК (с GPU):

**Linux/macOS:**
```bash
cd gpu-worker
./install.sh
```

**Windows:**
```cmd
cd gpu-worker
install.bat
```

#### На ноутбуке (главное приложение):

**Linux/macOS:**
```bash
./install.sh
```

---

## 🖥️ Стационарный ПК (GPU Worker)

### Требования:
- ✅ NVIDIA GPU (RTX 3060+, рекомендуется RTX 4070 Ti)
- ✅ CUDA Toolkit 11.8+
- ✅ Python 3.10+
- ✅ ~20GB свободного места (для AI моделей)

### Установка:

```bash
cd gpu-worker
chmod +x install.sh
./install.sh
```

Скрипт автоматически:
1. Проверит Python, pip, git, CUDA
2. Создаст виртуальное окружение
3. Установит PyTorch с CUDA
4. Установит все Python зависимости
5. Склонирует SadTalker
6. Предложит скачать AI модели (~10GB, 15-20 минут)
7. Создаст .env файл с API ключом

### Запуск:

```bash
./start.sh
```

Сервер запустится на `http://0.0.0.0:8001`

---

## 💻 Ноутбук (Main Application)

### Требования:
- ✅ Node.js 18+
- ✅ Docker Desktop
- ✅ ~2GB свободного места

### Установка:

```bash
chmod +x install.sh
./install.sh
```

Скрипт автоматически:
1. Проверит Node.js и Docker
2. Установит npm зависимости
3. Запустит Docker Compose (PostgreSQL, Redis, MinIO)
4. Применит миграции базы данных
5. Создаст .env файл
6. Запустит базовые тесты

### Запуск:

```bash
./start.sh
```

Приложение откроется на `http://localhost:3000`

---

## 🔗 Соединение машин

### На стационарном ПК:

1. Узнайте IP адрес:
   ```bash
   # Linux
   ip addr show
   
   # macOS
   ifconfig
   
   # Windows
   ipconfig
   ```

2. Запустите GPU сервер:
   ```bash
   ./start.sh
   ```

3. Скопируйте API ключ из `.env` файла

### На ноутбуке:

1. Откройте `.env` файл

2. Обновите настройки:
   ```env
   GPU_SERVER_URL=http://192.168.1.XXX:8001
   GPU_API_KEY=<ключ-со-стационарного-пк>
   ```

3. Запустите приложение:
   ```bash
   ./start.sh
   ```

---

## 🎯 Опции запуска

### GPU Worker

```bash
# Просто запуск
./start.sh

# Или напрямую
source venv/bin/activate
python server.py
```

### Main Application

```bash
# Интерактивный выбор режима
./start.sh

# Режимы:
# 1 - Development (только UI)
# 2 - Production (UI + Worker)
# 3 - Worker only
```

Или раздельно:

```bash
# Terminal 1: UI
npm run dev

# Terminal 2: Worker
npm run worker
```

---

## 🛠️ Troubleshooting

### GPU Worker

**Проблема:** CUDA not found
```bash
# Установите CUDA Toolkit
# https://developer.nvidia.com/cuda-downloads

# Проверьте установку
nvidia-smi
nvcc --version
```

**Проблема:** Python version too old
```bash
# Ubuntu/Debian
sudo apt install python3.10 python3.10-venv

# macOS
brew install python@3.10
```

**Проблема:** Models download failed
```bash
# Скачайте вручную
python download_models.py

# Или используйте торренты (быстрее)
# См. gpu-worker/README.md
```

### Main Application

**Проблема:** Docker not running
```bash
# macOS
open -a Docker

# Linux
sudo systemctl start docker

# Windows
# Запустите Docker Desktop из меню Пуск
```

**Проблема:** Port 5432 already in use
```bash
# Отредактируйте docker-compose.yml
# Измените порт на 5433 (уже исправлено в репозитории)
```

**Проблема:** npm install failed
```bash
# Очистите кэш
npm cache clean --force
rm -rf node_modules package-lock.json
npm install
```

---

## ⚡ Быстрые команды

### Проверка статуса

```bash
# GPU Server
curl http://localhost:8001/health

# Main App
curl http://localhost:3000/api/health

# Docker
docker-compose ps
```

### Остановка

```bash
# GPU Worker
# Ctrl+C в терминале

# Main App
# Ctrl+C в терминале
docker-compose down
```

### Перезапуск

```bash
# GPU Worker
cd gpu-worker
./start.sh

# Main App
docker-compose restart
./start.sh
```

### Логи

```bash
# Docker
docker-compose logs -f

# Specific service
docker-compose logs -f postgres
docker-compose logs -f redis

# App logs
tail -f /tmp/avatar-factory-dev.log
tail -f /tmp/avatar-factory-worker.log
```

---

## 📊 Проверка установки

### GPU Worker

```bash
cd gpu-worker
source venv/bin/activate

# Проверка Python пакетов
python -c "import torch; print('PyTorch:', torch.__version__)"
python -c "import torch; print('CUDA:', torch.cuda.is_available())"
python -c "import fastapi; print('FastAPI OK')"

# Тест сервера
python test_server.py
```

### Main Application

```bash
# Проверка зависимостей
npm list --depth=0

# Тест БД и сервисов
npx tsx test-basic.ts

# Полный тест API
npx tsx test-api-full.ts
```

---

## 🎬 Создание первого видео

1. **Убедитесь что всё запущено:**
   - ✅ GPU сервер (стационарный ПК)
   - ✅ Main app (ноутбук)
   - ✅ Worker (ноутбук)

2. **Откройте браузер:**
   ```
   http://localhost:3000
   ```

3. **Загрузите фото вашего лица**

4. **Введите текст** (например: "Привет! Это моё первое видео с аватаром!")

5. **Выберите настройки:**
   - Стиль фона
   - Формат видео
   - Голос

6. **Нажмите "Создать видео"**

7. **Подождите 1-3 минуты** ⏳

8. **Скачайте результат!** 🎉

---

## 📚 Дополнительная документация

- **QUICKSTART.md** - Подробный гайд на 15 минут
- **README.md** - Полная документация проекта
- **DEPLOYMENT.md** - Production deployment
- **TEST_RESULTS.md** - Результаты тестирования
- **gpu-worker/README.md** - Детали GPU сервера

---

## 💡 Полезные ссылки

### Зависимости

- **Node.js:** https://nodejs.org/
- **Python:** https://www.python.org/downloads/
- **Docker:** https://www.docker.com/products/docker-desktop
- **CUDA:** https://developer.nvidia.com/cuda-downloads

### AI Models

- **SadTalker:** https://github.com/OpenTalker/SadTalker
- **Silero TTS:** https://github.com/snakers4/silero-models
- **Stable Diffusion:** https://github.com/Stability-AI/stablediffusion

### Support

- **GitHub Issues:** https://github.com/Ne4to777/avatar-factory/issues
- **Documentation:** В репозитории

---

## ⏱️ Время установки

| Компонент | Время |
|-----------|-------|
| GPU Worker (без моделей) | 5-10 минут |
| AI Models Download | 15-30 минут |
| Main Application | 5-10 минут |
| **Итого** | **25-50 минут** |

## 💰 Стоимость

| | Разработка | После GPU |
|---|---|---|
| **Инфраструктура** | $0/мес | $5-10/мес |
| **API** | $0/мес | $0/мес |
| **vs Платные API** | - | **Экономия $1,200-6,000/год!** |

---

**Готово!** 🎉 Система установлена и готова к работе!
