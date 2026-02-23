# Avatar Factory

AI-powered avatar generation with Text-to-Speech, Lip-Sync, and Background Generation.

## Architecture

- **Frontend Server** (Node.js) - Serves UI and proxies requests
- **GPU Worker** (Python) - Runs AI models on NVIDIA GPU

## Setup

### 1. GPU Worker (Windows with NVIDIA GPU)

```bash
cd gpu-worker
install-final.bat
download-musetalk-models.bat
fix-vae-simple.bat
```

Start GPU server:
```bash
cd gpu-worker
venv\Scripts\python.exe server.py
```

### 2. Frontend Server (Mac/Windows/Linux)

```bash
# Install dependencies
npm install

# Start server
npm start
```

Access UI: `http://localhost:3000`

## Configuration

Create `.env` file:

```env
GPU_SERVER_URL=http://192.168.1.100:8001
GPU_API_KEY=your-secret-gpu-key-change-this
PORT=3000
```

## Features

- 🎤 **Text-to-Speech** - Silero TTS with Russian voices
- 🎨 **Background Generation** - Stable Diffusion XL
- 💬 **Lip-Sync Video** - MuseTalk real-time lip-sync

## API

All endpoints require `x-api-key` header.

### Health Check
```bash
curl http://localhost:3000/api/health
```

### TTS
```bash
curl -X POST "http://localhost:3000/api/tts?text=Привет&speaker=xenia"
```

### Background
```bash
curl -X POST http://localhost:3000/api/background \
  -H "Content-Type: application/json" \
  -d '{"prompt": "modern office", "steps": 30}'
```

### Lip-Sync
```bash
curl -X POST http://localhost:3000/api/lipsync \
  -F "image=@avatar.png" \
  -F "audio=@speech.wav" \
  -F "fps=25"
```

## License

MIT
