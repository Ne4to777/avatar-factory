"""
Download AI Models Script
Скрипт для скачивания всех необходимых AI моделей
"""

import os
import sys
import torch
from pathlib import Path

def check_gpu():
    """Проверка доступности GPU"""
    print("\n🔍 Checking GPU...")
    
    if not torch.cuda.is_available():
        print("❌ CUDA not available!")
        print("   Please install CUDA Toolkit 11.8+")
        print("   https://developer.nvidia.com/cuda-downloads")
        sys.exit(1)
    
    gpu_name = torch.cuda.get_device_name(0)
    vram = torch.cuda.get_device_properties(0).total_memory / 1e9
    
    print(f"✅ GPU: {gpu_name}")
    print(f"✅ VRAM: {vram:.1f}GB")
    
    if vram < 8:
        print("⚠️  Warning: Less than 8GB VRAM may cause issues")
        print("   Recommended: 10GB+ for smooth operation")
    
    return True

def download_silero_tts():
    """Скачивание Silero TTS"""
    print("\n📥 1/3 Downloading Silero TTS (Russian)...")
    
    try:
        model, _ = torch.hub.load(
            repo_or_dir='snakers4/silero-models',
            model='silero_tts',
            language='ru',
            speaker='v3_1_ru',
            force_reload=True
        )
        
        # Тест генерации
        audio = model.apply_tts(
            text="Привет! Это тестовое сообщение.",
            speaker='xenia',
            sample_rate=48000
        )
        
        print("✅ Silero TTS downloaded and tested")
        print(f"   Size: ~100MB")
        return True
    except Exception as e:
        print(f"❌ Failed to download Silero TTS: {e}")
        return False

def download_stable_diffusion():
    """Скачивание Stable Diffusion XL"""
    print("\n📥 2/3 Downloading Stable Diffusion XL...")
    print("   This will take 10-15 minutes (~7GB)")
    
    try:
        from diffusers import StableDiffusionXLPipeline
        
        pipeline = StableDiffusionXLPipeline.from_pretrained(
            "stabilityai/stable-diffusion-xl-base-1.0",
            torch_dtype=torch.float16,
            use_safetensors=True,
            variant="fp16"
        )
        
        print("✅ Stable Diffusion XL downloaded")
        print(f"   Size: ~7GB")
        return True
    except Exception as e:
        print(f"❌ Failed to download Stable Diffusion: {e}")
        return False

def setup_sadtalker():
    """Настройка SadTalker"""
    print("\n📥 3/3 Setting up SadTalker...")
    
    sadtalker_dir = Path("SadTalker")
    
    if not sadtalker_dir.exists():
        print("   Cloning SadTalker repository...")
        os.system("git clone https://github.com/OpenTalker/SadTalker.git")
    
    if not sadtalker_dir.exists():
        print("❌ Failed to clone SadTalker")
        return False
    
    print("✅ SadTalker repository cloned")
    
    # Проверка checkpoints
    checkpoints_dir = sadtalker_dir / "checkpoints"
    
    if not checkpoints_dir.exists() or not list(checkpoints_dir.glob("*.pth")):
        print("\n⚠️  SadTalker checkpoints not found!")
        print("   Please download manually:")
        print("   1. Go to: https://github.com/OpenTalker/SadTalker#-quick-start")
        print("   2. Download checkpoints (~2GB)")
        print("   3. Extract to: SadTalker/checkpoints/")
        print("\n   Or run (if on Linux/Mac):")
        print("   cd SadTalker && bash scripts/download_models.sh")
        return False
    
    print("✅ SadTalker checkpoints found")
    print(f"   Size: ~2GB")
    return True

def verify_installations():
    """Проверка установки всех компонентов"""
    print("\n🔍 Verifying installations...")
    
    checks = {
        'torch': False,
        'diffusers': False,
        'transformers': False,
        'soundfile': False,
        'opencv': False,
    }
    
    try:
        import torch
        checks['torch'] = True
        print("✅ PyTorch")
    except:
        print("❌ PyTorch not installed")
    
    try:
        import diffusers
        checks['diffusers'] = True
        print("✅ Diffusers")
    except:
        print("❌ Diffusers not installed")
    
    try:
        import transformers
        checks['transformers'] = True
        print("✅ Transformers")
    except:
        print("❌ Transformers not installed")
    
    try:
        import soundfile
        checks['soundfile'] = True
        print("✅ Soundfile")
    except:
        print("❌ Soundfile not installed")
    
    try:
        import cv2
        checks['opencv'] = True
        print("✅ OpenCV")
    except:
        print("❌ OpenCV not installed")
    
    all_ok = all(checks.values())
    
    if not all_ok:
        print("\n⚠️  Some dependencies are missing!")
        print("   Run: pip install -r requirements.txt")
        return False
    
    return True

def main():
    """Main function"""
    print("=" * 60)
    print("🚀 Avatar Factory - Model Downloader")
    print("=" * 60)
    
    # 1. Проверка GPU
    if not check_gpu():
        sys.exit(1)
    
    # 2. Проверка зависимостей
    if not verify_installations():
        sys.exit(1)
    
    print("\n" + "=" * 60)
    print("📦 Downloading models (this may take 20-30 minutes)")
    print("=" * 60)
    
    # 3. Скачивание моделей
    results = {
        'silero': download_silero_tts(),
        'stable_diffusion': download_stable_diffusion(),
        'sadtalker': setup_sadtalker(),
    }
    
    # 4. Итоги
    print("\n" + "=" * 60)
    print("📊 Download Summary")
    print("=" * 60)
    
    total_size_gb = 0
    
    if results['silero']:
        print("✅ Silero TTS: OK (~0.1GB)")
        total_size_gb += 0.1
    else:
        print("❌ Silero TTS: FAILED")
    
    if results['stable_diffusion']:
        print("✅ Stable Diffusion XL: OK (~7GB)")
        total_size_gb += 7
    else:
        print("❌ Stable Diffusion XL: FAILED")
    
    if results['sadtalker']:
        print("✅ SadTalker: OK (~2GB)")
        total_size_gb += 2
    else:
        print("❌ SadTalker: FAILED (manual setup required)")
    
    print(f"\n📦 Total downloaded: ~{total_size_gb:.1f}GB")
    
    # 5. Следующие шаги
    if all(results.values()):
        print("\n" + "=" * 60)
        print("🎉 All models downloaded successfully!")
        print("=" * 60)
        print("\nNext steps:")
        print("1. Create .env file:")
        print("   echo 'GPU_API_KEY=your-secret-key' > .env")
        print("\n2. Start the server:")
        print("   python server.py")
        print("\n3. Test the server:")
        print("   curl http://localhost:8001/health")
    else:
        print("\n" + "=" * 60)
        print("⚠️  Some models failed to download")
        print("=" * 60)
        print("\nPlease check the errors above and try again.")
        print("You may need to download some models manually.")
        sys.exit(1)

if __name__ == "__main__":
    main()
