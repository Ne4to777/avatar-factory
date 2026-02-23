"""
MuseTalk Inference Wrapper
Simplified API wrapper for MuseTalk lip-sync generation
"""

import os
import sys
from pathlib import Path
import logging
import torch
import numpy as np
import cv2
from typing import Optional, Union

logger = logging.getLogger(__name__)

# Add MuseTalk to path
MUSETALK_PATH = Path(__file__).parent / "MuseTalk"
logger.info(f"MuseTalk path: {MUSETALK_PATH}")

if not MUSETALK_PATH.exists():
    error_msg = (
        "MuseTalk not found! "
        "Please clone: git clone https://github.com/TMElyralab/MuseTalk.git"
    )
    logger.error(error_msg)
    raise ImportError(error_msg)

sys.path.insert(0, str(MUSETALK_PATH))
logger.info("Added MuseTalk to sys.path")

# MuseTalk modules use relative paths, so we need to change cwd temporarily
original_cwd = os.getcwd()
os.chdir(MUSETALK_PATH)
logger.info(f"Changed working directory to MuseTalk: {os.getcwd()}")

try:
    logger.info("Importing MuseTalk modules...")
    from musetalk.utils.utils import load_all_model, get_file_type, get_video_fps
    from musetalk.utils.preprocessing import get_landmark_and_bbox, read_imgs
    from musetalk.utils.blending import get_image
    logger.info("MuseTalk modules imported successfully")
except ImportError as e:
    error_msg = f"Failed to import MuseTalk: {e}"
    logger.error(error_msg)
    logger.error("Make sure MuseTalk is cloned and dependencies are installed")
    raise ImportError(error_msg) from e
finally:
    # Restore original working directory
    os.chdir(original_cwd)
    logger.info(f"Restored working directory: {os.getcwd()}")


class MuseTalkInference:
    """
    Simplified wrapper for MuseTalk lip-sync generation
    """
    
    def __init__(self, device: str = "cuda"):
        """
        Initialize MuseTalk models
        
        Args:
            device: 'cuda' or 'cpu'
        """
        self.device = torch.device(device if torch.cuda.is_available() else "cpu")
        logger.info(f"Initializing MuseTalk on device: {self.device}")
        
        # MuseTalk needs to be in its directory to load models
        original_cwd = os.getcwd()
        os.chdir(MUSETALK_PATH)
        logger.info(f"Changed to MuseTalk directory: {os.getcwd()}")
        
        # Load all MuseTalk models
        try:
            logger.info("Loading MuseTalk models...")
            models = load_all_model()
            
            # Handle both V1 (4 values) and V15 (3 values) API
            if len(models) == 4:
                logger.info("MuseTalk V1 detected (4 models)")
                self.audio_processor, self.vae, self.unet, self.pe = models
            elif len(models) == 3:
                logger.info("MuseTalk V15 detected (3 models)")
                # V15 order appears to be: vae, audio_processor, unet
                self.vae, self.audio_processor, self.unet = models
                self.pe = None  # V15 doesn't use separate PE model
            else:
                raise ValueError(f"Unexpected number of models: {len(models)}")
            
            logger.info("MuseTalk models loaded successfully")
            
            self.timesteps = torch.tensor([0], device=self.device)
            self.initialized = True
            
        except Exception as e:
            logger.error(f"Failed to load MuseTalk models: {e}")
            self.initialized = False
            raise
        finally:
            # Restore original working directory
            os.chdir(original_cwd)
            logger.info(f"Restored working directory: {os.getcwd()}")
    
    @torch.no_grad()
    def generate(
        self,
        image_path: Union[str, Path],
        audio_path: Union[str, Path],
        output_path: Union[str, Path],
        bbox_shift: int = 0,
        batch_size: int = 8,
        fps: int = 25
    ) -> Path:
        """
        Generate lip-synced video from image and audio
        
        Args:
            image_path: Path to source image or video
            audio_path: Path to audio file
            output_path: Path for output video
            bbox_shift: Face bounding box shift adjustment
            batch_size: Batch size for inference
            fps: Output video FPS
            
        Returns:
            Path to generated video
        """
        if not self.initialized:
            raise RuntimeError("MuseTalk not initialized")
        
        image_path = Path(image_path)
        audio_path = Path(audio_path)
        output_path = Path(output_path)
        
        logger.info(f"Generating lip-sync video:")
        logger.info(f"  Image: {image_path}")
        logger.info(f"  Audio: {audio_path}")
        logger.info(f"  Output: {output_path}")
        
        # Create temp directories
        temp_dir = Path("temp") / "musetalk"
        frames_dir = temp_dir / "frames"
        result_dir = temp_dir / "result"
        frames_dir.mkdir(parents=True, exist_ok=True)
        result_dir.mkdir(parents=True, exist_ok=True)
        
        try:
            # Extract frames from input
            if get_file_type(str(image_path)) == "video":
                logger.info("Extracting frames from video...")
                cmd = f"ffmpeg -v fatal -i {image_path} -start_number 0 {frames_dir}/%08d.png"
                os.system(cmd)
                input_img_list = sorted(frames_dir.glob("*.png"))
                fps = get_video_fps(str(image_path))
            else:
                logger.info("Using single image...")
                input_img_list = [image_path]
            
            # Process audio
            logger.info("Processing audio features...")
            whisper_feature = self.audio_processor.audio2feat(str(audio_path))
            whisper_chunks = self.audio_processor.feature2chunks(
                feature_array=whisper_feature,
                fps=fps
            )
            
            # Extract landmarks and preprocess
            logger.info("Extracting facial landmarks...")
            coord_list, frame_list = get_landmark_and_bbox(
                [str(p) for p in input_img_list],
                bbox_shift
            )
            
            # Prepare latents
            logger.info("Preparing latent representations...")
            input_latent_list = []
            for bbox, frame in zip(coord_list, frame_list):
                x1, y1, x2, y2 = bbox
                crop_frame = frame[y1:y2, x1:x2]
                crop_frame = cv2.resize(crop_frame, (256, 256), interpolation=cv2.INTER_LANCZOS4)
                latents = self.vae.get_latents_for_unet(crop_frame)
                input_latent_list.append(latents)
            
            # Create cycle for smooth animation
            frame_list_cycle = frame_list + frame_list[::-1]
            coord_list_cycle = coord_list + coord_list[::-1]
            input_latent_list_cycle = input_latent_list + input_latent_list[::-1]
            
            # Generate lip-synced frames
            logger.info(f"Generating {len(whisper_chunks)} frames...")
            res_frame_list = []
            
            for i in range(0, len(whisper_chunks), batch_size):
                batch_end = min(i + batch_size, len(whisper_chunks))
                whisper_batch = whisper_chunks[i:batch_end]
                latent_batch = input_latent_list_cycle[i:batch_end]
                
                # Convert to tensors
                audio_feature_batch = torch.stack([
                    torch.FloatTensor(arr) for arr in whisper_batch
                ]).to(self.unet.device)
                
                # Apply PE if available (V1 only, V15 has it built-in)
                if self.pe is not None:
                    audio_feature_batch = self.pe(audio_feature_batch)
                
                # Generate
                pred_latents = self.unet.model(
                    latent_batch,
                    self.timesteps,
                    encoder_hidden_states=audio_feature_batch
                ).sample
                
                recon = self.vae.decode_latents(pred_latents)
                res_frame_list.extend(recon)
            
            # Blend results back to original frames
            logger.info("Blending generated frames...")
            for i, res_frame in enumerate(res_frame_list):
                bbox = coord_list_cycle[i % len(coord_list_cycle)]
                ori_frame = frame_list_cycle[i % len(frame_list_cycle)].copy()
                x1, y1, x2, y2 = bbox
                
                res_frame = cv2.resize(
                    res_frame.astype(np.uint8),
                    (x2 - x1, y2 - y1)
                )
                
                combine_frame = get_image(ori_frame, res_frame, bbox)
                cv2.imwrite(str(result_dir / f"{i:08d}.png"), combine_frame)
            
            # Create video
            logger.info("Creating output video...")
            temp_video = temp_dir / "temp.mp4"
            
            cmd_img2video = (
                f"ffmpeg -y -v fatal -r {fps} -f image2 "
                f"-i {result_dir}/%08d.png -vcodec libx264 "
                f"-vf format=rgb24,scale=out_color_matrix=bt709,format=yuv420p "
                f"-crf 18 {temp_video}"
            )
            os.system(cmd_img2video)
            
            cmd_combine_audio = (
                f"ffmpeg -y -v fatal -i {audio_path} "
                f"-i {temp_video} {output_path}"
            )
            os.system(cmd_combine_audio)
            
            logger.info(f"Video generated successfully: {output_path}")
            return output_path
            
        finally:
            # Cleanup temp files
            import shutil
            if temp_dir.exists():
                shutil.rmtree(temp_dir)
                logger.info("Cleaned up temporary files")


def test_musetalk():
    """Test MuseTalk installation"""
    try:
        logger.info("Testing MuseTalk installation...")
        mt = MuseTalkInference(device="cuda")
        logger.info("MuseTalk initialized successfully!")
        return True
    except Exception as e:
        logger.error(f"MuseTalk test failed: {e}")
        return False


if __name__ == "__main__":
    # Test run
    logging.basicConfig(level=logging.INFO)
    test_musetalk()
