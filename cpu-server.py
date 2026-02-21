#!/usr/bin/env python3
"""
CPU-версия GPU сервера для тестирования на ноутбуке
Использует только легкие модели, работающие на CPU:
- Silero TTS (русский голос)
- FFmpeg для простого lip-sync (статичное изображение)
"""

from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.responses import FileResponse
import uvicorn
import tempfile
import os
from pathlib import Path
import subprocess
import torch

# Временная директория
TEMP_DIR = Path(tempfile.gettempdir()) / "avatar-factory-cpu"
TEMP_DIR.mkdir(exist_ok=True)

# ==========================================
# Загрузка моделей на уровне модуля
# ==========================================
print("=" * 60)
print("🖥️  Avatar Factory CPU Server - Initialization")
print("=" * 60)
print("Loading Silero TTS model...")

# Глобальные переменные
model = None
sample_rate = 48000
device = torch.device('cpu')
TTS_LOADED = False

# Загружаем модель синхронно
torch.set_num_threads(4)

try:
    # Загружаем модель и utils
    model, example_text = torch.hub.load(
        repo_or_dir='snakers4/silero-models',
        model='silero_tts',
        language='ru',
        speaker='v4_ru'
    )
    
    # .to(device) изменяет модель in-place и возвращает None!
    # Просто вызываем для эффекта, но не присваиваем
    model.to(device)
    
    print(f"✅ Silero TTS loaded successfully on CPU")
    print(f"   Model type: {type(model).__name__}")
    TTS_LOADED = True
except Exception as e:
    print(f"❌ Failed to load Silero TTS: {e}")
    import traceback
    traceback.print_exc()
    TTS_LOADED = False
    model = None

print(f"TTS Ready: {TTS_LOADED}, Model: {type(model).__name__ if model else 'None'}")
print("=" * 60)

# ==========================================
# FastAPI Application
# ==========================================
app = FastAPI(title="Avatar Factory CPU Server")

@app.get("/health")
async def health():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "mode": "CPU",
        "message": "CPU server running - uses lightweight models",
        "device": "CPU",
        "models_loaded": {
            "tts": TTS_LOADED,
            "lipsync": True,  # FFmpeg-based
            "background": False  # Disabled on CPU
        }
    }

@app.post("/api/tts")
async def generate_tts(
    text: str = Form(...),
    language: str = Form("ru"),
    speaker: str = Form("xenia")
):
    """
    Генерация речи через Silero TTS (работает на CPU)
    """
    if not TTS_LOADED or model is None:
        raise HTTPException(status_code=503, detail="TTS model not loaded")
    
    print(f"[CPU TTS] Generating: {text[:50]}...")
    
    try:
        output_path = TEMP_DIR / f"tts_cpu_{os.urandom(4).hex()}.wav"
        
        # Генерируем аудио через Silero
        # Модель работает синхронно, но FastAPI ожидает async
        import soundfile as sf
        import numpy as np
        
        # Вызываем модель напрямую
        audio = model.apply_tts(
            text=text,
            speaker=speaker,
            sample_rate=sample_rate
        )
        
        # Конвертируем tensor в numpy
        if torch.is_tensor(audio):
            audio_np = audio.detach().cpu().numpy()
        else:
            audio_np = audio
        
        # Сохраняем в WAV
        sf.write(str(output_path), audio_np, sample_rate)
        
        print(f"✅ TTS generated: {output_path.name} ({len(audio_np)/sample_rate:.1f}s)")
        
        return FileResponse(
            str(output_path),
            media_type="audio/wav",
            filename="tts_output.wav"
        )
        
    except Exception as e:
        print(f"❌ TTS error: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"TTS generation failed: {str(e)}")

@app.post("/api/lipsync")
async def generate_lipsync(
    image: UploadFile = File(...),
    audio: UploadFile = File(...)
):
    """
    Простой lip-sync через FFmpeg (статичное изображение + аудио)
    Без реального lip-sync, но работает на CPU
    """
    print(f"[CPU LIPSYNC] Creating video from image + audio...")
    
    try:
        # Сохраняем файлы
        image_data = await image.read()
        audio_data = await audio.read()
        
        temp_image = TEMP_DIR / f"img_{os.urandom(4).hex()}.png"
        temp_audio = TEMP_DIR / f"audio_{os.urandom(4).hex()}.wav"
        output_path = TEMP_DIR / f"lipsync_cpu_{os.urandom(4).hex()}.mp4"
        
        with open(temp_image, "wb") as f:
            f.write(image_data)
        with open(temp_audio, "wb") as f:
            f.write(audio_data)
        
        # Получаем длительность аудио
        probe = subprocess.run([
            'ffprobe', '-v', 'error',
            '-show_entries', 'format=duration',
            '-of', 'default=noprint_wrappers=1:nokey=1',
            str(temp_audio)
        ], capture_output=True, text=True, timeout=10)
        
        duration_str = probe.stdout.strip()
        try:
            duration = float(duration_str) if duration_str and duration_str != 'N/A' else 1.0
        except ValueError:
            duration = 1.0
        
        print(f"  Audio duration: {duration}s")
        
        # Создаем видео из статичного изображения + аудио
        result = subprocess.run([
            'ffmpeg', '-y',
            '-loop', '1',
            '-framerate', '30',
            '-i', str(temp_image),
            '-i', str(temp_audio),
            '-vf', 'scale=640:480:force_original_aspect_ratio=decrease,pad=640:480:(ow-iw)/2:(oh-ih)/2',
            '-c:v', 'libx264',
            '-t', str(duration),
            '-pix_fmt', 'yuv420p',
            '-c:a', 'aac',
            '-b:a', '128k',
            '-ar', '44100',
            '-shortest',
            '-movflags', '+faststart',
            str(output_path)
        ], capture_output=True, timeout=60)
        
        if result.returncode != 0:
            error_msg = result.stderr.decode() if result.stderr else "Unknown error"
            print(f"❌ FFmpeg failed: {error_msg}")
            raise HTTPException(status_code=500, detail=f"FFmpeg failed: {error_msg}")
        
        # Удаляем временные файлы
        temp_image.unlink()
        temp_audio.unlink()
        
        print(f"✅ Video created: {output_path.name}")
        
        return FileResponse(
            str(output_path),
            media_type="video/mp4",
            filename="lipsync_output.mp4"
        )
        
    except subprocess.TimeoutExpired:
        raise HTTPException(status_code=500, detail="FFmpeg timeout")
    except Exception as e:
        print(f"❌ Lipsync error: {e}")
        raise HTTPException(status_code=500, detail=f"Lipsync failed: {str(e)}")

@app.post("/api/generate-background")
async def generate_background(
    prompt: str = Form(...),
    style: str = Form("photorealistic")
):
    """
    Генерация фона отключена на CPU версии
    Возвращает простое цветное изображение
    """
    print(f"[CPU BG] Creating simple background...")
    
    try:
        output_path = TEMP_DIR / f"bg_cpu_{os.urandom(4).hex()}.png"
        
        # Создаем простой градиент через FFmpeg
        subprocess.run([
            'ffmpeg', '-y',
            '-f', 'lavfi',
            '-i', f'color=c=0x4a5568:s=1080x1920:d=1',
            '-frames:v', '1',
            str(output_path)
        ], check=True, capture_output=True, timeout=10)
        
        print(f"✅ Background created: {output_path.name}")
        
        return FileResponse(
            str(output_path),
            media_type="image/png",
            filename="background.png"
        )
        
    except Exception as e:
        print(f"❌ Background error: {e}")
        raise HTTPException(status_code=500, detail=f"Background generation failed: {str(e)}")

if __name__ == "__main__":
    print("")
    print(f"Status before server start:")
    print(f"  TTS_LOADED: {TTS_LOADED}")
    print(f"  model is None: {model is None}")
    print("")
    print("Starting server on http://0.0.0.0:8001")
    print("=" * 60)
    
    uvicorn.run(app, host="0.0.0.0", port=8001, log_level="info")
