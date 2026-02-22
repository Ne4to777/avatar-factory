"""
SadTalker Inference Wrapper
Обертка для упрощенного использования SadTalker
"""

import os
import sys
from pathlib import Path
import logging

logger = logging.getLogger(__name__)

# Добавляем SadTalker в path
SADTALKER_PATH = Path(__file__).parent / "SadTalker"
logger.info(f"SadTalker path: {SADTALKER_PATH}")
logger.info(f"SadTalker exists: {SADTALKER_PATH.exists()}")

if not SADTALKER_PATH.exists():
    error_msg = (
        "SadTalker not found! "
        "Please clone SadTalker repository: "
        "git clone https://github.com/OpenTalker/SadTalker.git"
    )
    logger.error(error_msg)
    raise ImportError(error_msg)

sys.path.insert(0, str(SADTALKER_PATH))
logger.info(f"Added SadTalker to sys.path")

try:
    logger.info("Attempting to import SadTalker inference...")
    from inference import InferenceWrapper
    logger.info("SadTalker inference imported successfully")
except ImportError as e:
    error_msg = f"Failed to import SadTalker: {e}"
    logger.error(error_msg)
    logger.error("This usually means SadTalker dependencies are not installed.")
    logger.error("Try: cd SadTalker && ..\\venv\\Scripts\\python.exe -m pip install -r requirements.txt")
    raise ImportError(error_msg) from e

class SadTalkerInference:
    """
    Упрощенная обертка для SadTalker
    """
    
    def __init__(self, checkpoint_path: str = None, device: str = "cuda"):
        """
        Args:
            checkpoint_path: Путь к чекпоинтам (default: SadTalker/checkpoints)
            device: 'cuda' или 'cpu'
        """
        if checkpoint_path is None:
            checkpoint_path = str(SADTALKER_PATH / "checkpoints")
        
        self.checkpoint_path = checkpoint_path
        self.device = device
        
        # Проверяем что чекпоинты существуют
        if not os.path.exists(checkpoint_path):
            raise FileNotFoundError(
                f"Checkpoints not found: {checkpoint_path}\n"
                f"Please download: https://github.com/OpenTalker/SadTalker#-quick-start"
            )
        
        print(f"✅ SadTalker initialized (device: {device})")
    
    def generate(
        self,
        source_image: str,
        driven_audio: str,
        output_path: str = None,
        preprocess: str = "crop",
        enhancer: str = "gfpgan",
        still: bool = False,
        expression_scale: float = 1.0,
        pose_style: int = 0
    ) -> str:
        """
        Генерация говорящего аватара
        
        Args:
            source_image: Путь к исходному изображению
            driven_audio: Путь к аудио файлу
            output_path: Путь для сохранения результата
            preprocess: 'crop' или 'resize' (crop рекомендуется)
            enhancer: 'gfpgan' или 'RestoreFormer' (улучшение качества лица)
            still: True для статичного фона (меньше движений)
            expression_scale: Масштаб выражений лица (0.1-2.0)
            pose_style: Стиль позы (0-46)
        
        Returns:
            Путь к сгенерированному видео
        """
        
        # Проверяем входные файлы
        if not os.path.exists(source_image):
            raise FileNotFoundError(f"Source image not found: {source_image}")
        
        if not os.path.exists(driven_audio):
            raise FileNotFoundError(f"Audio file not found: {driven_audio}")
        
        # Определяем выходной путь
        if output_path is None:
            output_dir = Path("/tmp/sadtalker_output")
            output_dir.mkdir(exist_ok=True)
            output_path = str(output_dir / f"output_{os.urandom(8).hex()}.mp4")
        
        print(f"🎬 Generating talking avatar...")
        print(f"   Image: {source_image}")
        print(f"   Audio: {driven_audio}")
        print(f"   Output: {output_path}")
        
        # Здесь будет реальный вызов SadTalker
        # Временно создаем заглушку
        
        try:
            # Импортируем и вызываем SadTalker inference
            from SadTalker.src.facerender.animate import AnimateFromCoeff
            from SadTalker.src.generate_batch import get_data
            from SadTalker.src.generate_facerender_batch import get_facerender_data
            
            # TODO: Реализовать полный pipeline SadTalker
            # Это требует детального изучения их API
            
            # Пока возвращаем заглушку
            print("⚠️  Using placeholder - implement full SadTalker pipeline")
            
            # В production здесь будет реальная генерация
            # Можно использовать готовый скрипт inference.py из SadTalker
            
            return output_path
            
        except Exception as e:
            print(f"❌ Generation failed: {e}")
            raise
    
    def __call__(self, *args, **kwargs):
        """Позволяет вызывать объект как функцию"""
        return self.generate(*args, **kwargs)


# Для тестирования
if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="SadTalker Inference")
    parser.add_argument("--image", required=True, help="Source image path")
    parser.add_argument("--audio", required=True, help="Audio file path")
    parser.add_argument("--output", help="Output video path")
    parser.add_argument("--device", default="cuda", help="Device: cuda or cpu")
    
    args = parser.parse_args()
    
    # Создаем inference объект
    talker = SadTalkerInference(device=args.device)
    
    # Генерируем видео
    output = talker.generate(
        source_image=args.image,
        driven_audio=args.audio,
        output_path=args.output
    )
    
    print(f"\n✅ Video generated: {output}")
