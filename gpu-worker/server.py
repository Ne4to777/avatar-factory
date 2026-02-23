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
    from typing import Optional
    import soundfile as sf
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

# API Key для безопасности
API_KEY = os.getenv("GPU_API_KEY", "your-secret-gpu-key-change-this")
logger.info(f"API Key loaded: {API_KEY[:8]}...")

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
models_loaded = False  # Flag to prevent double loading

def verify_api_key(x_api_key: str = Header()):
    """Проверка API ключа"""
    if x_api_key != API_KEY:
        raise HTTPException(status_code=403, detail="Invalid API Key")

@app.on_event("startup")
async def load_models():
    """Загрузка AI моделей при старте сервера"""
    global musetalk_model, sd_pipeline, tts_model, models_loaded
    
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
        
        logger.info("="*60)
        logger.info("STARTUP COMPLETE!")
        logger.info(f"MuseTalk (Lip-sync): {'OK' if musetalk_model else 'DISABLED'}")
        logger.info(f"Stable Diffusion XL: {'OK' if sd_pipeline else 'DISABLED'}")
        logger.info(f"Silero TTS: {'OK' if tts_model else 'DISABLED'}")
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
                "silero_tts": tts_model is not None
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
