# 🚀 START HERE - Пошаговая инструкция

## Текущий статус сервера

Ваш сервер сейчас запущен, но:
- ❌ **Silero TTS** - поврежденный кеш (DISABLED)
- ✅ **Stable Diffusion** - работает (OK)
- ❌ **MuseTalk** - не установлен (DISABLED)

---

## 📝 Что нужно сделать (3 шага)

### ШАГ 1: Исправить Silero TTS и перезапустить ✨

**Вариант 1 (рекомендуется):** Двойной клик по файлу
```
Откройте Проводник Windows → C:\dev\avatar-factory\gpu-worker
Двойной клик на: fix-and-restart.bat
```

**Вариант 2:** Через командную строку
```cmd
cd C:\dev\avatar-factory\gpu-worker
fix-and-restart.bat
```

**Вариант 3:** Полный путь (работает из любого места)
```cmd
C:\dev\avatar-factory\gpu-worker\fix-and-restart.bat
```

Этот скрипт:
- Остановит текущий сервер
- Очистит поврежденный кеш Silero TTS
- Загрузит обновленный код с поддержкой MuseTalk
- Перезапустит сервер

**Время:** ~30 секунд

**Проверка:**
```bash
curl http://localhost:8001/health
```

Должно показать:
```json
{
  "models": {
    "musetalk": false,         ← Пока false (устанавливаем в шаге 2)
    "stable_diffusion": true,
    "silero_tts": true         ← Должно быть true!
  }
}
```

---

### ШАГ 2: Установить MuseTalk 🎬

После того как Silero TTS заработал, установите MuseTalk:

```powershell
powershell -ExecutionPolicy Bypass -File install-musetalk.ps1
```

Этот скрипт:
- Клонирует MuseTalk repository (~200 MB)
- Установит дополнительные зависимости
- Скачает модели из HuggingFace (~2 GB)
- Установит custom packages (MMCM, controlnet_aux и др.)

**Время:** ~5-15 минут (зависит от скорости интернета)

**Проверка после установки:**
```cmd
venv\Scripts\python.exe -c "from musetalk_inference import test_musetalk; test_musetalk()"
```

Должно вывести:
```
[INFO] Testing MuseTalk installation...
[INFO] MuseTalk initialized successfully!
```

**Перезапустите сервер:**
```cmd
stop.bat
start.bat
```

**Финальная проверка:**
```bash
curl http://localhost:8001/health
```

Должно показать:
```json
{
  "models": {
    "musetalk": true,          ← Теперь true!
    "stable_diffusion": true,
    "silero_tts": true
  }
}
```

---

### ШАГ 3: Протестировать API 🧪

Используйте руководство `TEST-API.md` для тестирования всех эндпоинтов.

**Быстрый тест:**
```bash
# 1. Генерация речи
curl -X POST http://localhost:8001/api/tts ^
  -H "x-api-key: YOUR_API_KEY" ^
  -d "text=Привет! Это тест." ^
  -d "speaker=xenia" ^
  --output test_tts.wav

# 2. Проверка lip-sync (после установки MuseTalk)
curl -X POST http://localhost:8001/api/lipsync ^
  -H "x-api-key: YOUR_API_KEY" ^
  -F "image=@test_face.jpg" ^
  -F "audio=@test_tts.wav" ^
  --output test_lipsync.mp4
```

**API ключ:** найдите в `.env` файле (`type .env`)

---

## 🛠️ Дополнительные утилиты

### Диагностика компонентов
```cmd
test-components.bat
```
Проверяет Python, PyTorch, CUDA, зависимости, Silero TTS, MuseTalk.

### Установка Windows Service (автозапуск)
```cmd
install-service.bat
```
Сервер будет автоматически запускаться при загрузке Windows.

### Удаление Windows Service
```cmd
uninstall-service.bat
```

---

## 📊 Текущая конфигурация

### Технологии
- Python 3.11
- PyTorch 2.7.0 + CUDA 11.8
- MuseTalk для real-time lip-sync
- Stable Diffusion XL для генерации фонов
- Silero TTS для русской озвучки

### Производительность (RTX 4070 Ti)
- Генерация 10 сек видео: **~10-15 сек**
- Генерация 30 сек видео: **~30-45 сек**
- TTS 10 сек текста: **~1-2 сек**
- Stable Diffusion 1024x1024: **~5-10 сек**

---

## ❓ Если что-то пошло не так

### Silero TTS всё ещё DISABLED после fix-and-restart.bat

**Ручная очистка кеша:**
```cmd
rd /s /q "%USERPROFILE%\.cache\torch\hub"
stop.bat
start.bat
```

### MuseTalk не устанавливается

**Проверьте логи установки** на наличие ошибок:
- Ошибки компиляции C++ кода (mmcv, mmpose)
- Недостаточно места на диске
- Проблемы с интернет подключением

**Попробуйте установить заново:**
```powershell
rd /s /q MuseTalk
powershell -ExecutionPolicy Bypass -File install-musetalk.ps1
```

### Нужна помощь

1. Запустите диагностику:
   ```cmd
   test-components.bat
   ```

2. Проверьте логи:
   ```cmd
   type logs\service.log
   type logs\service-error.log
   ```

3. Откройте issue на GitHub с логами и описанием проблемы

---

## 🎯 Краткий чеклист

- [ ] Запустил `fix-and-restart.bat`
- [ ] Проверил `/health` - silero_tts = true
- [ ] Запустил `install-musetalk.ps1`
- [ ] Перезапустил сервер (stop.bat → start.bat)
- [ ] Проверил `/health` - musetalk = true
- [ ] Протестировал TTS (см. TEST-API.md)
- [ ] Протестировал lip-sync (см. TEST-API.md)
- [ ] Установил Windows Service (опционально)
- [ ] Обновил `.env` на ноутбуке с правильным GPU_SERVER_URL

---

## 📚 Документация

- **README.md** - Полное руководство по установке и использованию
- **TEST-API.md** - Примеры тестирования всех API эндпоинтов
- **CHANGELOG-MUSETALK.md** - Детальное описание изменений
- **QUICK-FIX.md** - Решения частых проблем

---

**Успешной работы! 🎉**

Если всё работает, переходите к тестированию через фронтенд:
```bash
cd ..  # в корень проекта avatar-factory
npm run dev
```

Откройте http://localhost:3000 и создайте первое видео! 🚀
