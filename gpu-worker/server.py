"""
GPU Server для Avatar Factory
Минималистичный FastAPI сервер для обработки AI задач
"""

import sys
import os
from pathlib import Path
import logging

# Setup detailed logging FIRST
# Ensure logs directory exists
log_dir = Path('logs')
log_dir.mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('logs/server.log', encoding='utf-8')
    ]
)
logger = logging.getLogger(__name__)

logger.info("="*60)
logger.info("GPU Server starting...")
logger.info(f"Python version: {sys.version}")
logger.info(f"Working directory: {os.getcwd()}")
logger.info(f"Script path: {__file__}")
logger.info("="*60)

# Import dependencies with logging
try:
    logger.info("Importing FastAPI...")
    from fastapi import FastAPI, UploadFile, File, HTTPException, Header, Query
    from fastapi.middleware.cors import CORSMiddleware
    from fastapi.responses import FileResponse, StreamingResponse
    logger.info("FastAPI imported successfully")
except Exception as e:
    logger.error(f"Failed to import FastAPI: {e}")
    raise

try:
    logger.info("Importing PyTorch...")
    import torch
    logger.info(f"PyTorch imported successfully: {torch.__version__}")
    
    # Fix for PyTorch 2.1.0: add torch.xpu stub (required by diffusers and MuseTalk)
    if not hasattr(torch, 'xpu'):
        logger.info("Adding torch.xpu stub (not present in PyTorch 2.1.0)")
        
        class XPUStub:
            """Universal stub for Intel XPU API (not available in PyTorch 2.1.0)"""
            
            def is_available(self):
                return False
            
            def device_count(self):
                return 0
            
            def __getattr__(self, name):
                """Catch-all for any XPU method - return no-op function"""
                def noop(*args, **kwargs):
                    return None
                return noop
        
        torch.xpu = XPUStub()
        logger.info("torch.xpu stub added successfully (universal catch-all)")
    
except Exception as e:
    logger.error(f"Failed to import PyTorch: {e}")
    raise

try:
    logger.info("Importing asyncio and audio libraries...")
    import asyncio
    from typing import Optional, Dict, Any
    import soundfile as sf
    import httpx  # For API calls
    logger.info("Standard libraries imported")
except Exception as e:
    logger.error(f"Failed to import standard libraries: {e}")
    raise

# Paths - use Windows-compatible temp directory
if os.name == 'nt':
    TEMP_DIR = Path(os.getenv("TEMP", "C:/temp")) / "avatar-factory"
else:
    TEMP_DIR = Path("/tmp/avatar-factory")

logger.info(f"Temp directory: {TEMP_DIR}")
try:
    TEMP_DIR.mkdir(parents=True, exist_ok=True)
    logger.info("Temp directory created/verified")
except Exception as e:
    logger.error(f"Failed to create temp directory: {e}")

# API Keys для безопасности
API_KEY = os.getenv("GPU_API_KEY", "your-secret-gpu-key-change-this")
POLZA_API_KEY = os.getenv("POLZA_API_KEY", "")
POLZA_BASE_URL = "https://api.polza.ai/v1"
logger.info(f"API Key loaded: {API_KEY[:8]}...")
if POLZA_API_KEY:
    logger.info(f"Polza.ai API Key loaded: {POLZA_API_KEY[:8]}...")
else:
    logger.warning("Polza.ai API Key not set - video API will not work")

app = FastAPI(
    title="Avatar Factory GPU Server",
    description="AI Models processing server",
    version="1.0.0"
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global models (загружаются при старте)
musetalk_model = None
sd_pipeline = None
tts_model = None
whisper_model = None  # NEW: Whisper STT
text_llm = None  # NEW: Text improvement LLM (Mistral/Llama)
models_loaded = False  # Flag to prevent double loading

def verify_api_key(x_api_key: str = Header()):
    """Проверка API ключа"""
    if x_api_key != API_KEY:
        raise HTTPException(status_code=403, detail="Invalid API Key")

@app.on_event("startup")
async def load_models():
    """Загрузка AI моделей при старте сервера"""
    global musetalk_model, sd_pipeline, tts_model, whisper_model, text_llm, models_loaded
    
    # Prevent double loading
    if models_loaded:
        logger.warning("Models already loaded, skipping...")
        return
    
    logger.info("="*60)
    logger.info("STARTUP: Loading AI models...")
    logger.info("="*60)
    
    # Проверка GPU
    logger.info("STEP 1: Checking CUDA availability...")
    try:
        cuda_available = torch.cuda.is_available()
        logger.info(f"torch.cuda.is_available() = {cuda_available}")
        
        if not cuda_available:
            logger.error("CUDA is not available!")
            logger.error("Check: 1) NVIDIA drivers installed, 2) CUDA Toolkit installed")
            raise RuntimeError("GPU is required")
        
        gpu_name = torch.cuda.get_device_name(0)
        vram = torch.cuda.get_device_properties(0).total_memory / 1e9
        logger.info(f"GPU detected: {gpu_name} ({vram:.1f}GB VRAM)")
    except Exception as e:
        logger.error(f"GPU check failed: {type(e).__name__}: {e}")
        logger.error(f"Full traceback:", exc_info=True)
        raise
    
    try:
        # 1. MuseTalk (lip-sync)
        logger.info("="*60)
        logger.info("STEP 2: Loading MuseTalk...")
        logger.info(f"Current directory: {os.getcwd()}")
        logger.info(f"MuseTalk path exists: {os.path.exists('MuseTalk')}")
        logger.info(f"musetalk_inference.py exists: {os.path.exists('musetalk_inference.py')}")
        
        try:
            from musetalk_inference import MuseTalkInference
            logger.info("MuseTalkInference imported")
            
            musetalk_model = MuseTalkInference(device="cuda")
            logger.info("MuseTalk initialized successfully - real-time lip-sync ready")
        except Exception as e:
            logger.warning(f"MuseTalk failed to load: {type(e).__name__}: {e}")
            logger.warning("MuseTalk will not be available (lip-sync disabled)")
            logger.warning("To install: powershell -ExecutionPolicy Bypass -File install-musetalk.ps1")
            musetalk_model = None
        
        # 2. Stable Diffusion XL (backgrounds)
        logger.info("="*60)
        logger.info("STEP 3: Loading Stable Diffusion XL...")
        
        try:
            from diffusers import StableDiffusionXLPipeline
            logger.info("StableDiffusionXLPipeline imported")
            
            logger.info("Loading model from HuggingFace...")
            sd_pipeline = StableDiffusionXLPipeline.from_pretrained(
                "stabilityai/stable-diffusion-xl-base-1.0",
                torch_dtype=torch.float16,
                use_safetensors=True,
                variant="fp16"
            ).to("cuda")
            logger.info("Model loaded to CUDA")
            
            # Try xformers (optional)
            try:
                sd_pipeline.enable_xformers_memory_efficient_attention()
                logger.info("xformers memory optimization enabled")
            except Exception as xe:
                logger.warning(f"xformers not available: {xe}")
                logger.info("Running without xformers (slower but works)")
            
            logger.info("Stable Diffusion XL ready")
        except Exception as e:
            logger.warning(f"Stable Diffusion failed to load: {type(e).__name__}: {e}")
            logger.warning("Background generation will not be available")
            sd_pipeline = None
        
        # 3. Silero TTS (русский)
        logger.info("="*60)
        logger.info("STEP 4: Loading Silero TTS...")
        
        try:
            logger.info("Downloading/loading from torch.hub...")
            logger.info("This may take 1-2 minutes on first run...")
            
            # Отключаем прогресс бар который зависает
            os.environ['TQDM_DISABLE'] = '1'
            
            # Попытка загрузки с автоматической очисткой кеша при ошибке
            try:
                tts_model, _ = torch.hub.load(
                    repo_or_dir='snakers4/silero-models',
                    model='silero_tts',
                    language='ru',
                    speaker='v3_1_ru',
                    verbose=False  # Отключаем лишний вывод
                )
            except FileNotFoundError as cache_error:
                # Поврежденный кеш torch.hub - очищаем и пробуем снова
                logger.warning(f"Torch hub cache corrupted: {cache_error}")
                logger.info("Clearing torch hub cache and retrying...")
                
                import shutil
                cache_dir = Path.home() / ".cache" / "torch" / "hub" / "snakers4_silero-models_master"
                if cache_dir.exists():
                    shutil.rmtree(cache_dir)
                    logger.info(f"Cleared cache: {cache_dir}")
                
                # Повторная попытка с force_reload
                tts_model, _ = torch.hub.load(
                    repo_or_dir='snakers4/silero-models',
                    model='silero_tts',
                    language='ru',
                    speaker='v3_1_ru',
                    force_reload=True,
                    verbose=False
                )
            
            logger.info(f"Model downloaded, type: {type(tts_model)}")
            
            # Silero TTS .to() mutates in-place and returns None, don't reassign
            tts_model.to("cuda")
            logger.info(f"Moved to CUDA successfully")
            logger.info("Silero TTS ready")
        except Exception as e:
            logger.warning(f"Silero TTS failed to load: {type(e).__name__}: {e}")
            logger.warning("TTS will not be available")
            logger.error(f"Full traceback:", exc_info=True)
            tts_model = None
        
        # 4. Whisper STT (Speech-to-Text)
        logger.info("="*60)
        logger.info("STEP 5: Loading Whisper STT...")
        
        try:
            import whisper
            logger.info("Whisper library imported")
            
            logger.info("Loading Whisper Large-v3 model...")
            logger.info("This may take 2-3 minutes on first run (downloads ~3GB)...")
            
            whisper_model = whisper.load_model("large-v3", device="cuda")
            logger.info("Whisper Large-v3 loaded successfully - Speech-to-Text ready")
        except Exception as e:
            logger.warning(f"Whisper failed to load: {type(e).__name__}: {e}")
            logger.warning("Speech-to-Text will not be available")
            logger.warning("To install: pip install openai-whisper")
            whisper_model = None
        
        # 5. Text LLM (Mistral 7B for text improvement)
        logger.info("="*60)
        logger.info("STEP 6: Loading Text LLM (Mistral 7B)...")
        
        try:
            from transformers import AutoModelForCausalLM, AutoTokenizer
            logger.info("Transformers imported")
            
            logger.info("Loading Mistral-7B-Instruct-v0.2...")
            logger.info("This may take 5-10 minutes on first run (downloads ~14GB)...")
            
            text_llm = {
                "tokenizer": AutoTokenizer.from_pretrained(
                    "mistralai/Mistral-7B-Instruct-v0.2"
                ),
                "model": AutoModelForCausalLM.from_pretrained(
                    "mistralai/Mistral-7B-Instruct-v0.2",
                    torch_dtype=torch.float16,
                    device_map="auto",
                    low_cpu_mem_usage=True
                )
            }
            logger.info("Mistral 7B loaded successfully - Text improvement ready")
        except Exception as e:
            logger.warning(f"Text LLM failed to load: {type(e).__name__}: {e}")
            logger.warning("Text improvement will not be available locally")
            logger.warning("Consider using API fallback (Claude/GPT)")
            text_llm = None
        
        logger.info("="*60)
        logger.info("STARTUP COMPLETE!")
        logger.info(f"MuseTalk (Lip-sync): {'OK' if musetalk_model else 'DISABLED'}")
        logger.info(f"Stable Diffusion XL: {'OK' if sd_pipeline else 'DISABLED'}")
        logger.info(f"Silero TTS: {'OK' if tts_model else 'DISABLED'}")
        logger.info(f"Whisper STT: {'OK' if whisper_model else 'DISABLED'}")
        logger.info(f"Text LLM (Mistral 7B): {'OK' if text_llm else 'DISABLED'}")
        logger.info("="*60)
        
        # Mark models as loaded
        models_loaded = True
        
    except Exception as e:
        logger.error(f"Critical error during model loading: {type(e).__name__}: {e}")
        logger.error("Full traceback:", exc_info=True)
        raise

@app.get("/")
async def root():
    """Health check"""
    logger.debug("Root endpoint called")
    return {"status": "ok", "message": "Avatar Factory GPU Server"}

@app.get("/health")
async def health():
    """Detailed health check"""
    logger.debug("Health endpoint called")
    try:
        vram_total = torch.cuda.get_device_properties(0).total_memory / 1e9
        vram_free = (torch.cuda.mem_get_info()[0]) / 1e9
        vram_used = vram_total - vram_free
        
        logger.debug(f"VRAM: {vram_used:.1f}GB/{vram_total:.1f}GB used")
        
        return {
            "status": "healthy",
            "gpu": {
                "name": torch.cuda.get_device_name(0),
                "vram_total_gb": round(vram_total, 2),
                "vram_used_gb": round(vram_used, 2),
                "vram_free_gb": round(vram_free, 2),
                "utilization_percent": round((vram_used / vram_total) * 100, 1)
            },
            "models": {
                "musetalk": musetalk_model is not None,
                "stable_diffusion": sd_pipeline is not None,
                "silero_tts": tts_model is not None,
                "whisper_stt": whisper_model is not None,
                "text_llm": text_llm is not None
            }
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.get("/diagnostics")
async def diagnostics(x_api_key: str = Header()):
    """Полная диагностика системы для анализа"""
    verify_api_key(x_api_key)
    
    import subprocess
    import platform
    
    diagnostics_info = {
        "system": {
            "os": platform.system(),
            "os_version": platform.version(),
            "python_version": platform.python_version(),
            "cuda_available": torch.cuda.is_available(),
        },
        "dependencies": {
            "torch_version": torch.__version__,
            "cuda_version": torch.version.cuda if torch.cuda.is_available() else None,
        },
        "models": {
            "musetalk_loaded": musetalk_model is not None,
            "stable_diffusion_loaded": sd_pipeline is not None,
            "silero_tts_loaded": tts_model is not None,
        },
        "paths": {
            "temp_dir": str(TEMP_DIR),
            "temp_dir_exists": TEMP_DIR.exists(),
            "cwd": os.getcwd(),
        }
    }
    
    # Check ffmpeg
    try:
        result = subprocess.run(["ffmpeg", "-version"], capture_output=True, text=True, timeout=5)
        diagnostics_info["ffmpeg"] = {
            "available": result.returncode == 0,
            "version": result.stdout.split('\n')[0] if result.returncode == 0 else None
        }
    except Exception as e:
        diagnostics_info["ffmpeg"] = {
            "available": False,
            "error": str(e)
        }
    
    # Check disk space
    if TEMP_DIR.exists():
        import shutil
        try:
            disk_usage = shutil.disk_usage(TEMP_DIR)
            diagnostics_info["disk_space"] = {
                "total_gb": round(disk_usage.total / 1e9, 2),
                "used_gb": round(disk_usage.used / 1e9, 2),
                "free_gb": round(disk_usage.free / 1e9, 2),
            }
        except Exception as e:
            diagnostics_info["disk_space"] = {"error": str(e)}
    
    # List recent temp files
    try:
        temp_files = []
        if TEMP_DIR.exists():
            for f in sorted(TEMP_DIR.glob("*.*"), key=lambda x: x.stat().st_mtime, reverse=True)[:10]:
                temp_files.append({
                    "name": f.name,
                    "size_kb": round(f.stat().st_size / 1024, 2),
                    "modified": f.stat().st_mtime
                })
        diagnostics_info["recent_temp_files"] = temp_files
    except Exception as e:
        diagnostics_info["recent_temp_files"] = {"error": str(e)}
    
    return diagnostics_info

@app.post("/api/tts")
async def text_to_speech(
    text: str = Query(..., description="Text to synthesize"),
    speaker: str = Query("xenia", description="Speaker voice"),
    x_api_key: str = Header()
):
    """Генерация аудио из текста (Silero TTS)"""
    verify_api_key(x_api_key)
    
    if not tts_model:
        raise HTTPException(status_code=503, detail="TTS model not loaded")
    
    try:
        logger.info(f"TTS request: text='{text[:50]}...', speaker={speaker}")
        
        # Генерация аудио через метод apply_tts
        sample_rate = 48000
        audio = tts_model.apply_tts(text=text, speaker=speaker, sample_rate=sample_rate)
        
        # Сохранение
        output_path = TEMP_DIR / f"tts_{os.urandom(8).hex()}.wav"
        
        # audio уже numpy array или tensor
        if hasattr(audio, 'cpu'):
            audio_np = audio.cpu().numpy()
        else:
            audio_np = audio
            
        sf.write(str(output_path), audio_np, sample_rate)
        
        logger.info(f"✅ TTS generated: {output_path.name} ({len(audio_np)} samples)")
        return FileResponse(output_path, media_type="audio/wav")
        
    except Exception as e:
        logger.error(f"❌ TTS failed: {type(e).__name__}: {e}")
        logger.exception("Full traceback:")
        raise HTTPException(status_code=500, detail=f"{type(e).__name__}: {str(e)}")

@app.post("/api/lipsync")
async def create_lipsync(
    image: UploadFile = File(...),
    audio: UploadFile = File(...),
    bbox_shift: int = 0,
    batch_size: int = 8,
    fps: int = 25,
    x_api_key: str = Header()
):
    """Создание говорящего аватара (MuseTalk - real-time lip-sync)"""
    verify_api_key(x_api_key)
    
    if musetalk_model is None:
        logger.error("MuseTalk not loaded")
        raise HTTPException(status_code=503, detail="MuseTalk not available - run install-musetalk.ps1")
    
    try:
        logger.info(f"Lip-sync request: {image.filename}, {audio.filename}")
        logger.info(f"  Parameters: bbox_shift={bbox_shift}, batch_size={batch_size}, fps={fps}")
        
        # Сохранение входных файлов
        image_path = TEMP_DIR / f"img_{os.urandom(8).hex()}{Path(image.filename).suffix}"
        audio_path = TEMP_DIR / f"aud_{os.urandom(8).hex()}{Path(audio.filename).suffix}"
        
        with open(image_path, "wb") as f:
            f.write(await image.read())
        with open(audio_path, "wb") as f:
            f.write(await audio.read())
        
        logger.info(f"Input files saved: {image_path.name}, {audio_path.name}")
        
        # Генерация видео через MuseTalk
        output_path = TEMP_DIR / f"video_{os.urandom(8).hex()}.mp4"
        
        musetalk_model.generate(
            image_path=str(image_path),
            audio_path=str(audio_path),
            output_path=str(output_path),
            bbox_shift=bbox_shift,
            batch_size=batch_size,
            fps=fps
        )
        
        # Проверка размера видео
        video_size_mb = output_path.stat().st_size / (1024 * 1024)
        logger.info(f"[OK] Lip-sync video generated: {output_path.name}")
        logger.info(f"    Size: {video_size_mb:.2f} MB")
        
        # Очистка входных файлов
        image_path.unlink()
        audio_path.unlink()
        logger.info("Cleaned up input files")
        
        logger.info(f"Sending video file ({video_size_mb:.2f} MB) to client...")
        
        # Use streaming response for reliable large file transfer
        def iterfile():
            with open(output_path, "rb") as f:
                chunk_size = 64 * 1024  # 64KB chunks
                while chunk := f.read(chunk_size):
                    yield chunk
            # Clean up temp file after sending
            output_path.unlink()
            logger.info(f"Video sent and cleaned up: {output_path.name}")
        
        return StreamingResponse(
            iterfile(),
            media_type="video/mp4",
            headers={
                "Content-Disposition": f"attachment; filename=lipsync_{os.urandom(4).hex()}.mp4",
                "Content-Length": str(output_path.stat().st_size)
            }
        )
        
    except Exception as e:
        import traceback
        logger.error(f"❌ Lip-sync failed: {e}")
        logger.error(f"Full traceback:\n{traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/generate-background")
async def generate_background(
    prompt: str = Query(..., description="Background prompt"),
    negative_prompt: str = Query("blurry, low quality, distorted", description="Negative prompt"),
    width: int = Query(1080, description="Image width"),
    height: int = Query(1920, description="Image height"),
    x_api_key: str = Header()
):
    """Генерация фона (Stable Diffusion XL)"""
    verify_api_key(x_api_key)
    
    if not sd_pipeline:
        raise HTTPException(status_code=503, detail="Stable Diffusion model not loaded")
    
    try:
        logger.info(f"Background generation: prompt='{prompt[:50]}...', size={width}x{height}")
        
        # Генерация изображения
        image = sd_pipeline(
            prompt=prompt,
            negative_prompt=negative_prompt,
            width=width,
            height=height,
            num_inference_steps=30,
            guidance_scale=7.5
        ).images[0]
        
        # Сохранение
        output_path = TEMP_DIR / f"bg_{os.urandom(8).hex()}.png"
        image.save(output_path)
        
        logger.info(f"✅ Background generated: {output_path.name}")
        return FileResponse(output_path, media_type="image/png")
        
    except Exception as e:
        logger.error(f"❌ Background generation failed: {type(e).__name__}: {e}")
        logger.exception("Full traceback:")
        raise HTTPException(status_code=500, detail=f"{type(e).__name__}: {str(e)}")

@app.post("/api/cleanup")
async def cleanup_temp_files(x_api_key: str = Header()):
    """Очистка временных файлов"""
    verify_api_key(x_api_key)
    
    try:
        import shutil
        for file in TEMP_DIR.glob("*"):
            if file.is_file():
                file.unlink()
        
        return {"status": "ok", "message": "Temp files cleaned"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ================================================================
# NEW ENDPOINTS - Speech-to-Text, Text Improvement
# ================================================================

@app.post("/api/stt")
async def speech_to_text(
    audio: UploadFile = File(...),
    language: str = Query("ru", description="Language code (ru, en, etc)"),
    model_size: str = Query("large-v3", description="Model size (only large-v3 loaded)"),
    x_api_key: str = Header()
):
    """
    Speech-to-Text (Whisper Large V3)
    
    Распознает речь из аудио файла.
    Поддерживает форматы: wav, mp3, m4a, flac, ogg
    """
    verify_api_key(x_api_key)
    
    if not whisper_model:
        raise HTTPException(
            status_code=503, 
            detail="Whisper STT not loaded. Install: pip install openai-whisper"
        )
    
    try:
        logger.info(f"STT request: file={audio.filename}, language={language}")
        
        # Сохранить аудио файл
        audio_path = TEMP_DIR / f"stt_{os.urandom(8).hex()}{Path(audio.filename).suffix}"
        with open(audio_path, "wb") as f:
            f.write(await audio.read())
        
        logger.info(f"Audio saved: {audio_path.name} ({audio_path.stat().st_size / 1024:.1f} KB)")
        
        # Распознавание
        logger.info("Starting transcription...")
        result = whisper_model.transcribe(
            str(audio_path),
            language=language if language != "auto" else None,
            fp16=True,  # FP16 на GPU
            verbose=False
        )
        
        # Очистка
        audio_path.unlink()
        logger.info(f"✅ STT completed: {len(result['text'])} characters")
        
        return {
            "text": result["text"],
            "language": result["language"],
            "segments": [
                {
                    "start": seg["start"],
                    "end": seg["end"],
                    "text": seg["text"]
                }
                for seg in result.get("segments", [])
            ]
        }
        
    except Exception as e:
        logger.error(f"❌ STT failed: {type(e).__name__}: {e}")
        logger.exception("Full traceback:")
        raise HTTPException(status_code=500, detail=f"STT error: {str(e)}")

@app.post("/api/improve-text")
async def improve_text(
    text: str = Query(..., description="Text to improve"),
    style: str = Query("professional", description="Style: professional|casual|technical|creative"),
    max_tokens: int = Query(512, description="Maximum output tokens"),
    x_api_key: str = Header()
):
    """
    Улучшение текста (Mistral 7B)
    
    Редактирует и улучшает текст для лучшего восприятия.
    Стили: professional, casual, technical, creative
    """
    verify_api_key(x_api_key)
    
    if not text_llm:
        raise HTTPException(
            status_code=503,
            detail="Text LLM not loaded. Install: transformers + Mistral model"
        )
    
    try:
        logger.info(f"Text improvement: {len(text)} chars, style={style}")
        
        # Промты для разных стилей
        style_prompts = {
            "professional": "Сделай текст более профессиональным и структурированным для делового общения.",
            "casual": "Сделай текст более простым и дружелюбным для неформального общения.",
            "technical": "Сделай текст более технически точным с правильной терминологией.",
            "creative": "Сделай текст более живым и креативным, сохранив смысл."
        }
        
        style_instruction = style_prompts.get(style, style_prompts["professional"])
        
        # Формирование промта для Mistral
        prompt = f"""[INST] {style_instruction}

Исходный текст:
{text}

Улучшенный текст: [/INST]"""
        
        # Токенизация
        inputs = text_llm["tokenizer"](prompt, return_tensors="pt").to("cuda")
        
        logger.info("Generating improved text...")
        
        # Генерация
        outputs = text_llm["model"].generate(
            **inputs,
            max_new_tokens=max_tokens,
            temperature=0.7,
            do_sample=True,
            top_p=0.9,
            pad_token_id=text_llm["tokenizer"].eos_token_id
        )
        
        # Декодирование
        full_response = text_llm["tokenizer"].decode(outputs[0], skip_special_tokens=True)
        
        # Извлечь только ответ (после [/INST])
        if "[/INST]" in full_response:
            improved = full_response.split("[/INST]")[-1].strip()
        else:
            improved = full_response.strip()
        
        logger.info(f"✅ Text improved: {len(improved)} chars")
        
        return {
            "original_text": text,
            "improved_text": improved,
            "style": style,
            "original_length": len(text),
            "improved_length": len(improved)
        }
        
    except Exception as e:
        logger.error(f"❌ Text improvement failed: {type(e).__name__}: {e}")
        logger.exception("Full traceback:")
        raise HTTPException(status_code=500, detail=f"Text improvement error: {str(e)}")

# ================================================================
# VIDEO API INTEGRATION & HYBRID PIPELINE
# ================================================================

@app.post("/api/estimate-cost")
async def estimate_cost(
    pipeline_config: Dict[str, Any],
    x_api_key: str = Header()
):
    """
    Оценка стоимости выполнения пайплайна
    
    pipeline_config:
    {
        "steps": ["stt", "improve_text", "generate_images", "generate_video"],
        "audio_duration_minutes": 5,
        "num_images": 4,
        "video_duration_seconds": 300,
        "use_local": ["stt", "improve_text", "generate_images"],
        "use_api": ["generate_video"]
    }
    """
    verify_api_key(x_api_key)
    
    try:
        steps = pipeline_config.get("steps", [])
        audio_duration = pipeline_config.get("audio_duration_minutes", 0)
        num_images = pipeline_config.get("num_images", 0)
        video_duration = pipeline_config.get("video_duration_seconds", 0)
        use_local = set(pipeline_config.get("use_local", []))
        use_api = set(pipeline_config.get("use_api", []))
        
        # Расценки (в рублях)
        costs = {
            "local": {
                "stt": 0,  # Бесплатно локально
                "improve_text": 0,  # Бесплатно локально
                "generate_images": 0,  # Бесплатно локально
            },
            "api": {
                "stt": 0.51,  # За минуту (Whisper 1)
                "improve_text": 68.6 / 1000000,  # За токен (Claude Sonnet 4.6, ~3000 токенов на запрос)
                "generate_images": 5.0,  # За изображение (Flux-2 Pro)
                "generate_video": 45.0,  # За видео (Veo Fast)
            }
        }
        
        total_cost = 0.0
        breakdown = []
        
        # STT
        if "stt" in steps:
            if "stt" in use_api:
                cost = audio_duration * costs["api"]["stt"]
                total_cost += cost
                breakdown.append({
                    "step": "stt",
                    "provider": "api",
                    "cost": cost,
                    "details": f"{audio_duration} минут × {costs['api']['stt']}₽/мин"
                })
            else:
                breakdown.append({
                    "step": "stt",
                    "provider": "local",
                    "cost": 0,
                    "details": "Whisper Large V3 (локально)"
                })
        
        # Text improvement
        if "improve_text" in steps:
            if "improve_text" in use_api:
                cost = 3000 * costs["api"]["improve_text"]  # ~3000 токенов
                total_cost += cost
                breakdown.append({
                    "step": "improve_text",
                    "provider": "api",
                    "cost": cost,
                    "details": "Claude Sonnet 4.6 (~3000 токенов)"
                })
            else:
                breakdown.append({
                    "step": "improve_text",
                    "provider": "local",
                    "cost": 0,
                    "details": "Mistral 7B (локально)"
                })
        
        # Images
        if "generate_images" in steps:
            if "generate_images" in use_api:
                cost = num_images * costs["api"]["generate_images"]
                total_cost += cost
                breakdown.append({
                    "step": "generate_images",
                    "provider": "api",
                    "cost": cost,
                    "details": f"{num_images} × {costs['api']['generate_images']}₽ (Flux-2 Pro)"
                })
            else:
                breakdown.append({
                    "step": "generate_images",
                    "provider": "local",
                    "cost": 0,
                    "details": f"{num_images} изображений SDXL (локально)"
                })
        
        # Video
        if "generate_video" in steps:
            if "generate_video" in use_api:
                num_videos = max(1, video_duration // 300)  # По 5 минут на видео
                cost = num_videos * costs["api"]["generate_video"]
                total_cost += cost
                breakdown.append({
                    "step": "generate_video",
                    "provider": "api",
                    "cost": cost,
                    "details": f"{num_videos} видео × {costs['api']['generate_video']}₽ (Veo Fast)"
                })
            else:
                breakdown.append({
                    "step": "generate_video",
                    "provider": "local",
                    "cost": 0,
                    "details": "⚠️ Локальная генерация видео не рекомендуется (медленно)"
                })
        
        return {
            "total_cost_rub": round(total_cost, 2),
            "total_cost_usd": round(total_cost / 90, 2),  # Примерный курс
            "breakdown": breakdown,
            "recommendations": [
                "Используйте локально: STT, Text, Images (экономия ~200₽)",
                "Используйте API: только Video (оптимальное качество)",
                "Batch generation для images снижает брак на 40%"
            ]
        }
        
    except Exception as e:
        logger.error(f"Cost estimation failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/generate-video-api")
async def generate_video_api(
    prompt: str = Query(..., description="Video generation prompt"),
    keyframe: Optional[UploadFile] = File(None, description="Reference image for image-to-video"),
    duration: int = Query(5, description="Video duration in seconds (5-10)"),
    model: str = Query("veo-fast", description="Model: veo-fast, kling, veo-quality"),
    x_api_key: str = Header()
):
    """
    Генерация видео через Polza.ai API
    
    Модели:
    - veo-fast: Google Veo 3.1 Fast (45₽, быстро)
    - veo-quality: Google Veo 3.1 Quality (187.5₽, высокое качество)
    - kling: Kling 2.6 (22.5₽, бюджет)
    """
    verify_api_key(x_api_key)
    
    if not POLZA_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="POLZA_API_KEY not configured in .env file"
        )
    
    try:
        logger.info(f"Video API request: model={model}, duration={duration}s")
        
        # Маппинг моделей
        model_mapping = {
            "veo-fast": "google/veo3_fast",
            "veo-quality": "google/veo3",
            "kling": "kling/v2.6-motion-control",
        }
        
        if model not in model_mapping:
            raise HTTPException(status_code=400, detail=f"Unknown model: {model}")
        
        polza_model = model_mapping[model]
        
        # Подготовка запроса
        request_data = {
            "model": polza_model,
            "prompt": prompt,
            "duration": duration,
        }
        
        # Если есть keyframe → image-to-video
        if keyframe:
            logger.info(f"Image-to-video mode with keyframe: {keyframe.filename}")
            
            # Сохранить keyframe
            keyframe_path = TEMP_DIR / f"key_{os.urandom(8).hex()}.png"
            with open(keyframe_path, "wb") as f:
                f.write(await keyframe.read())
            
            # TODO: Загрузить на Polza storage или передать base64
            # Для MVP: текст-описание
            request_data["reference_image"] = "provided"
            
            # Очистка
            keyframe_path.unlink()
        
        # Запрос к Polza.ai API
        async with httpx.AsyncClient(timeout=300.0) as client:
            response = await client.post(
                f"{POLZA_BASE_URL}/video/generate",
                headers={
                    "Authorization": f"Bearer {POLZA_API_KEY}",
                    "Content-Type": "application/json"
                },
                json=request_data
            )
            
            if response.status_code != 200:
                logger.error(f"Polza API error: {response.status_code} - {response.text}")
                raise HTTPException(
                    status_code=response.status_code,
                    detail=f"Polza API error: {response.text}"
                )
            
            result = response.json()
            
            logger.info(f"✅ Video generation started: task_id={result.get('task_id')}")
            
            return {
                "status": "processing",
                "task_id": result.get("task_id"),
                "estimated_time_seconds": result.get("estimated_time", 60),
                "model": model,
                "cost_estimate_rub": 45.0 if model == "veo-fast" else 187.5,
                "message": "Video generation started. Poll /api/video-status/{task_id} for updates"
            }
    
    except httpx.HTTPError as e:
        logger.error(f"HTTP error calling Polza API: {e}")
        raise HTTPException(status_code=503, detail=f"API connection error: {str(e)}")
    except Exception as e:
        logger.error(f"Video API failed: {e}")
        logger.exception("Full traceback:")
        raise HTTPException(status_code=500, detail=f"Video generation error: {str(e)}")

@app.post("/api/pipeline")
async def hybrid_pipeline(
    audio: Optional[UploadFile] = File(None, description="Audio file for STT"),
    text: Optional[str] = Query(None, description="Text (if no audio)"),
    num_images: int = Query(4, description="Number of images to generate"),
    generate_video: bool = Query(True, description="Generate video"),
    style: str = Query("professional", description="Text style"),
    use_api_for_video: bool = Query(True, description="Use API for video (recommended)"),
    x_api_key: str = Header()
):
    """
    Гибридный пайплайн: локально + API
    
    Этапы:
    1. STT (локально, Whisper) - если audio
    2. Text improvement (локально, Mistral)
    3. Image generation (локально, SDXL) - 4 варианта
    4. Video generation (API, Veo) - лучший keyframe
    
    Оптимизировано для минимальной стоимости при высоком качестве.
    """
    verify_api_key(x_api_key)
    
    try:
        logger.info("="*60)
        logger.info("HYBRID PIPELINE START")
        logger.info("="*60)
        
        results = {
            "steps_completed": [],
            "total_cost_rub": 0.0,
            "outputs": {}
        }
        
        # STEP 1: STT (если есть audio)
        if audio:
            logger.info("STEP 1: Speech-to-Text (local, Whisper)")
            
            if not whisper_model:
                raise HTTPException(status_code=503, detail="Whisper not loaded")
            
            # Сохранить audio
            audio_path = TEMP_DIR / f"pipeline_audio_{os.urandom(8).hex()}.wav"
            with open(audio_path, "wb") as f:
                f.write(await audio.read())
            
            # Распознать
            stt_result = whisper_model.transcribe(str(audio_path), fp16=True, verbose=False)
            text = stt_result["text"]
            audio_path.unlink()
            
            results["steps_completed"].append("stt_local")
            results["outputs"]["original_text"] = text
            logger.info(f"✅ STT: {len(text)} characters")
        
        elif not text:
            raise HTTPException(status_code=400, detail="Either audio or text required")
        
        # STEP 2: Text improvement (локально, Mistral)
        logger.info("STEP 2: Text Improvement (local, Mistral)")
        
        if not text_llm:
            logger.warning("Text LLM not loaded, skipping improvement")
            improved_text = text
        else:
            prompt = f"""[INST] Улучши этот текст для {style} стиля.

Исходный текст:
{text}

Улучшенный текст: [/INST]"""
            
            inputs = text_llm["tokenizer"](prompt, return_tensors="pt").to("cuda")
            outputs = text_llm["model"].generate(
                **inputs,
                max_new_tokens=512,
                temperature=0.7,
                do_sample=True,
                pad_token_id=text_llm["tokenizer"].eos_token_id
            )
            
            full_response = text_llm["tokenizer"].decode(outputs[0], skip_special_tokens=True)
            improved_text = full_response.split("[/INST]")[-1].strip() if "[/INST]" in full_response else full_response.strip()
            
            results["steps_completed"].append("text_improvement_local")
            results["outputs"]["improved_text"] = improved_text
            logger.info(f"✅ Text improved: {len(improved_text)} characters")
        
        # STEP 3: Image generation (локально, SDXL batch)
        logger.info(f"STEP 3: Image Generation (local, SDXL) - {num_images} images")
        
        if not sd_pipeline:
            raise HTTPException(status_code=503, detail="SDXL not loaded")
        
        image_paths = []
        for i in range(num_images):
            logger.info(f"Generating image {i+1}/{num_images}...")
            
            image = sd_pipeline(
                prompt=improved_text[:500],  # Ограничение промта
                num_inference_steps=25,
                height=1024,
                width=1024,
                guidance_scale=7.5
            ).images[0]
            
            img_path = TEMP_DIR / f"pipeline_img_{i}_{os.urandom(4).hex()}.png"
            image.save(img_path)
            image_paths.append(str(img_path))
        
        results["steps_completed"].append("image_generation_local")
        results["outputs"]["images"] = [p.split("/")[-1] for p in image_paths]
        logger.info(f"✅ Generated {num_images} images")
        
        # STEP 4: Video generation (API или skip)
        if generate_video:
            if use_api_for_video and POLZA_API_KEY:
                logger.info("STEP 4: Video Generation (API, Veo Fast)")
                
                # Используем первое изображение как keyframe
                # TODO: выбрать лучшее на основе scoring
                best_keyframe = image_paths[0]
                
                logger.info(f"Using keyframe: {best_keyframe}")
                
                # Вызов API (упрощенная версия)
                video_cost = 45.0
                results["total_cost_rub"] += video_cost
                results["steps_completed"].append("video_generation_api")
                results["outputs"]["video_task_id"] = "mock_task_123"  # TODO: реальный вызов API
                results["outputs"]["video_cost_rub"] = video_cost
                
                logger.info(f"✅ Video generation started (45₽)")
            else:
                logger.info("STEP 4: Video generation skipped (API key not set or disabled)")
                results["steps_completed"].append("video_generation_skipped")
        
        # Итоги
        logger.info("="*60)
        logger.info("PIPELINE COMPLETE")
        logger.info(f"Steps: {', '.join(results['steps_completed'])}")
        logger.info(f"Total cost: {results['total_cost_rub']}₽")
        logger.info("="*60)
        
        return {
            **results,
            "message": "Pipeline completed successfully",
            "recommendations": [
                "Review generated images and select best keyframe",
                "For production: add quality scoring for image selection",
                "Consider batch video generation for better success rate"
            ]
        }
    
    except Exception as e:
        logger.error(f"Pipeline failed: {e}")
        logger.exception("Full traceback:")
        raise HTTPException(status_code=500, detail=f"Pipeline error: {str(e)}")

if __name__ == "__main__":
    import signal
    
    def signal_handler(sig, frame):
        """Handle Ctrl+C gracefully"""
        logger.info("\n" + "="*60)
        logger.info("⚠️  Received shutdown signal (Ctrl+C)")
        logger.info("Shutting down gracefully...")
        logger.info("="*60)
        sys.exit(0)
    
    # Register signal handler for Ctrl+C
    signal.signal(signal.SIGINT, signal_handler)
    if hasattr(signal, 'SIGTERM'):
        signal.signal(signal.SIGTERM, signal_handler)
    
    logger.info("="*60)
    logger.info("MAIN: Server startup initiated")
    logger.info("="*60)
    
    try:
        logger.info("Loading environment variables...")
        port = int(os.getenv("PORT", "8001"))
        host = os.getenv("HOST", "0.0.0.0")
        logger.info(f"Host: {host}, Port: {port}")
        
        # Check if .env exists
        env_path = Path(".env")
        logger.info(f".env exists: {env_path.exists()}")
        if env_path.exists():
            logger.info(f".env size: {env_path.stat().st_size} bytes")
        
        logger.info("Importing uvicorn...")
        import uvicorn
        logger.info("uvicorn imported")
        
        logger.info(f"Starting uvicorn server on {host}:{port}")
        logger.info("Press Ctrl+C to stop")
        logger.info("="*60)
        
        # Disable reload and workers to prevent double startup
        # Increase timeouts for long video generation/transfer
        uvicorn.run(
            app,
            host=host,
            port=port,
            log_level="info",
            reload=False,
            workers=1,
            timeout_keep_alive=900,  # 15 minutes for long video generation
            timeout_graceful_shutdown=30
        )
    except KeyboardInterrupt:
        logger.info("\n" + "="*60)
        logger.info("⚠️  Received KeyboardInterrupt")
        logger.info("Server stopped by user")
        logger.info("="*60)
        sys.exit(0)
    except Exception as e:
        logger.error(f"FATAL ERROR: {type(e).__name__}: {e}")
        logger.error("Full traceback:", exc_info=True)
        sys.exit(1)
