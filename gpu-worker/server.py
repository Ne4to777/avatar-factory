"""
GPU Server для Avatar Factory
Минималистичный FastAPI сервер для обработки AI задач
"""

import sys
import os
from pathlib import Path
import logging

# Setup detailed logging FIRST
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
    from fastapi import FastAPI, UploadFile, File, HTTPException, Header
    from fastapi.middleware.cors import CORSMiddleware
    from fastapi.responses import FileResponse
    logger.info("FastAPI imported successfully")
except Exception as e:
    logger.error(f"Failed to import FastAPI: {e}")
    raise

try:
    logger.info("Importing PyTorch...")
    import torch
    logger.info(f"PyTorch imported successfully: {torch.__version__}")
except Exception as e:
    logger.error(f"Failed to import PyTorch: {e}")
    raise

try:
    logger.info("Importing asyncio...")
    import asyncio
    from typing import Optional
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
sadtalker_model = None
sd_pipeline = None
tts_model = None

def verify_api_key(x_api_key: str = Header()):
    """Проверка API ключа"""
    if x_api_key != API_KEY:
        raise HTTPException(status_code=403, detail="Invalid API Key")

@app.on_event("startup")
async def load_models():
    """Загрузка AI моделей при старте сервера"""
    global sadtalker_model, sd_pipeline, tts_model
    
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
        # 1. SadTalker (lip-sync)
        logger.info("="*60)
        logger.info("STEP 2: Loading SadTalker...")
        logger.info(f"Current directory: {os.getcwd()}")
        logger.info(f"SadTalker path exists: {os.path.exists('SadTalker')}")
        logger.info(f"sadtalker_inference.py exists: {os.path.exists('sadtalker_inference.py')}")
        
        try:
            from sadtalker_inference import SadTalkerInference
            logger.info("SadTalkerInference imported")
            
            sadtalker_model = SadTalkerInference(
                checkpoint_path="./checkpoints",
                device="cuda"
            )
            logger.info("SadTalker initialized successfully")
        except Exception as e:
            logger.warning(f"SadTalker failed to load: {type(e).__name__}: {e}")
            logger.warning("SadTalker will not be available (lip-sync disabled)")
            sadtalker_model = None
        
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
            tts_model, _ = torch.hub.load(
                repo_or_dir='snakers4/silero-models',
                model='silero_tts',
                language='ru',
                speaker='v3_1_ru'
            )
            logger.info("Model downloaded")
            
            tts_model = tts_model.to("cuda")
            logger.info("Silero TTS ready")
        except Exception as e:
            logger.warning(f"Silero TTS failed to load: {type(e).__name__}: {e}")
            logger.warning("TTS will not be available")
            tts_model = None
        
        logger.info("="*60)
        logger.info("STARTUP COMPLETE!")
        logger.info(f"SadTalker: {'OK' if sadtalker_model else 'DISABLED'}")
        logger.info(f"Stable Diffusion: {'OK' if sd_pipeline else 'DISABLED'}")
        logger.info(f"TTS: {'OK' if tts_model else 'DISABLED'}")
        logger.info("="*60)
        
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
                "sadtalker": sadtalker_model is not None,
                "stable_diffusion": sd_pipeline is not None,
                "silero_tts": tts_model is not None
            }
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.post("/api/tts")
async def text_to_speech(
    text: str,
    speaker: str = "xenia",
    x_api_key: str = Header()
):
    """Генерация аудио из текста (Silero TTS)"""
    verify_api_key(x_api_key)
    
    try:
        logger.info(f"TTS request: {len(text)} chars, speaker: {speaker}")
        
        # Генерация аудио
        audio = tts_model.apply_tts(
            text=text,
            speaker=speaker,
            sample_rate=48000
        )
        
        # Сохранение
        output_path = TEMP_DIR / f"tts_{os.urandom(8).hex()}.wav"
        import soundfile as sf
        sf.write(str(output_path), audio.cpu().numpy(), 48000)
        
        logger.info(f"✅ TTS generated: {output_path}")
        return FileResponse(output_path, media_type="audio/wav")
        
    except Exception as e:
        logger.error(f"❌ TTS failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/lipsync")
async def create_lipsync(
    image: UploadFile = File(...),
    audio: UploadFile = File(...),
    x_api_key: str = Header()
):
    """Создание говорящего аватара (SadTalker)"""
    verify_api_key(x_api_key)
    
    try:
        logger.info(f"Lip-sync request: {image.filename}, {audio.filename}")
        
        # Сохранение входных файлов
        image_path = TEMP_DIR / f"img_{os.urandom(8).hex()}{Path(image.filename).suffix}"
        audio_path = TEMP_DIR / f"aud_{os.urandom(8).hex()}{Path(audio.filename).suffix}"
        
        with open(image_path, "wb") as f:
            f.write(await image.read())
        with open(audio_path, "wb") as f:
            f.write(await audio.read())
        
        # Генерация видео
        output_path = TEMP_DIR / f"video_{os.urandom(8).hex()}.mp4"
        
        sadtalker_model.generate(
            source_image=str(image_path),
            driven_audio=str(audio_path),
            output_path=str(output_path),
            preprocess="crop",
            enhancer="gfpgan"  # улучшение качества лица
        )
        
        logger.info(f"✅ Lip-sync generated: {output_path}")
        
        # Очистка входных файлов
        image_path.unlink()
        audio_path.unlink()
        
        return FileResponse(output_path, media_type="video/mp4")
        
    except Exception as e:
        logger.error(f"❌ Lip-sync failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/generate-background")
async def generate_background(
    prompt: str,
    negative_prompt: str = "blurry, low quality, distorted",
    width: int = 1080,
    height: int = 1920,
    x_api_key: str = Header()
):
    """Генерация фона (Stable Diffusion XL)"""
    verify_api_key(x_api_key)
    
    try:
        logger.info(f"Background generation: {prompt}")
        
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
        
        logger.info(f"✅ Background generated: {output_path}")
        return FileResponse(output_path, media_type="image/png")
        
    except Exception as e:
        logger.error(f"❌ Background generation failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

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
        logger.info("="*60)
        
        uvicorn.run(
            app,
            host=host,
            port=port,
            log_level="info"
        )
    except Exception as e:
        logger.error(f"FATAL ERROR: {type(e).__name__}: {e}")
        logger.error("Full traceback:", exc_info=True)
        sys.exit(1)
