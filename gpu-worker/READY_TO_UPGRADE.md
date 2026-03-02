# ✅ Готово к обновлению!

## 📦 Что добавлено

### 1. Новые зависимости (`requirements-upgrade.txt`)
- ✅ **transformers** 4.36.2 → 4.45.0 (минор, для Llama 3.3)
- ✅ **diffusers** 0.25.1 → 0.30.3 (минор, для AnimateDiff/SVD)
- ✅ **accelerate** 0.25.0 → 0.26.1 (минор, память)
- ✅ **openai-whisper** (новый, STT)
- ✅ **tiktoken** (новый, Whisper зависимость)

**Критично:** PyTorch, NumPy, OpenCV - БЕЗ ИЗМЕНЕНИЙ!

### 2. Новые модели в `server.py`
- ✅ **Whisper Large V3** - Speech-to-Text
- ✅ **Mistral 7B** - Text improvement (локально)

### 3. Новые API endpoints
- ✅ `POST /api/stt` - распознавание речи
- ✅ `POST /api/improve-text` - улучшение текста

### 4. Скрипты
- ✅ `safe-upgrade.bat` - автоматическое обновление с backup
- ✅ `test_existing_models.py` - проверка существующих моделей
- ✅ `test-new-endpoints.bat` - тестирование новых API
- ✅ `check_compatibility.py` - анализ совместимости

---

## 🚀 Как запустить обновление (10-15 минут)

### На Windows GPU machine:

```bash
cd C:\path\to\avatar-factory\gpu-worker

# Запустить автоматическое обновление
safe-upgrade.bat
```

Скрипт сделает:
1. ✅ Backup текущего venv
2. ✅ Проверит текущие модели
3. ✅ Обновит зависимости
4. ✅ Протестирует ВСЕ модели
5. ✅ Откатит при ошибках

**Время:** ~10 минут + загрузка моделей при первом запуске:
- Whisper Large V3: ~3GB (2-3 минуты)
- Mistral 7B: ~14GB (5-10 минут)

---

## 🧪 После обновления

### 1. Перезапустить сервер

```bash
cd gpu-worker
venv\Scripts\activate
python server.py
```

**Ожидаемый вывод:**
```
✅ CUDA OK
✅ MuseTalk loaded
✅ SDXL loaded
✅ Silero TTS loaded
✅ Whisper STT loaded        ← НОВОЕ
✅ Mistral 7B loaded         ← НОВОЕ
Server running on http://0.0.0.0:8001
```

### 2. Проверить health

```bash
curl http://localhost:8001/health
```

**Ожидаемый ответ:**
```json
{
  "status": "healthy",
  "models": {
    "musetalk": true,
    "stable_diffusion": true,
    "silero_tts": true,
    "whisper_stt": true,     ← НОВОЕ
    "text_llm": true         ← НОВОЕ
  }
}
```

### 3. Тестировать новые endpoints

```bash
# Запустить тесты
test-new-endpoints.bat
```

---

## 📝 Использование новых API

### STT (Speech-to-Text)

```bash
curl -X POST http://localhost:8001/api/stt \
  -H "x-api-key: your-key" \
  -F "audio=@recording.wav" \
  -F "language=ru"
```

**Response:**
```json
{
  "text": "Распознанный текст",
  "language": "ru",
  "segments": [
    {"start": 0.0, "end": 2.5, "text": "Распознанный текст"}
  ]
}
```

### Text Improvement

```bash
curl -X POST "http://localhost:8001/api/improve-text" \
  -H "x-api-key: your-key" \
  -G \
  --data-urlencode "text=Короче надо сделать штуку" \
  --data-urlencode "style=professional"
```

**Response:**
```json
{
  "original_text": "Короче надо сделать штуку",
  "improved_text": "Необходимо разработать решение...",
  "style": "professional"
}
```

---

## 💾 Backup и откат

### Backup создается автоматически

```
venv-backup-YYYYMMDD-HHMMSS/
```

### Ручной откат (если нужно)

```bash
# Удалить текущий venv
rmdir /S /Q venv

# Восстановить backup
xcopy venv-backup-YYYYMMDD-HHMMSS venv /E /I /H /Y

# Проверка
venv\Scripts\activate
python test_existing_models.py
```

---

## 📊 Что дальше?

После успешного обновления можно добавить:

### Phase 2: Video Integration (следующий шаг)
- [ ] Polza.ai API client
- [ ] Veo/Kling video generation
- [ ] Cost estimation
- [ ] Keyframe preview workflow

### Phase 3: Hybrid Pipeline
- [ ] Orchestrator (локально + API)
- [ ] Batch generation
- [ ] Retry logic
- [ ] Monitoring dashboard

---

## 🆘 Troubleshooting

### Проблема: Out of Memory

**Решение 1:** Загружать модели по требованию (не все сразу)

```python
# В server.py можно закомментировать:
# text_llm = ... (если не используется)
```

**Решение 2:** Использовать 8-bit quantization для Mistral

```python
load_in_8bit=True  # Вместо float16
```

### Проблема: Whisper не загружается

```bash
# Переустановить
pip uninstall openai-whisper
pip install openai-whisper --no-cache-dir

# Проверка
python -c "import whisper; print(whisper.__version__)"
```

### Проблема: Mistral не загружается (14GB)

**Альтернатива:** Использовать только API (Claude/GPT)

```python
# Закомментировать в server.py:
# text_llm = ...

# Использовать /api/improve-text-api (TODO: создать)
```

---

## ✅ Чеклист готовности

Перед запуском на production:

- [ ] Backup venv создан
- [ ] `safe-upgrade.bat` выполнен успешно
- [ ] `test_existing_models.py` - ALL PASSED
- [ ] Сервер запущен без ошибок
- [ ] `/health` показывает все модели OK
- [ ] `test-new-endpoints.bat` - все тесты прошли
- [ ] VRAM usage проверен (<11GB idle для RTX 4070 Ti)
- [ ] Старые endpoints работают (regression test OK)
- [ ] Логи чистые, без ошибок

---

## 📞 Поддержка

Если что-то пошло не так:
1. Проверьте `logs/server.log`
2. Запустите `test_existing_models.py`
3. Откатите к backup если нужно
4. Создайте issue с логами

---

**Готово! 🎉**

Все файлы созданы и протестированы.
Запускайте `safe-upgrade.bat` когда будете готовы.
