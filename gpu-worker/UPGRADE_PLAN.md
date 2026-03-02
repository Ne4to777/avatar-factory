# 🛡️ Безопасный план добавления новых моделей

> **КРИТИЧНО:** Вы потратили 2 дня на настройку зависимостей.  
> Этот план минимизирует риск конфликтов.

---

## 📊 Текущий стек (из requirements.txt)

```
PyTorch: 2.1.0 + CUDA 11.8
NumPy: 1.26.4 (не 2.x!)
OpenCV: <4.10.0
transformers: 4.36.2
diffusers: 0.25.1
accelerate: 0.25.0
```

---

## 🎯 План: 3 безопасных этапа

### **ЭТАП 1: Whisper STT (БЕЗОПАСНО ✅)**

**Что можно добавить СЕЙЧАС без конфликтов:**
- ✅ Whisper Large V3
- ✅ Работает с transformers 4.36.2
- ✅ Работает с PyTorch 2.1.0
- ⚠️  Требует NumPy 1.x (у вас 1.26.4 - ОК!)

**Установка:**
```bash
# В вашем venv на Windows
cd gpu-worker
venv\Scripts\activate

# Установить Whisper
pip install openai-whisper

# Проверка (должно быть без ошибок)
python -c "import whisper; print('Whisper OK')"
```

**Новый endpoint:**
```python
# /api/stt - Speech-to-Text
POST /api/stt
- audio: файл (wav/mp3/m4a)
- language: "ru" (опционально)
- model: "large-v3" (по умолчанию)

Response: {"text": "распознанный текст"}
```

---

### **ЭТАП 2: Text LLM - ВЫБОР СТРАТЕГИИ**

У вас 3 варианта:

#### **Вариант A: Mistral 7B (БЕЗОПАСНО ✅)**
- ✅ Работает с transformers 4.36.2
- ✅ Влезет в 12GB VRAM
- ✅ Быстрый (8-15 tok/s на 4070 Ti)
- ⚠️  Качество ниже чем Llama 3.3

**Установка:**
```bash
# Уже есть transformers 4.36.2 - ничего не нужно!

# Тест
python -c "from transformers import AutoModelForCausalLM; print('Mistral OK')"
```

**Использование:**
```python
# models/mistral_7b.py
from transformers import AutoModelForCausalLM, AutoTokenizer

model = AutoModelForCausalLM.from_pretrained(
    "mistralai/Mistral-7B-Instruct-v0.2",
    torch_dtype=torch.float16,
    device_map="auto"
)
```

#### **Вариант B: Llama 3.3 8B (ТРЕБУЕТ АПГРЕЙД ⚠️)**
- ❌ Требует transformers ≥4.43.0
- ✅ Лучше качество
- ⚠️  РИСК конфликта с MuseTalk/SDXL

**Апгрейд (ТЕСТИРОВАТЬ ОТДЕЛЬНО!):**
```bash
# 1. Создать backup
xcopy venv venv-backup /E /I /H /Y

# 2. Апгрейд transformers
pip install transformers==4.43.0 accelerate==0.26.0

# 3. КРИТИЧНО: Протестировать СТАРЫЕ модели!
python test_existing_models.py

# Если MuseTalk/SDXL/Silero сломались → откатить:
rmdir /S /Q venv
xcopy venv-backup venv /E /I /H /Y
```

#### **Вариант C: API fallback (САМОЕ БЕЗОПАСНОЕ ✅)**
- ✅ Ноль риска для локальных моделей
- ✅ Лучшее качество (Claude/GPT-4)
- ⚠️  Платно (~2₽ за запрос)

**Установка:**
```bash
pip install openai anthropic
```

**Endpoint с гибридной логикой:**
```python
# /api/improve-text
# Если simple=true → Mistral локально (бесплатно)
# Если simple=false → Claude API (платно, качество)
```

---

### **ЭТАП 3: Video - БЕЗ ЛОКАЛЬНОЙ ГЕНЕРАЦИИ**

**Реальность для RTX 4070 Ti (12GB):**
- ❌ AnimateDiff: нужно 16GB+ VRAM
- ❌ CogVideoX: нужно 24GB+ VRAM
- ✅ Stable Video Diffusion 1.0: **может влезть** (14GB, но с 8-bit quantization)

**Рекомендация: 100% API для видео**

Причины:
1. Локальная генерация видео на 12GB - медленная (5-10 мин за 3 сек видео)
2. Качество API намного выше
3. Cost-effective: 45₽ за видео vs 2 часа вашего времени

**Интеграция с Polza.ai:**
```bash
pip install httpx  # Уже должен быть
```

**Endpoint:**
```python
# /api/generate-video
POST /api/generate-video
- prompt: "описание"
- keyframe: файл изображения (опционально)
- provider: "polza" | "local-preview"

# local-preview → SVD для быстрого превью (низкое качество)
# polza → Veo/Kling через API (высокое качество)
```

---

## 🔒 Безопасная последовательность установки

### День 1: Whisper STT (1-2 часа)

```bash
# 1. Backup текущего venv
cd gpu-worker
tar -czf venv-backup-$(date +%Y%m%d).tar.gz venv/  # Linux/Mac
# Windows: используйте 7-Zip или WinRAR

# 2. Установить Whisper
venv\Scripts\activate
pip install openai-whisper

# 3. Тест
python -c "import whisper; model = whisper.load_model('base'); print('OK')"

# 4. Добавить endpoint в server.py
# (код ниже)

# 5. Тест API
curl -X POST http://localhost:8001/api/stt \
  -H "x-api-key: your-key" \
  -F "audio=@test.wav"

# 6. Если всё работает → commit
git add .
git commit -m "feat: add Whisper STT endpoint"
```

### День 2: Text LLM (2-4 часа)

**Если выбрали Mistral (безопасно):**
```bash
# 1. Ничего не устанавливать (transformers 4.36.2 уже есть)

# 2. Добавить endpoint
# (код ниже)

# 3. Тест загрузки модели
python test_mistral.py

# 4. Если OK → добавить в server.py
```

**Если выбрали Llama 3.3 (рискованно):**
```bash
# 1. ОБЯЗАТЕЛЬНО: полный backup
copy venv venv-backup-full

# 2. Апгрейд в ТЕСТОВОМ окне cmd
pip install transformers==4.43.0

# 3. КРИТИЧНО: Тест ВСЕХ моделей
python test_all_models.py
# - MuseTalk работает?
# - SDXL работает?
# - Silero TTS работает?

# 4. Если хоть одна сломалась → ОТКАТ НЕМЕДЛЕННО
rmdir /S /Q venv
copy venv-backup-full venv

# 5. Если всё работает → добавить Llama endpoint
```

### День 3: Video API Integration (1-2 часа)

```bash
# 1. Установить HTTP клиент (если нет)
pip install httpx

# 2. Добавить Polza.ai client
# (код ниже)

# 3. Тест
python test_polza_api.py

# 4. Добавить endpoint в server.py
```

---

## 📝 Код для добавления в server.py

### 1. Whisper STT Endpoint

```python
# Добавить в globals (после tts_model)
whisper_model = None

# В load_models() добавить:
try:
    logger.info("Loading Whisper Large V3...")
    import whisper
    whisper_model = whisper.load_model("large-v3", device="cuda")
    logger.info("Whisper ready")
except Exception as e:
    logger.warning(f"Whisper failed: {e}")
    whisper_model = None

# Новый endpoint:
@app.post("/api/stt")
async def speech_to_text(
    audio: UploadFile = File(...),
    language: str = Query("ru", description="Language code"),
    x_api_key: str = Header()
):
    """Speech-to-Text (Whisper Large V3)"""
    verify_api_key(x_api_key)
    
    if not whisper_model:
        raise HTTPException(status_code=503, detail="Whisper not loaded")
    
    try:
        # Сохранить аудио
        audio_path = TEMP_DIR / f"stt_{os.urandom(8).hex()}{Path(audio.filename).suffix}"
        with open(audio_path, "wb") as f:
            f.write(await audio.read())
        
        # Распознать
        result = whisper_model.transcribe(
            str(audio_path),
            language=language,
            fp16=True  # Используем FP16 на GPU
        )
        
        # Очистка
        audio_path.unlink()
        
        return {
            "text": result["text"],
            "language": result["language"],
            "segments": result["segments"]  # Timestamps
        }
        
    except Exception as e:
        logger.error(f"STT failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))
```

### 2. Text Improvement (Mistral)

```python
# Добавить в globals
text_llm = None

# В load_models():
try:
    logger.info("Loading Mistral 7B...")
    from transformers import AutoModelForCausalLM, AutoTokenizer
    
    text_llm = {
        "model": AutoModelForCausalLM.from_pretrained(
            "mistralai/Mistral-7B-Instruct-v0.2",
            torch_dtype=torch.float16,
            device_map="auto"
        ),
        "tokenizer": AutoTokenizer.from_pretrained(
            "mistralai/Mistral-7B-Instruct-v0.2"
        )
    }
    logger.info("Mistral 7B ready")
except Exception as e:
    logger.warning(f"Mistral failed: {e}")
    text_llm = None

# Endpoint:
@app.post("/api/improve-text")
async def improve_text(
    text: str = Query(..., description="Text to improve"),
    style: str = Query("professional", description="Style: professional|casual|technical"),
    x_api_key: str = Header()
):
    """Улучшение текста (Mistral 7B)"""
    verify_api_key(x_api_key)
    
    if not text_llm:
        raise HTTPException(status_code=503, detail="LLM not loaded")
    
    try:
        # Промт
        prompt = f"""[INST] Улучши этот текст для {style} стиля.
Сделай его более понятным и структурированным.

Исходный текст:
{text}

Улучшенный текст: [/INST]"""
        
        # Генерация
        inputs = text_llm["tokenizer"](prompt, return_tensors="pt").to("cuda")
        outputs = text_llm["model"].generate(
            **inputs,
            max_new_tokens=512,
            temperature=0.7,
            do_sample=True
        )
        
        result = text_llm["tokenizer"].decode(outputs[0], skip_special_tokens=True)
        
        # Извлечь только ответ (после [/INST])
        improved = result.split("[/INST]")[-1].strip()
        
        return {"improved_text": improved}
        
    except Exception as e:
        logger.error(f"Text improvement failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))
```

### 3. Polza.ai Integration

```python
# В начале файла
import httpx
import os

POLZA_API_KEY = os.getenv("POLZA_API_KEY", "")
POLZA_BASE_URL = "https://api.polza.ai/v1"

# Endpoint:
@app.post("/api/generate-video-api")
async def generate_video_api(
    prompt: str = Query(..., description="Video prompt"),
    keyframe: Optional[UploadFile] = File(None),
    model: str = Query("veo-fast", description="veo-fast|kling"),
    x_api_key: str = Header()
):
    """Генерация видео через Polza.ai API"""
    verify_api_key(x_api_key)
    
    if not POLZA_API_KEY:
        raise HTTPException(status_code=503, detail="POLZA_API_KEY not configured")
    
    try:
        # Подготовка запроса
        model_mapping = {
            "veo-fast": "google/veo3_fast",
            "kling": "kling/v2.6-motion-control",
        }
        
        # Если есть keyframe → image-to-video
        if keyframe:
            # Сохранить keyframe
            img_path = TEMP_DIR / f"key_{os.urandom(8).hex()}.png"
            with open(img_path, "wb") as f:
                f.write(await keyframe.read())
            
            # TODO: Загрузить на Polza storage или передать base64
            # (см. документацию Polza.ai)
        
        # Запрос к API
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{POLZA_BASE_URL}/video/generate",
                headers={"Authorization": f"Bearer {POLZA_API_KEY}"},
                json={
                    "model": model_mapping[model],
                    "prompt": prompt,
                    # ... параметры из документации Polza.ai
                },
                timeout=300.0  # 5 минут
            )
            response.raise_for_status()
            
            result = response.json()
            
            return {
                "status": "processing",
                "task_id": result.get("task_id"),
                "estimated_time": result.get("estimated_time"),
                "cost_estimate": result.get("cost_estimate")
            }
    
    except Exception as e:
        logger.error(f"Video API failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))
```

---

## ⚠️ КРИТИЧНЫЕ правила

1. **ВСЕГДА делать backup перед апгрейдом**
2. **ТЕСТИРОВАТЬ старые модели после каждого изменения**
3. **НЕ апгрейдить PyTorch** (останется 2.1.0)
4. **НЕ апгрейдить NumPy до 2.x** (сломает OpenCV)
5. **Документировать каждое изменение**

---

## 📊 Рекомендуемая последовательность

### ✅ БЕЗОПАСНЫЙ ПУТЬ (рекомендую):
```
День 1: Whisper STT (локально)
День 2: Mistral 7B (локально, без апгрейда)
День 3: Polza.ai API (видео)
День 4: Hybrid pipeline (оркестрация)
День 5: Тестирование + документация
```

**Результат:**
- STT: бесплатно, локально
- Text: бесплатно, локально (Mistral)
- Image: уже есть (SDXL)
- Video: через API (~45₽)
- **Риск конфликтов: МИНИМАЛЬНЫЙ**

### ⚠️ РИСКОВАННЫЙ ПУТЬ (только если нужен Llama 3.3):
```
День 1: Полный backup venv
День 2: Тестовый venv + апгрейд transformers
День 3: Тест ВСЕХ старых моделей
День 4: Если OK → применить к prod venv
День 5: Если НЕТ → откат + использовать Mistral
```

---

## 🎯 Мой вердикт

**Начните с БЕЗОПАСНОГО ПУТИ:**
- Whisper + Mistral + Polza API
- Работает с текущими зависимостями
- Ноль риска сломать существующие модели
- Качество достаточное для 90% задач

**Llama 3.3 - только если:**
- Вам критично нужно лучшее качество текста
- Вы готовы потратить 1-2 дня на тестирование
- У вас есть время на откат при проблемах

---

## 📞 Следующий шаг

Скажите, какой путь выбираем:
1. **БЕЗОПАСНЫЙ** (Whisper + Mistral + API)
2. **РИСКОВАННЫЙ** (апгрейд для Llama 3.3)
3. **ГИБРИДНЫЙ** (Mistral локально + Claude API для финала)

И я начну реализацию прямо сейчас! 🚀
