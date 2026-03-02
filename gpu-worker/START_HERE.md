# 🚀 START HERE - Avatar Factory v2.0

## ⚡ Quick Start (3 команды)

```bash
# 1. Обновление (10-15 минут)
cd gpu-worker
safe-upgrade.bat

# 2. Настройка API ключа
copy .env.example .env
notepad .env  # Добавьте ваш GPU_API_KEY

# 3. Запуск
venv\Scripts\activate
python server.py
```

**Готово!** Сервер работает на `http://localhost:8001`

---

## ✅ Что нового в v2.0

### 🎙️ Speech-to-Text (Whisper Large V3)
```bash
curl -X POST http://localhost:8001/api/stt \
  -H "x-api-key: your-key" \
  -F "audio=@recording.wav"
```

### ✍️ Text Improvement (Mistral 7B)
```bash
curl -X POST "http://localhost:8001/api/improve-text" \
  -H "x-api-key: your-key" \
  -G --data-urlencode "text=Ваш текст"
```

### 🎬 Video Generation (Polza.ai API)
```bash
curl -X POST "http://localhost:8001/api/generate-video-api" \
  -H "x-api-key: your-key" \
  -F "prompt=Описание видео"
```

### 🔄 Hybrid Pipeline (всё вместе)
```bash
curl -X POST http://localhost:8001/api/pipeline \
  -H "x-api-key: your-key" \
  -F "audio=@recording.wav"
```

---

## 💰 Экономия

**До обновления:** 2095₽/месяц (30 видео)  
**После обновления:** 1350₽/месяц (30 видео)  
**Экономия:** 745₽/месяц (~35%)

**Как:** Локально STT, Text, Images. API только для Video.

---

## 📚 Документация

| Файл | Описание |
|------|----------|
| **API_REFERENCE.md** | Полная документация API (все endpoints) |
| **DEPLOYMENT_SUMMARY.md** | Что сделано, как запустить, troubleshooting |
| **READY_TO_UPGRADE.md** | Детальная инструкция по обновлению |
| **QUICK_COMMANDS.md** | Команды для диагностики и работы |
| `http://localhost:8001/docs` | Swagger UI (интерактивная документация) |

---

## 🔧 Troubleshooting

### Сервер не запускается?
```bash
# Проверить логи
type logs\server.log

# Тест моделей
python test_existing_models.py
```

### Out of Memory?
```bash
# В server.py закомментируйте строку ~280:
# text_llm = ...
# Это освободит 7GB VRAM
```

### Нужен откат?
```bash
rmdir /S /Q venv
xcopy venv-backup-YYYYMMDD venv /E /I /H /Y
```

---

## 📞 Помощь

- **Health check:** `http://localhost:8001/health`
- **Swagger docs:** `http://localhost:8001/docs`
- **Logs:** `logs/server.log`
- **Tests:** `test-new-endpoints.bat`

---

## 🎯 Следующие шаги

1. ✅ Запустите `safe-upgrade.bat`
2. ✅ Настройте `.env` (API ключи)
3. ✅ Запустите сервер
4. ✅ Протестируйте: `test-new-endpoints.bat`
5. ✅ Прочитайте `API_REFERENCE.md`
6. ✅ Попробуйте `/api/pipeline`

**Все готово к production! 🎉**
