#!/usr/bin/env python3
"""
Mock GPU Server для тестирования Avatar Factory
Возвращает заглушки вместо реальной AI генерации
"""

from fastapi import FastAPI, File, UploadFile, Form
from fastapi.responses import FileResponse, JSONResponse
import uvicorn
import tempfile
import os
from pathlib import Path

app = FastAPI(title="Mock GPU Server")

# Временная директория
TEMP_DIR = Path(tempfile.gettempdir()) / "mock-gpu-server"
TEMP_DIR.mkdir(exist_ok=True)

@app.get("/health")
async def health():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "mode": "MOCK",
        "message": "Mock GPU server running - returns fake data for testing",
        "models_loaded": {
            "tts": True,
            "lipsync": True,
            "background": True
        }
    }

@app.post("/api/tts")
async def generate_tts(
    text: str = Form(...),
    language: str = Form("ru"),
    speaker: str = Form("female")
):
    """
    Mock TTS endpoint - создает пустой аудио файл
    """
    print(f"[MOCK TTS] Text: {text[:50]}... | Language: {language} | Speaker: {speaker}")
    
    # Создаем пустой wav файл (44 байта = WAV header)
    output_path = TEMP_DIR / f"tts_mock_{os.urandom(4).hex()}.wav"
    
    # Минимальный WAV header (16kHz, mono, 1 секунда тишины)
    wav_data = bytes([
        # RIFF header
        0x52, 0x49, 0x46, 0x46,  # "RIFF"
        0x24, 0x00, 0x00, 0x00,  # File size - 8
        0x57, 0x41, 0x56, 0x45,  # "WAVE"
        # fmt chunk
        0x66, 0x6D, 0x74, 0x20,  # "fmt "
        0x10, 0x00, 0x00, 0x00,  # Chunk size (16)
        0x01, 0x00,              # Audio format (1 = PCM)
        0x01, 0x00,              # Channels (1 = mono)
        0x80, 0x3E, 0x00, 0x00,  # Sample rate (16000 Hz)
        0x00, 0x7D, 0x00, 0x00,  # Byte rate
        0x02, 0x00,              # Block align
        0x10, 0x00,              # Bits per sample (16)
        # data chunk
        0x64, 0x61, 0x74, 0x61,  # "data"
        0x00, 0x00, 0x00, 0x00,  # Data size (0 = silence)
    ])
    
    with open(output_path, "wb") as f:
        f.write(wav_data)
    
    return FileResponse(
        str(output_path),
        media_type="audio/wav",
        filename="mock_tts.wav"
    )

@app.post("/api/lipsync")
async def generate_lipsync(
    image: UploadFile = File(...),
    audio: UploadFile = File(...)
):
    """
    Mock lip-sync endpoint - создает простое видео из изображения
    """
    print(f"[MOCK LIPSYNC] Image: {image.filename} | Audio: {audio.filename}")
    
    # Сохраняем загруженное изображение
    image_data = await image.read()
    audio_data = await audio.read()
    
    # Сохраняем во временные файлы
    temp_image = TEMP_DIR / f"img_{os.urandom(4).hex()}.png"
    temp_audio = TEMP_DIR / f"audio_{os.urandom(4).hex()}.wav"
    output_path = TEMP_DIR / f"lipsync_mock_{os.urandom(4).hex()}.mp4"
    
    with open(temp_image, "wb") as f:
        f.write(image_data)
    with open(temp_audio, "wb") as f:
        f.write(audio_data)
    
    # Используем ffmpeg для создания простого видео (изображение + аудио)
    # Сначала масштабируем изображение до нормального размера (640x480)
    import subprocess
    try:
        # Получаем длительность аудио
        probe = subprocess.run([
            'ffprobe', '-v', 'error',
            '-show_entries', 'format=duration',
            '-of', 'default=noprint_wrappers=1:nokey=1',
            str(temp_audio)
        ], capture_output=True, text=True)
        
        duration_str = probe.stdout.strip()
        try:
            duration = max(1.0, min(5.0, float(duration_str))) if duration_str and duration_str != 'N/A' else 1.0
        except ValueError:
            duration = 1.0
        
        # Создаем видео из изображения
        subprocess.run([
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
        ], check=True, capture_output=True, timeout=30)
        
        # Удаляем временные файлы
        temp_image.unlink()
        temp_audio.unlink()
        
        return FileResponse(
            str(output_path),
            media_type="video/mp4",
            filename="mock_lipsync.mp4"
        )
    except Exception as e:
        return JSONResponse({
            "error": "FFmpeg failed",
            "details": str(e)
        }, status_code=500)

@app.post("/api/generate-background")
async def generate_background(
    prompt: str = Form(...),
    style: str = Form("photorealistic")
):
    """
    Mock background generation - создает простое изображение
    """
    print(f"[MOCK BG] Prompt: {prompt} | Style: {style}")
    
    # Создаем минимальное PNG изображение 1x1 pixel
    output_path = TEMP_DIR / f"bg_mock_{os.urandom(4).hex()}.png"
    
    # Минимальный PNG (белый пиксель 1x1)
    png_data = bytes([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,  # PNG signature
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,  # IHDR chunk
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,  # 1x1 pixels
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
        0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,  # IDAT chunk
        0x54, 0x08, 0xD7, 0x63, 0xF8, 0xFF, 0xFF, 0x3F,
        0x00, 0x05, 0xFE, 0x02, 0xFE, 0xDC, 0xCC, 0x59,
        0xE7, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,  # IEND chunk
        0x44, 0xAE, 0x42, 0x60, 0x82
    ])
    
    with open(output_path, "wb") as f:
        f.write(png_data)
    
    return FileResponse(
        str(output_path),
        media_type="image/png",
        filename="mock_background.png"
    )

if __name__ == "__main__":
    print("=" * 60)
    print("🎭 Mock GPU Server for Avatar Factory")
    print("=" * 60)
    print("⚠️  This is a MOCK server for testing only!")
    print("   It returns fake data instead of real AI generation")
    print("")
    print("Starting server on http://0.0.0.0:8001")
    print("=" * 60)
    
    uvicorn.run(app, host="0.0.0.0", port=8001, log_level="info")
