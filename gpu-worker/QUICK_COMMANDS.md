# ⚡ Quick Commands Reference

Быстрые команды для работы с Avatar Factory GPU Worker

---

## 🔍 Проверки ПЕРЕД установкой

```bash
# 1. Проверка совместимости зависимостей
python check_compatibility.py

# 2. Проверка текущих версий
pip list | findstr "torch transformers diffusers numpy opencv"

# 3. Проверка VRAM
nvidia-smi
```

---

## 💾 Backup ПЕРЕД изменениями

```bash
# Полный backup venv (рекомендуется)
# Время: ~2-5 минут, Размер: ~5-10 GB
cd gpu-worker

# Windows
xcopy venv venv-backup-%date:~-4,4%%date:~-10,2%%date:~-7,2% /E /I /H /Y

# Или архив (экономит место)
tar -czf venv-backup-%date%.tar.gz venv/
```

---

## 🧪 Тестирование ПОСЛЕ изменений

```bash
# КРИТИЧНО! Запускать после ЛЮБОГО изменения зависимостей
cd gpu-worker
venv\Scripts\activate
python test_existing_models.py

# Ожидаемый результат: ALL TESTS PASSED
# Если FAIL → немедленный откат!
```

---

## 🔄 Откат при проблемах

```bash
# БЫСТРЫЙ откат из backup
cd gpu-worker

# Удалить сломанный venv
rmdir /S /Q venv

# Восстановить из backup
xcopy venv-backup-YYYYMMDD venv /E /I /H /Y

# Или из архива
tar -xzf venv-backup-YYYYMMDD.tar.gz

# Проверка
python test_existing_models.py
```

---

## 📦 Установка новых зависимостей

### Whisper STT (безопасно)

```bash
cd gpu-worker
venv\Scripts\activate

# Установка
pip install openai-whisper

# Проверка
python -c "import whisper; print('Whisper:', whisper.__version__)"

# Тест
python test_existing_models.py
```

### Mistral 7B (безопасно, без новых пакетов)

```bash
# Ничего устанавливать не нужно!
# transformers 4.36.2 уже поддерживает Mistral

# Проверка
python -c "from transformers import AutoModelForCausalLM; print('Mistral OK')"

# Тест загрузки (НЕ обязательно, загружает ~14GB)
# python -c "from transformers import AutoModelForCausalLM; AutoModelForCausalLM.from_pretrained('mistralai/Mistral-7B-Instruct-v0.2')"
```

### Polza.ai API Client (безопасно)

```bash
# httpx уже должен быть установлен (зависимость FastAPI)
pip list | findstr httpx

# Если нет:
pip install httpx

# Добавить в .env
echo POLZA_API_KEY=your-key-here >> .env
```

---

## 🚀 Запуск сервера

```bash
cd gpu-worker

# Активация venv
venv\Scripts\activate

# Проверка переменных окружения
type .env

# Запуск
python server.py

# Ожидаемый вывод:
# ✓ CUDA OK
# ✓ MuseTalk loaded
# ✓ SDXL loaded
# ✓ Silero TTS loaded
# Server running on http://0.0.0.0:8001
```

---

## 🔧 Тестирование API

```bash
# 1. Health check
curl http://localhost:8001/health

# 2. STT (после добавления Whisper)
curl -X POST http://localhost:8001/api/stt \
  -H "x-api-key: your-secret-gpu-key-change-this" \
  -F "audio=@test.wav"

# 3. Text improvement (после добавления Mistral)
curl -X POST "http://localhost:8001/api/improve-text?text=Привет мир&style=professional" \
  -H "x-api-key: your-secret-gpu-key-change-this"

# 4. Existing TTS
curl -X POST "http://localhost:8001/api/tts?text=Тест&speaker=xenia" \
  -H "x-api-key: your-secret-gpu-key-change-this" \
  --output test_output.wav

# 5. Existing background
curl -X POST "http://localhost:8001/api/generate-background?prompt=test" \
  -H "x-api-key: your-secret-gpu-key-change-this" \
  --output test_bg.png
```

---

## 📊 Мониторинг GPU

```bash
# Непрерывный мониторинг
nvidia-smi -l 1

# Или более детальный
nvidia-smi dmon -s mu

# Только VRAM
nvidia-smi --query-gpu=memory.used,memory.total --format=csv -l 1
```

---

## 🐛 Диагностика проблем

### Проблема: CUDA not available

```bash
# Проверка драйверов
nvidia-smi

# Проверка PyTorch
python -c "import torch; print('CUDA:', torch.cuda.is_available()); print('Version:', torch.version.cuda)"

# Переустановка PyTorch (КРАЙНЯЯ МЕРА!)
pip uninstall torch torchvision torchaudio
pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu118
```

### Проблема: Out of memory

```bash
# Очистка VRAM
python -c "import torch; torch.cuda.empty_cache(); print('Cleared')"

# Перезапуск сервера
# Ctrl+C в окне сервера
python server.py

# Уменьшение batch_size в запросах
# lipsync: batch_size=4 вместо 8
# SDXL: num_inference_steps=20 вместо 30
```

### Проблема: ModuleNotFoundError

```bash
# Проверка venv активирован
where python
# Должен показать: gpu-worker\venv\Scripts\python.exe

# Переустановка зависимостей
pip install -r requirements.txt

# Если не помогает → откат к backup
```

---

## 📦 Обновление зависимостей (ОСТОРОЖНО!)

```bash
# ТОЛЬКО если вы понимаете риски!

# 1. BACKUP обязательно!
xcopy venv venv-backup-upgrade /E /I /H /Y

# 2. Апгрейд конкретного пакета
pip install transformers==4.43.0

# 3. НЕМЕДЛЕННО тестировать
python test_existing_models.py

# 4. Если упало → ОТКАТ
rmdir /S /Q venv
xcopy venv-backup-upgrade venv /E /I /H /Y
```

---

## 🧹 Очистка

```bash
# Очистка временных файлов
curl -X POST http://localhost:8001/api/cleanup \
  -H "x-api-key: your-secret-gpu-key-change-this"

# Очистка кеша HuggingFace (~50GB)
# ВНИМАНИЕ: Модели будут загружены заново при следующем запуске!
rmdir /S /Q %USERPROFILE%\.cache\huggingface

# Очистка кеша torch.hub
rmdir /S /Q %USERPROFILE%\.cache\torch

# Очистка pip кеша
pip cache purge
```

---

## 📝 Логи

```bash
# Просмотр логов сервера
cd gpu-worker
type logs\server.log

# Последние 50 строк
powershell Get-Content logs\server.log -Tail 50

# Мониторинг в реальном времени
powershell Get-Content logs\server.log -Wait -Tail 10
```

---

## 🔐 Безопасность

```bash
# Генерация нового API ключа
python -c "import secrets; print('New key:', secrets.token_urlsafe(32))"

# Обновление в .env
notepad .env
# Изменить GPU_API_KEY=...

# Перезапуск сервера для применения
```

---

## 📚 Документация

```bash
# Список всех endpoints
curl http://localhost:8001/docs

# Или открыть в браузере
start http://localhost:8001/docs

# Проверка версии
curl http://localhost:8001/ | jq
```

---

## 🆘 Экстренное восстановление

**Если всё сломалось:**

```bash
# 1. Остановить сервер (Ctrl+C)

# 2. Удалить venv
cd gpu-worker
rmdir /S /Q venv

# 3. Восстановить из ПОСЛЕДНЕГО рабочего backup
xcopy venv-backup-LAST-WORKING venv /E /I /H /Y

# 4. Тест
venv\Scripts\activate
python test_existing_models.py

# 5. Если OK → запуск сервера
python server.py

# 6. Если НЕ OK → полная переустановка
# (см. install-final.bat)
```

---

## ✅ Чеклист перед production

- [ ] Backup venv создан и проверен
- [ ] test_existing_models.py - ALL PASSED
- [ ] Все API endpoints протестированы
- [ ] VRAM usage в норме (<10GB в idle)
- [ ] Логи без ошибок
- [ ] API ключ изменен с дефолтного
- [ ] .env настроен правильно
- [ ] Документация обновлена

---

## 💡 Полезные alias (добавить в PowerShell profile)

```powershell
# Открыть: notepad $PROFILE

# Добавить:
function av-activate { cd C:\path\to\avatar-factory\gpu-worker; .\venv\Scripts\Activate.ps1 }
function av-test { python test_existing_models.py }
function av-run { python server.py }
function av-backup { xcopy venv "venv-backup-$(Get-Date -Format 'yyyyMMdd')" /E /I /H /Y }

# Использование:
# av-activate
# av-test
# av-run
```

---

**Сохраните этот файл!** Пригодится при любых изменениях.
