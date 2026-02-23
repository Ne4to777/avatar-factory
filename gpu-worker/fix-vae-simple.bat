@echo off
REM Create missing config.json for sd-vae

cd /d "%~dp0"

echo.
echo Creating config.json for sd-vae...
echo.

(
echo {
echo   "_class_name": "AutoencoderKL",
echo   "_diffusers_version": "0.25.0",
echo   "act_fn": "silu",
echo   "block_out_channels": [128, 256, 512, 512],
echo   "down_block_types": ["DownEncoderBlock2D", "DownEncoderBlock2D", "DownEncoderBlock2D", "DownEncoderBlock2D"],
echo   "in_channels": 3,
echo   "latent_channels": 4,
echo   "layers_per_block": 2,
echo   "norm_num_groups": 32,
echo   "out_channels": 3,
echo   "sample_size": 512,
echo   "up_block_types": ["UpDecoderBlock2D", "UpDecoderBlock2D", "UpDecoderBlock2D", "UpDecoderBlock2D"]
echo }
) > MuseTalk\models\sd-vae\config.json

echo [OK] config.json created
echo.
echo Now start the server:
echo   venv\Scripts\python.exe server.py
echo.
pause
