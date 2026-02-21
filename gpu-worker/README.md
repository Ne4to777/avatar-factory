# GPU Worker Setup Guide

Инструкция по установке GPU сервера на стационарный ПК с RTX 4070 Ti.

## Системные требования

- **GPU:** NVIDIA RTX 4070 Ti (12GB VRAM) или лучше
- **CUDA:** 11.8 или выше
- **Python:** 3.10 или выше
- **RAM:** 16GB+
- **Место на диске:** ~20GB для моделей

## Установка (Windows)

### 1. Установите Python 3.10+

Скачайте с [python.org](https://www.python.org/downloads/)

Проверьте установку:
```cmd
python --version
```

### 2. Установите CUDA Toolkit 11.8

Скачайте с [NVIDIA Developer](https://developer.nvidia.com/cuda-11-8-0-download-archive)

Проверьте установку:
```cmd
nvcc --version
nvidia-smi
```

### 3. Клонируйте репозиторий (если еще не сделали)

```cmd
cd C:\Projects
git clone https://github.com/yourusername/avatar-factory.git
cd avatar-factory\gpu-worker
```

### 4. Создайте виртуальное окружение

```cmd
python -m venv venv
venv\Scripts\activate
```

### 5. Установите PyTorch с CUDA

```cmd
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
```

Проверьте GPU:
```cmd
python -c "import torch; print(torch.cuda.is_available()); print(torch.cuda.get_device_name(0))"
```

Должно вывести:
```
True
NVIDIA GeForce RTX 4070 Ti
```

### 6. Установите зависимости

```cmd
pip install -r requirements.txt
```

### 7. Клонируйте SadTalker

```cmd
git clone https://github.com/OpenTalker/SadTalker.git
cd SadTalker
pip install -r requirements.txt
cd ..
```

### 8. Скачайте модели

Создайте скрипт `download_models.py`:

```python
import torch
from diffusers import StableDiffusionXLPipeline
import os

print("📥 Downloading models...")

# 1. Silero TTS (автоматически загрузится при первом использовании)
print("1/3 Silero TTS...")
model, _ = torch.hub.load(
    repo_or_dir='snakers4/silero-models',
    model='silero_tts',
    language='ru',
    speaker='v3_1_ru'
)
print("✅ Silero TTS ready")

# 2. Stable Diffusion XL
print("2/3 Stable Diffusion XL...")
pipeline = StableDiffusionXLPipeline.from_pretrained(
    "stabilityai/stable-diffusion-xl-base-1.0",
    torch_dtype=torch.float16,
    use_safetensors=True,
    variant="fp16"
)
print("✅ Stable Diffusion XL ready")

# 3. SadTalker checkpoints
print("3/3 SadTalker checkpoints...")
print("Run: cd SadTalker && bash scripts/download_models.sh")
print("✅ All models ready!")
```

Запустите:
```cmd
python download_models.py
```

### 9. Скачайте чекпоинты SadTalker

```cmd
cd SadTalker
bash scripts/download_models.sh
cd ..
```

Или скачайте вручную:
- [SadTalker checkpoints](https://github.com/OpenTalker/SadTalker#-quick-start)

Поместите в `SadTalker/checkpoints/`

### 10. Создайте `.env` файл

```cmd
copy .env.example .env
notepad .env
```

Отредактируйте:
```env
GPU_API_KEY=your-secret-gpu-key-12345
HOST=0.0.0.0
PORT=8001
```

### 11. Запустите сервер

```cmd
python server.py
```

Вы должны увидеть:
```
🚀 Loading AI models...
✅ GPU: NVIDIA GeForce RTX 4070 Ti (12.0GB VRAM)
✅ SadTalker loaded
✅ Stable Diffusion XL loaded
✅ Silero TTS loaded
🎉 All models loaded successfully!
🚀 Starting GPU Server on 0.0.0.0:8001
```

### 12. Проверьте работу

Откройте браузер:
```
http://localhost:8001/health
```

Должно вывести JSON со статусом GPU.

## Установка (Linux/Ubuntu)

### 1. Установите зависимости

```bash
sudo apt update
sudo apt install -y python3.10 python3-pip python3-venv git ffmpeg
```

### 2. Установите CUDA

```bash
wget https://developer.download.nvidia.com/compute/cuda/11.8.0/local_installers/cuda_11.8.0_520.61.05_linux.run
sudo sh cuda_11.8.0_520.61.05_linux.run
```

Добавьте в `~/.bashrc`:
```bash
export PATH=/usr/local/cuda-11.8/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-11.8/lib64:$LD_LIBRARY_PATH
```

### 3. Установите PyTorch

```bash
cd gpu-worker
python3 -m venv venv
source venv/bin/activate
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
```

### 4. Продолжайте с шага 6 из инструкции Windows

## Использование

### Запуск сервера

**Windows:**
```cmd
cd gpu-worker
venv\Scripts\activate
python server.py
```

**Linux:**
```bash
cd gpu-worker
source venv/bin/activate
python server.py
```

### Автозапуск (Windows Service)

Используйте [NSSM](https://nssm.cc/):

```cmd
nssm install AvatarFactoryGPU "C:\Projects\avatar-factory\gpu-worker\venv\Scripts\python.exe" "C:\Projects\avatar-factory\gpu-worker\server.py"
nssm start AvatarFactoryGPU
```

### Автозапуск (Linux systemd)

Создайте `/etc/systemd/system/avatar-factory-gpu.service`:

```ini
[Unit]
Description=Avatar Factory GPU Server
After=network.target

[Service]
Type=simple
User=your-username
WorkingDirectory=/home/your-username/avatar-factory/gpu-worker
Environment="PATH=/home/your-username/avatar-factory/gpu-worker/venv/bin"
ExecStart=/home/your-username/avatar-factory/gpu-worker/venv/bin/python server.py
Restart=always

[Install]
WantedBy=multi-user.target
```

Запустите:
```bash
sudo systemctl enable avatar-factory-gpu
sudo systemctl start avatar-factory-gpu
sudo systemctl status avatar-factory-gpu
```

## Мониторинг

### Проверка GPU нагрузки

**Windows:**
```cmd
nvidia-smi -l 1
```

**Linux:**
```bash
watch -n 1 nvidia-smi
```

### Логи сервера

```bash
tail -f /tmp/avatar-factory/gpu-server.log
```

## Оптимизация производительности

### 1. Включите xformers

```bash
pip install xformers
```

### 2. Используйте FP16 precision

Уже включено в коде по умолчанию.

### 3. Настройте batch size

В `server.py` измените:
```python
sd_pipeline.enable_attention_slicing(1)
```

### 4. Очистка VRAM

```python
import torch
torch.cuda.empty_cache()
```

## Troubleshooting

### CUDA out of memory

Уменьшите разрешение или batch size:
```python
# В server.py
width = 768  # вместо 1080
height = 1024  # вместо 1920
```

### Медленная генерация

1. Проверьте температуру GPU: `nvidia-smi`
2. Закройте другие приложения использующие GPU
3. Обновите драйвера NVIDIA

### Ошибки импорта

```bash
pip install --upgrade pip
pip install --force-reinstall -r requirements.txt
```

## Производительность RTX 4070 Ti

| Задача | Время |
|--------|-------|
| TTS (10 сек текста) | 1-2 сек |
| SadTalker (10 сек видео) | 30-60 сек |
| Stable Diffusion XL | 5-10 сек |

**Итого:** ~40-70 сек на одно видео (15-30 сек)

## Поддержка

- GitHub Issues: [issues](https://github.com/yourusername/avatar-factory/issues)
- Telegram: @yourusername
