"""
GPU Server для Avatar Factory
Минималистичный FastAPI сервер для обработки AI задач
"""

from fastapi import FastAPI, UploadFile, File, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
import torch
import os
import asyncio
from pathlib import Path
from typing import Optional
import logging

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Paths
TEMP_DIR = Path("/tmp/avatar-factory")
TEMP_DIR.mkdir(exist_ok=True)

# API Key для безопасности
API_KEY = os.getenv("GPU_API_KEY", "your-secret-gpu-key-change-this")

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
    
    logger.info("🚀 Loading AI models...")
    
    # Проверка GPU
    if not torch.cuda.is_available():
        logger.error("❌ CUDA not available!")
        raise RuntimeError("GPU is required")
    
    gpu_name = torch.cuda.get_device_name(0)
    vram = torch.cuda.get_device_properties(0).total_memory / 1e9
    logger.info(f"✅ GPU: {gpu_name} ({vram:.1f}GB VRAM)")
    
    try:
        # 1. SadTalker (lip-sync)
        logger.info("Loading SadTalker...")
        from sadtalker_inference import SadTalkerInference
        sadtalker_model = SadTalkerInference(
            checkpoint_path="./checkpoints",
            device="cuda"
        )
        logger.info("✅ SadTalker loaded")
        
        # 2. Stable Diffusion XL (backgrounds)
        logger.info("Loading Stable Diffusion XL...")
        from diffusers import StableDiffusionXLPipeline
        sd_pipeline = StableDiffusionXLPipeline.from_pretrained(
            "stabilityai/stable-diffusion-xl-base-1.0",
            torch_dtype=torch.float16,
            use_safetensors=True,
            variant="fp16"
        ).to("cuda")
        sd_pipeline.enable_xformers_memory_efficient_attention()
        logger.info("✅ Stable Diffusion XL loaded")
        
        # 3. Silero TTS (русский)
        logger.info("Loading Silero TTS...")
        import torch
        tts_model, _ = torch.hub.load(
            repo_or_dir='snakers4/silero-models',
            model='silero_tts',
            language='ru',
            speaker='v3_1_ru'
        )
        tts_model = tts_model.to("cuda")
        logger.info("✅ Silero TTS loaded")
        
        logger.info("🎉 All models loaded successfully!")
        
    except Exception as e:
        logger.error(f"❌ Failed to load models: {e}")
        raise

@app.get("/")
async def root():
    """Health check"""
    return {"status": "ok", "message": "Avatar Factory GPU Server"}

@app.get("/health")
async def health():
    """Detailed health check"""
    try:
        vram_total = torch.cuda.get_device_properties(0).total_memory / 1e9
        vram_free = (torch.cuda.mem_get_info()[0]) / 1e9
        vram_used = vram_total - vram_free
        
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
    import uvicorn
    
    port = int(os.getenv("PORT", "8001"))
    host = os.getenv("HOST", "0.0.0.0")
    
    logger.info(f"🚀 Starting GPU Server on {host}:{port}")
    
    uvicorn.run(
        app,
        host=host,
        port=port,
        log_level="info"
    )
