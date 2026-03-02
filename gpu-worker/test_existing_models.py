"""
Тест всех существующих моделей
Запускать ПОСЛЕ любого изменения зависимостей!
"""

import sys
import torch
import logging
from pathlib import Path

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)

def test_cuda():
    """Проверка CUDA"""
    logger.info("=" * 70)
    logger.info("1. CUDA Check")
    logger.info("=" * 70)
    
    try:
        assert torch.cuda.is_available(), "CUDA not available"
        gpu_name = torch.cuda.get_device_name(0)
        vram = torch.cuda.get_device_properties(0).total_memory / 1e9
        logger.info(f"✅ CUDA OK: {gpu_name} ({vram:.1f}GB)")
        return True
    except Exception as e:
        logger.error(f"❌ CUDA FAILED: {e}")
        return False

def test_silero_tts():
    """Проверка Silero TTS"""
    logger.info("\n" + "=" * 70)
    logger.info("2. Silero TTS")
    logger.info("=" * 70)
    
    try:
        import soundfile as sf
        
        logger.info("Loading Silero TTS...")
        model, _ = torch.hub.load(
            repo_or_dir='snakers4/silero-models',
            model='silero_tts',
            language='ru',
            speaker='v3_1_ru',
            verbose=False
        )
        model.to("cuda")
        
        logger.info("Generating test audio...")
        sample_rate = 48000
        audio = model.apply_tts(text="Тест", speaker="xenia", sample_rate=sample_rate)
        
        assert audio is not None, "No audio generated"
        assert len(audio) > 0, "Empty audio"
        
        logger.info(f"✅ Silero TTS OK (generated {len(audio)} samples)")
        
        # Очистка VRAM
        del model
        torch.cuda.empty_cache()
        
        return True
    except Exception as e:
        logger.error(f"❌ Silero TTS FAILED: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_stable_diffusion_xl():
    """Проверка Stable Diffusion XL"""
    logger.info("\n" + "=" * 70)
    logger.info("3. Stable Diffusion XL")
    logger.info("=" * 70)
    
    try:
        from diffusers import StableDiffusionXLPipeline
        
        logger.info("Loading SDXL...")
        pipeline = StableDiffusionXLPipeline.from_pretrained(
            "stabilityai/stable-diffusion-xl-base-1.0",
            torch_dtype=torch.float16,
            use_safetensors=True,
            variant="fp16"
        ).to("cuda")
        
        logger.info("Generating test image...")
        image = pipeline(
            prompt="test",
            num_inference_steps=10,  # Быстрый тест
            height=512,
            width=512
        ).images[0]
        
        assert image is not None, "No image generated"
        assert image.size == (512, 512), f"Wrong size: {image.size}"
        
        logger.info(f"✅ SDXL OK (generated {image.size} image)")
        
        # Очистка VRAM
        del pipeline
        torch.cuda.empty_cache()
        
        return True
    except Exception as e:
        logger.error(f"❌ SDXL FAILED: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_musetalk():
    """Проверка MuseTalk"""
    logger.info("\n" + "=" * 70)
    logger.info("4. MuseTalk")
    logger.info("=" * 70)
    
    try:
        # Проверяем только импорт (полный тест требует файлы)
        from musetalk_inference import MuseTalkInference
        
        logger.info("MuseTalk imports OK")
        
        # Попытка инициализации (если есть модели)
        musetalk_path = Path("MuseTalk")
        if musetalk_path.exists():
            logger.info("Initializing MuseTalk...")
            model = MuseTalkInference(device="cuda")
            logger.info("✅ MuseTalk OK (initialized)")
            del model
            torch.cuda.empty_cache()
        else:
            logger.warning("⚠️  MuseTalk models not found (run download-musetalk-models.bat)")
            logger.info("✅ MuseTalk OK (imports work)")
        
        return True
    except Exception as e:
        logger.error(f"❌ MuseTalk FAILED: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_dependencies():
    """Проверка критичных зависимостей"""
    logger.info("\n" + "=" * 70)
    logger.info("5. Dependencies Check")
    logger.info("=" * 70)
    
    deps = {
        "torch": "2.1.0",
        "numpy": "1.26",  # Префикс
        "opencv-python": None,
        "transformers": "4.36",
        "diffusers": "0.25",
        "accelerate": "0.25",
    }
    
    all_ok = True
    
    for package, expected_prefix in deps.items():
        try:
            module = __import__(package.replace("-", "_"))
            version = getattr(module, "__version__", "unknown")
            
            if expected_prefix and not version.startswith(expected_prefix):
                logger.warning(f"⚠️  {package}: {version} (expected {expected_prefix}.x)")
                all_ok = False
            else:
                logger.info(f"✅ {package}: {version}")
        except ImportError as e:
            logger.error(f"❌ {package}: NOT INSTALLED")
            all_ok = False
    
    return all_ok

def main():
    """Запуск всех тестов"""
    logger.info("\n" + "=" * 70)
    logger.info("🧪 TESTING ALL EXISTING MODELS")
    logger.info("=" * 70)
    logger.info("\n⚠️  ВАЖНО: Запускайте после ЛЮБОГО изменения зависимостей!")
    logger.info("⚠️  Если хоть один тест упал → ОТКАТЫВАЙТЕ изменения!\n")
    
    results = {
        "CUDA": test_cuda(),
        "Dependencies": test_dependencies(),
        "Silero TTS": test_silero_tts(),
        "Stable Diffusion XL": test_stable_diffusion_xl(),
        "MuseTalk": test_musetalk(),
    }
    
    # Итоги
    logger.info("\n" + "=" * 70)
    logger.info("📊 RESULTS")
    logger.info("=" * 70)
    
    all_passed = all(results.values())
    
    for test_name, passed in results.items():
        status = "✅ PASS" if passed else "❌ FAIL"
        logger.info(f"{status}: {test_name}")
    
    logger.info("\n" + "=" * 70)
    
    if all_passed:
        logger.info("🎉 ALL TESTS PASSED - SAFE TO PROCEED")
        logger.info("=" * 70)
        return 0
    else:
        logger.error("❌ SOME TESTS FAILED - DO NOT PROCEED!")
        logger.error("⚠️  Откатите изменения в зависимостях!")
        logger.error("=" * 70)
        return 1

if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        logger.info("\n⚠️  Test interrupted by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"\n💥 CRITICAL ERROR: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
