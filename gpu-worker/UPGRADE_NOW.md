# 🚀 Инструкция по обновлению (Минорные версии)

## Быстрый старт (15-20 минут)

### 1️⃣ Запуск обновления

```bash
cd gpu-worker
safe-upgrade.bat
```

Скрипт автоматически:
- ✅ Создаст backup venv
- ✅ Проверит текущее состояние
- ✅ Обновит зависимости
- ✅ Протестирует ВСЕ модели
- ✅ Откатит при ошибках

**Время:** ~10 минут (зависит от скорости интернета)

---

### 2️⃣ Что обновляется

| Пакет | Было | Станет | Изменение |
|-------|------|--------|-----------|
| transformers | 4.36.2 | 4.45.0 | Минор (Llama 3.3 support) |
| diffusers | 0.25.1 | 0.30.3 | Минор (AnimateDiff, SVD) |
| accelerate | 0.25.0 | 0.26.1 | Минор (память) |
| openai-whisper | - | latest | **НОВЫЙ** (STT) |
| tiktoken | - | latest | **НОВЫЙ** (Whisper dep) |

**НЕ меняется (критично!):**
- ❌ PyTorch 2.1.0 - БЕЗ ИЗМЕНЕНИЙ
- ❌ NumPy 1.26.4 - БЕЗ ИЗМЕНЕНИЙ
- ❌ OpenCV <4.10.0 - БЕЗ ИЗМЕНЕНИЙ

---

### 3️⃣ После обновления

```bash
# Перезапустить сервер
cd gpu-worker
venv\Scripts\activate
python server.py
```

Проверить:
```bash
curl http://localhost:8001/health
```

---

## 🎯 Следующие шаги (добавление новых endpoints)

Я создам pull request с:
1. ✅ Whisper STT endpoint (`/api/stt`)
2. ✅ Text improvement endpoint (`/api/improve-text`)
3. ✅ Video API integration (`/api/generate-video-api`)
4. ✅ Hybrid pipeline (`/api/pipeline`)
5. ✅ Cost tracking (`/api/estimate-cost`)

Или добавляем по одному и тестируем?

---

## 🔄 Если что-то пошло не так

Скрипт автоматически откатит изменения.

**Ручной откат:**
```bash
cd gpu-worker

# Удалить сломанный venv
rmdir /S /Q venv

# Восстановить backup (имя будет venv-backup-YYYYMMDD-HHMMSS)
xcopy venv-backup-YYYYMMDD-HHMMSS venv /E /I /H /Y

# Проверка
venv\Scripts\activate
python test_existing_models.py
```

---

## 📊 Ожидаемый результат

После успешного обновления:
```
✅ Все существующие модели работают
✅ Whisper установлен и готов
✅ transformers поддерживает Llama 3.3
✅ diffusers поддерживает AnimateDiff
✅ Backup сохранен
```

Готово к добавлению новых endpoints! 🎉
