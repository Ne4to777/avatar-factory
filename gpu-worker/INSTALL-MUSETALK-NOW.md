# 🚨 Как установить MuseTalk СЕЙЧАС

## Проблема
```
ERROR: Could not install packages due to an OSError: [WinError 5] Отказано в доступе
Check the permissions.
```

**Причина:** Сервер запущен и держит файлы OpenCV/PyTorch. Нужно остановить перед установкой.

---

## ⚙️ Требования (важно!)

MuseTalk требует **Visual Studio Build Tools** для компиляции C++ расширений (`mmcv`, `mmpose`, `mmdet`).

### Проверьте что Build Tools установлены:

```cmd
where cl
```

Если видите путь (например `C:\Program Files\Microsoft Visual Studio\...`), всё ОК.

### Если Build Tools НЕ установлены:

1. Скачайте: https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022
2. Запустите установщик
3. Выберите: **"Desktop development with C++"**
4. Установите (требуется ~6 GB)
5. Перезагрузите компьютер

**Без Build Tools установка MuseTalk провалится с ошибкой:**
```
error: Microsoft Visual C++ 14.0 or greater is required
```

---

## ✅ Решение (4 команды)

### 1️⃣ Остановите сервер
```cmd
cd C:\dev\avatar-factory\gpu-worker
stop.bat
```

Подождите **5 секунд** чтобы все процессы завершились.

### 2️⃣ Обновите код
```cmd
git pull
```

Что изменилось:
- ✅ Исправлена ошибка PowerShell "Could not load module 'venv'"
- ✅ `install-musetalk.ps1` автоматически проверяет что сервер остановлен
- ✅ Удалены все упоминания устаревших модулей
- ✅ Добавлена поддержка HF_TOKEN для быстрой загрузки

### 2.5️⃣ (Опционально) Настройте токен для быстрой загрузки

Чтобы модели скачивались **в 2-3 раза быстрее**, создайте `.env` файл:

```cmd
cd C:\dev\avatar-factory\gpu-worker
notepad .env
```

Вставьте в `.env`:
```env
HF_TOKEN=hf_YOUR_TOKEN_HERE
API_KEY=your-secret-key-123
```

Сохраните (Ctrl+S) и закройте notepad.

Без токена модели тоже скачаются, просто медленнее.

### 3️⃣ Перезапустите PowerShell
Закройте и откройте PowerShell заново (или cmd), чтобы избежать проблем с кешированием переменных.

### 4️⃣ Установите MuseTalk
```cmd
cd C:\dev\avatar-factory\gpu-worker
powershell -ExecutionPolicy Bypass -File install-musetalk.ps1
```

Установка займет **5-15 минут** (скачивает ~2GB).

---

## ✅ После установки

### 1. Запустите сервер:
```cmd
start.bat
```

### 2. Проверьте что MuseTalk загрузился:
```bash
curl http://localhost:8001/health
```

Должно показать:
```json
{
  "models": {
    "musetalk": true,  ← Должно быть true!
    "stable_diffusion": true,
    "silero_tts": true
  }
}
```

### 3. Протестируйте API:
Смотрите `TEST-API.md` для примеров тестирования.

---

## 🎯 Краткий чеклист

- [ ] `stop.bat` - остановил сервер
- [ ] Подождал 5 секунд
- [ ] `git pull` - получил обновления
- [ ] `install-musetalk.ps1` - установил MuseTalk
- [ ] `start.bat` - запустил сервер
- [ ] `curl http://localhost:8001/health` - проверил статус
- [ ] `musetalk: true` - всё работает! 🎉

---

## 📥 Альтернатива: Ручная загрузка моделей

Если автоматическая загрузка не работает или очень медленная, можно скачать модели вручную:

**Смотрите подробную инструкцию:** [MANUAL-DOWNLOAD-MUSETALK.md](MANUAL-DOWNLOAD-MUSETALK.md)

**Краткая версия:**
1. Откройте: https://huggingface.co/TMElyralab/MuseTalk
2. Скачайте все файлы (~2GB)
3. Поместите в `C:\dev\avatar-factory\gpu-worker\MuseTalk\models\`
4. Запустите `start.bat`

---

## 🐛 Если всё ещё ошибка "Access Denied"

### Вариант 1: Жесткая остановка
```cmd
taskkill /F /IM python.exe
timeout /t 5
powershell -ExecutionPolicy Bypass -File install-musetalk.ps1
```

### Вариант 2: Перезагрузка ПК
1. Перезагрузите Windows
2. НЕ запускайте сервер
3. Сразу запустите `install-musetalk.ps1`

---

**После успешной установки этот файл можно удалить.** 🚀
