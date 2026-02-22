# Quick Fix - Решение текущих проблем

## Проблема 1: Silero TTS не загружается

**Ошибка:**
```
FileNotFoundError: C:\Users\ne4to/.cache\torch\hub\snakers4_silero-models_master\hubconf.py
```

**Причина:** Поврежденный кеш torch.hub

**Решение (автоматическое):**
```cmd
fix-and-restart.bat
```

Этот скрипт:
1. Остановит сервер
2. Очистит поврежденный кеш Silero TTS
3. Очистит временные файлы
4. Перезапустит сервер с обновленным кодом

---

## Проблема 2: Старый код (требуется перезагрузка)

**Симптом:** Лог показывает старые названия моделей вместо `MuseTalk`

**Причина:** Сервер использует код до последних обновлений

**Решение:**
```cmd
stop.bat
start.bat
```

Или используйте `fix-and-restart.bat` (делает всё автоматически).

---

## Проверка после исправления

### 1. Проверьте что сервер запущен:
```bash
curl http://localhost:8001/health
```

### 2. Проверьте что все модели загружены:
```json
{
  "models": {
    "musetalk": false,  // ← Пока false, нужна установка
    "stable_diffusion": true,
    "silero_tts": true  // ← Должно быть true после fix
  }
}
```

### 3. Проверьте логи:
```cmd
type logs\service.log | findstr "STARTUP COMPLETE" /A:-3
```

Должно быть:
```
[INFO] STARTUP COMPLETE!
[INFO] MuseTalk (Lip-sync): DISABLED  ← Нормально, пока не установили
[INFO] Stable Diffusion XL: OK
[INFO] Silero TTS: OK  ← Должно быть OK
```

---

## Следующие шаги

### Если Silero TTS = OK и Stable Diffusion = OK

Отлично! Теперь установите MuseTalk:

```powershell
powershell -ExecutionPolicy Bypass -File install-musetalk.ps1
```

После установки перезапустите сервер:
```cmd
stop.bat
start.bat
```

Проверьте что `musetalk: true`:
```bash
curl http://localhost:8001/health
```

### Если Silero TTS всё ещё DISABLED

**Ручная очистка кеша:**
```cmd
rd /s /q "%USERPROFILE%\.cache\torch\hub\snakers4_silero-models_master"
```

**Перезапуск:**
```cmd
stop.bat
start.bat
```

**Проверка Python окружения:**
```cmd
venv\Scripts\python.exe -c "import torch; print('PyTorch:', torch.__version__); print('CUDA:', torch.cuda.is_available())"
```

Должно вывести:
```
PyTorch: 2.7.0+cu118
CUDA: True
```

---

## Альтернативное решение (если fix-and-restart.bat не помог)

### 1. Полная очистка и переустановка

```cmd
REM Остановка
stop.bat

REM Очистка кеша
rd /s /q "%USERPROFILE%\.cache\torch"
rd /s /q "temp"

REM Переустановка зависимостей
venv\Scripts\python.exe -m pip install --force-reinstall torch==2.7.0+cu118 torchvision==0.22.0+cu118 torchaudio==2.7.0+cu118 --index-url https://download.pytorch.org/whl/cu118

REM Скачивание моделей заново
venv\Scripts\python.exe download_models.py

REM Запуск
start.bat
```

### 2. Проверка логов в реальном времени

```powershell
Get-Content logs\service.log -Wait -Tail 30
```

Или:
```cmd
tail -f logs\service.log
```

---

## 🎯 Быстрый чеклист

- [ ] Запустил `fix-and-restart.bat`
- [ ] Проверил `/health` - silero_tts = true
- [ ] Запустил `install-musetalk.ps1`
- [ ] Перезапустил сервер
- [ ] Проверил `/health` - musetalk = true
- [ ] Протестировал API (см. TEST-API.md)

---

## 💡 Подсказка

Если хотите видеть логи в реальном времени при запуске:

```cmd
REM Вместо start.bat используйте:
venv\Scripts\python.exe server.py
```

Это запустит сервер в текущем окне и вы увидите все логи напрямую (не через service).

Для остановки: `Ctrl+C`
