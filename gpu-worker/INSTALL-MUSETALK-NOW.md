# 🚨 Как установить MuseTalk СЕЙЧАС

## Проблема
```
ERROR: Could not install packages due to an OSError: [WinError 5] Отказано в доступе
Check the permissions.
```

**Причина:** Сервер запущен и держит файлы OpenCV/PyTorch. Нужно остановить перед установкой.

---

## ✅ Решение (3 команды)

### 1️⃣ Остановите сервер
```cmd
cd C:\dev\avatar-factory\gpu-worker
stop.bat
```

Подождите **5 секунд** чтобы все процессы завершились.

### 2️⃣ Pull обновленный код
```cmd
git pull
```

Обновленный `install-musetalk.ps1` теперь автоматически проверяет что сервер остановлен.

### 3️⃣ Установите MuseTalk
```powershell
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
