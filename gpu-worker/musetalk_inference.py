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
    from musetalk.utils.utils import load_all_model, get_file_type, get_video_fps, datagen
    from musetalk.utils.preprocessing import get_landmark_and_bbox, read_imgs
    from musetalk.whisper.audio2feature import Audio2Feature
    logger.info("MuseTalk base modules imported successfully")
except ImportError as e:
    error_msg = f"Failed to import MuseTalk: {e}"
    logger.error(error_msg)
    logger.error("Make sure MuseTalk is cloned and dependencies are installed")
    raise ImportError(error_msg) from e
finally:
    # Restore original working directory
    os.chdir(original_cwd)
    logger.info(f"Restored working directory: {os.getcwd()}")

# Define fallback blending function
def blend_image_simple(background, foreground, bbox):
    """Simple image blending - paste foreground onto background at bbox location"""
    x1, y1, x2, y2 = bbox
    result = background.copy()
    
    # Ensure foreground matches bbox size
    fg_h, fg_w = foreground.shape[:2]
    bbox_h, bbox_w = y2 - y1, x2 - x1
    
    if fg_h != bbox_h or fg_w != bbox_w:
        logger.warning(f"Foreground size {(fg_h, fg_w)} doesn't match bbox size {(bbox_h, bbox_w)}, resizing...")
        foreground = cv2.resize(foreground, (bbox_w, bbox_h))
    
    result[y1:y2, x1:x2] = foreground
    return result

# ALWAYS use our fallback function for blending (MuseTalk's get_image has issues)
get_image = blend_image_simple
logger.info(f"✓ Using blend function: {get_image.__name__}")


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
            
            # Debug: log model types to understand correct order
            logger.info(f"Loaded {len(models)} models:")
            for i, model in enumerate(models):
                model_type = type(model).__name__
                logger.info(f"  Model {i}: {model_type}")
            
            # Handle both V1 (4 values) and V15 (3 values) API
            if len(models) == 4:
                logger.info("MuseTalk V1 detected (4 models)")
                self.audio_processor, self.vae, self.unet, self.pe = models
            elif len(models) == 3:
                logger.info("MuseTalk V15 detected (3 models)")
                # V15 returns: VAE, UNet, PositionalEncoding
                self.vae = models[0]
                self.unet = models[1]
                self.pe = models[2]
                # V15 doesn't include audio_processor in load_all_model, create it manually
                logger.info("Creating Audio2Feature for V15...")
                self.audio_processor = Audio2Feature(model_path="tiny")
                self.audio_processor.model.to(self.device)
                logger.info(f"Audio2Feature loaded and moved to {self.device}")
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
        
        import time
        generation_start = time.time()
        
        image_path = Path(image_path)
        audio_path = Path(audio_path)
        output_path = Path(output_path)
        
        logger.info("=" * 80)
        logger.info("STARTING LIP-SYNC VIDEO GENERATION")
        logger.info(f"  Image: {image_path}")
        logger.info(f"  Audio: {audio_path}")
        logger.info(f"  Output: {output_path}")
        logger.info("=" * 80)
        
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
            try:
                whisper_feature = self.audio_processor.audio2feat(str(audio_path))
                logger.info(f"whisper_feature type: {type(whisper_feature)}, shape: {whisper_feature.shape if hasattr(whisper_feature, 'shape') else 'no shape'}")
                
                whisper_chunks = self.audio_processor.feature2chunks(
                    feature_array=whisper_feature,
                    fps=fps
                )
                logger.info(f"Audio processed: {len(whisper_chunks)} chunks")
                if whisper_chunks:
                    logger.info(f"First chunk type: {type(whisper_chunks[0])}, shape: {whisper_chunks[0].shape if hasattr(whisper_chunks[0], 'shape') else 'no shape'}")
            except FileNotFoundError as e:
                raise RuntimeError(f"Audio processing failed - ffmpeg not found in PATH: {e}") from e
            
            # Extract landmarks and preprocess
            logger.info("Extracting facial landmarks...")
            coord_list, frame_list = get_landmark_and_bbox(
                [str(p) for p in input_img_list],
                bbox_shift
            )
            logger.info(f"Landmarks extracted: {len(coord_list)} coords, {len(frame_list)} frames")
            logger.info(f"coord_list type: {type(coord_list)}, first coord type: {type(coord_list[0]) if coord_list else 'empty'}")
            logger.info(f"frame_list type: {type(frame_list)}, first frame type: {type(frame_list[0]) if frame_list else 'empty'}")
            
            # Prepare latents
            logger.info("Preparing latent representations...")
            input_latent_list = []
            for bbox, frame in zip(coord_list, frame_list):
                x1, y1, x2, y2 = bbox
                crop_frame = frame[y1:y2, x1:x2]
                crop_frame = cv2.resize(crop_frame, (256, 256), interpolation=cv2.INTER_LANCZOS4)
                latents = self.vae.get_latents_for_unet(crop_frame)
                input_latent_list.append(latents)
            
            logger.info(f"Latents prepared: {len(input_latent_list)} items, first latent type: {type(input_latent_list[0])}, shape: {input_latent_list[0].shape if hasattr(input_latent_list[0], 'shape') else 'no shape'}")
            
            # Create cycle for smooth animation
            frame_list_cycle = frame_list + frame_list[::-1]
            coord_list_cycle = coord_list + coord_list[::-1]
            input_latent_list_cycle = input_latent_list + input_latent_list[::-1]
            
            # Generate lip-synced frames using datagen (exactly as in original inference.py)
            logger.info(f"Generating {len(whisper_chunks)} frames...")
            logger.info(f"whisper_chunks type: {type(whisper_chunks)}, first chunk type: {type(whisper_chunks[0])}")
            logger.info(f"input_latent_list_cycle type: {type(input_latent_list_cycle)}, first latent type: {type(input_latent_list_cycle[0])}")
            res_frame_list = []
            
            # datagen expects TENSORS, not numpy arrays - convert both whisper and latents to tensors
            whisper_chunks_tensor = []
            for chunk in whisper_chunks:
                if isinstance(chunk, np.ndarray):
                    whisper_chunks_tensor.append(torch.from_numpy(chunk).float())
                elif isinstance(chunk, torch.Tensor):
                    whisper_chunks_tensor.append(chunk.float())
                else:
                    whisper_chunks_tensor.append(torch.FloatTensor(chunk))
            
            # Latents are already tensors from VAE, keep them as is
            logger.info(f"Converted {len(whisper_chunks_tensor)} whisper chunks to tensors")
            logger.info(f"First whisper tensor type: {type(whisper_chunks_tensor[0])}, shape: {whisper_chunks_tensor[0].shape}")
            logger.info(f"input_latent_list_cycle has {len(input_latent_list_cycle)} latents, first type: {type(input_latent_list_cycle[0])}")
            
            try:
                logger.info("Creating datagen generator...")
                gen = datagen(whisper_chunks_tensor, input_latent_list_cycle, batch_size)
                logger.info("datagen generator created successfully")
            except Exception as e:
                logger.error(f"Failed to create datagen: {type(e).__name__}: {e}")
                raise
            
            logger.info("Starting batch processing loop...")
            import time
            total_batches = (len(whisper_chunks_tensor) + batch_size - 1) // batch_size
            logger.info(f"Total batches to process: {total_batches}")
            
            try:
                for i, (whisper_batch, latent_batch) in enumerate(gen):
                    batch_start = time.time()
                    progress_pct = ((i + 1) / total_batches) * 100
                    logger.info(f"=== Batch {i+1}/{total_batches} ({progress_pct:.1f}%) ===")
                    
                    # datagen already returns tensors, just move to device
                    audio_feature_batch = whisper_batch.to(self.unet.device)
                    latent_batch = latent_batch.to(self.unet.device)
                    
                    # Apply PE (V15 has it, V1 uses separate pe model)
                    if self.pe is not None:
                        audio_feature_batch = self.pe(audio_feature_batch)
                    
                    logger.info(f"  → Running UNet inference...")
                    unet_start = time.time()
                    
                    # Generate
                    pred_latents = self.unet.model(
                        latent_batch,
                        self.timesteps,
                        encoder_hidden_states=audio_feature_batch
                    ).sample
                    
                    unet_time = time.time() - unet_start
                    logger.info(f"  → UNet done in {unet_time:.2f}s")
                    logger.info(f"  → pred_latents shape: {pred_latents.shape}, dtype: {pred_latents.dtype}, device: {pred_latents.device}")
                    logger.info(f"  → Starting VAE decode (this may take 30-60 seconds)...")
                    vae_start = time.time()
                    
                    # Decode latents to frames (decode one by one to avoid memory issues)
                    recon = []
                    batch_size_vae = pred_latents.shape[0]
                    logger.info(f"  → Decoding {batch_size_vae} latents...")
                    
                    for j in range(batch_size_vae):
                        if j % 2 == 0:  # Log every 2 frames
                            elapsed = time.time() - vae_start
                            logger.info(f"    → Decoding frame {j+1}/{batch_size_vae} (elapsed: {elapsed:.1f}s)")
                        
                        single_latent = pred_latents[j:j+1]
                        decoded_frame = self.vae.decode_latents(single_latent)
                        recon.extend(decoded_frame)
                    
                    vae_time = time.time() - vae_start
                    batch_time = time.time() - batch_start
                    logger.info(f"  → VAE decoded {len(recon)} frames in {vae_time:.2f}s ({vae_time/len(recon):.2f}s per frame)")
                    logger.info(f"  → Batch {i+1} completed in {batch_time:.2f}s total")
                    
                    for res_frame in recon:
                        res_frame_list.append(res_frame)
            except Exception as e:
                logger.error(f"Error in batch processing loop: {type(e).__name__}: {e}")
                logger.error(f"Error occurred at batch {i if 'i' in locals() else 'unknown'}")
                import traceback
                logger.error(f"Traceback:\n{traceback.format_exc()}")
                raise
            
            # Blend results back to original frames
            total_frames = len(res_frame_list)
            logger.info(f"Blending {total_frames} generated frames...")
            blend_start = time.time()
            
            for i, res_frame in enumerate(res_frame_list):
                if i % 5 == 0 or i == total_frames - 1:  # Log every 5 frames
                    progress_pct = ((i + 1) / total_frames) * 100
                    logger.info(f"  → Blending frame {i+1}/{total_frames} ({progress_pct:.1f}%)")
                
                bbox = coord_list_cycle[i % len(coord_list_cycle)]
                ori_frame = frame_list_cycle[i % len(frame_list_cycle)].copy()
                x1, y1, x2, y2 = bbox
                
                # Resize res_frame to match bbox
                res_frame = cv2.resize(
                    res_frame.astype(np.uint8),
                    (x2 - x1, y2 - y1)
                )
                
                # Blend using get_image function
                try:
                    combine_frame = get_image(ori_frame, res_frame, bbox)
                except Exception as e:
                    logger.error(f"Blending failed for frame {i}: {type(e).__name__}: {e}")
                    logger.error(f"  ori_frame shape: {ori_frame.shape}, res_frame shape: {res_frame.shape}, bbox: {bbox}")
                    raise
                
                cv2.imwrite(str(result_dir / f"{i:08d}.png"), combine_frame)
            
            blend_time = time.time() - blend_start
            logger.info(f"Blending completed in {blend_time:.2f}s")
            
            # Create video
            logger.info("Creating output video with ffmpeg...")
            video_start = time.time()
            temp_video = temp_dir / "temp.mp4"
            
            # Check ffmpeg availability
            import subprocess
            try:
                subprocess.run(["ffmpeg", "-version"], capture_output=True, check=True)
            except (FileNotFoundError, subprocess.CalledProcessError) as e:
                raise RuntimeError(
                    "ffmpeg not found. Please install ffmpeg and add to PATH:\n"
                    "  Download from: https://ffmpeg.org/download.html\n"
                    "  Or use: choco install ffmpeg (with Chocolatey)\n"
                ) from e
            
            logger.info(f"  → Step 1/2: Encoding frames to video (fps={fps})...")
            cmd_img2video = (
                f"ffmpeg -y -v fatal -r {fps} -f image2 "
                f"-i {result_dir}/%08d.png -vcodec libx264 "
                f"-vf format=rgb24,scale=out_color_matrix=bt709,format=yuv420p "
                f"-crf 18 {temp_video}"
            )
            
            encode_start = time.time()
            result = os.system(cmd_img2video)
            encode_time = time.time() - encode_start
            
            if result != 0:
                raise RuntimeError(f"ffmpeg frames-to-video failed with code {result}")
            logger.info(f"  → Video encoded in {encode_time:.2f}s")
            
            logger.info(f"  → Step 2/2: Merging audio...")
            cmd_combine_audio = (
                f"ffmpeg -y -v fatal -i {audio_path} "
                f"-i {temp_video} {output_path}"
            )
            
            merge_start = time.time()
            result = os.system(cmd_combine_audio)
            merge_time = time.time() - merge_start
            
            if result != 0:
                raise RuntimeError(f"ffmpeg audio merge failed with code {result}")
            
            video_time = time.time() - video_start
            logger.info(f"  → Audio merged in {merge_time:.2f}s")
            logger.info(f"Video creation completed in {video_time:.2f}s total")
            
            total_time = time.time() - generation_start
            logger.info("=" * 80)
            logger.info(f"✅ VIDEO GENERATION COMPLETED SUCCESSFULLY")
            logger.info(f"   Output: {output_path}")
            logger.info(f"   Total time: {total_time:.2f}s ({total_time/60:.1f} minutes)")
            logger.info("=" * 80)
            
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
