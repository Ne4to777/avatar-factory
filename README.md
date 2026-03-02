# Avatar Factory

AI-powered avatar video generation with Text-to-Speech, Lip-Sync, and Background Generation.

## Documentation

| Document | Description |
|----------|-------------|
| [docs/QUICKSTART.md](docs/QUICKSTART.md) | Fast setup and first video |
| [docs/API.md](docs/API.md) | Full API reference |
| [docs/PROJECT_SUMMARY.md](docs/PROJECT_SUMMARY.md) | Architecture overview |
| [gpu-worker/README.md](gpu-worker/README.md) | GPU server installation |

## Architecture

- **Next.js** (Node.js) — Frontend, API routes, VideoService layer
- **PostgreSQL** — Videos and users
- **Redis** — BullMQ job queue
- **S3/MinIO** — File storage
- **GPU Worker** (Python) — AI models on NVIDIA GPU

### VideoService Layer

The `VideoService` in `lib/services/video.service.ts` handles video lifecycle:
- Create and queue jobs
- Get status with progress
- Delete video and storage assets

API routes (`app/api/videos/*`) delegate to VideoService.

## Quick Start

### 1. Infrastructure

```bash
# Start PostgreSQL, Redis, MinIO
docker-compose up -d

# Wait for init
sleep 10

# Migrations
npx prisma migrate dev
```

### 2. Environment

```bash
cp .env.example .env
```

Edit `.env` — use S3_* vars (or MINIO_* for legacy):

```env
# Database
DATABASE_URL="postgresql://avatar:avatar_password@localhost:5432/avatar_factory"

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379

# Storage (S3/MinIO)
S3_ENDPOINT=localhost
S3_PORT=9000
S3_ACCESS_KEY=minioadmin
S3_SECRET_KEY=minioadmin123
S3_BUCKET=avatar-videos

# GPU Worker
GPU_SERVER_URL=http://192.168.1.100:8001
GPU_API_KEY=your-secret-gpu-key-change-this
```

### 3. Start Application

**Terminal 1 — Next.js:**
```bash
npm run dev
```

**Terminal 2 — Worker:**
```bash
npm run worker
```

Open: http://localhost:3000

### 4. GPU Worker (Separate PC)

See [gpu-worker/README.md](gpu-worker/README.md). Start the GPU server on a machine with an NVIDIA GPU.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| **Database** | | |
| DATABASE_URL | required | PostgreSQL connection string |
| **Redis** | | |
| REDIS_HOST | localhost | Redis host |
| REDIS_PORT | 6379 | Redis port |
| **Storage (S3/MinIO)** | | |
| S3_ENDPOINT | localhost | S3/MinIO endpoint |
| S3_PORT | 9000 | S3/MinIO port |
| S3_ACCESS_KEY | minioadmin | Access key |
| S3_SECRET_KEY | minioadmin123 | Secret key |
| S3_BUCKET | avatar-videos | Bucket name |
| S3_USE_SSL | false | Use HTTPS |
| S3_REGION | us-east-1 | Region |

**Legacy:** `MINIO_*` vars are supported when `S3_*` are not set. `S3_*` takes precedence.

| Variable | Default | Description |
|----------|---------|-------------|
| **GPU** | | |
| GPU_SERVER_URL | http://localhost:8001 | GPU server base URL |
| GPU_API_KEY | development-key | API key for GPU server |
| **App** | | |
| PORT | 3000 | Next.js port |

## Testing

```bash
# Unit tests
npm run test:unit

# Integration tests
npm run test:integration

# All tests
npm run test

# E2E video generation
npm run test:e2e
```

## Features

- Text-to-Speech (Silero TTS)
- Lip-sync video (MuseTalk)
- Background generation (Stable Diffusion XL)
- Vertical / horizontal / square formats
- Background styles: simple, professional, creative, minimalist

## API Overview

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /api/videos/create | Create video job |
| GET | /api/videos/:id | Get video status |
| DELETE | /api/videos/:id | Delete video |
| POST | /api/upload | Upload avatar/background |
| GET | /api/health | Health check |

Full details: [docs/API.md](docs/API.md)

## License

MIT
