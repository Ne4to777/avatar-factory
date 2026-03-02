# Avatar Factory API Reference

Complete API documentation for the Avatar Factory Next.js application.

**Base URL:** `http://localhost:3000` (or your deployment URL)

## Authentication

The Next.js API routes do **not** require authentication for development. Production deployments should add authentication (e.g., Clerk, NextAuth) — see `app/api/videos/create/route.ts` for the `userId` TODO.

The **GPU Worker** (port 8001) requires an `x-api-key` header. Set `GPU_API_KEY` in `.env` and configure the same key on the GPU server.

---

## Endpoints

### 1. POST /api/videos/create

Create a new video generation job. The video is queued for processing by the background worker.

#### Request

| Header | Required | Description |
|--------|----------|-------------|
| Content-Type | Yes | `application/json` |

**Body:**

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| text | string | Yes | — | Text to speak (1–500 characters) |
| photoUrl | string (URL) | No* | — | URL of avatar photo (from `/api/upload`) |
| avatarId | string | No* | — | ID of saved avatar |
| backgroundStyle | string | No | `"simple"` | Background style (see below) |
| backgroundUrl | string (URL) | No | — | Pre-generated background image URL |
| voiceId | string | No | `"ru_speaker_female"` | Voice preset ID |
| format | string | No | `"VERTICAL"` | Video format (see below) |

*Either `photoUrl` or `avatarId` must be provided.

**backgroundStyle values:**
- `simple` — Modern minimalist office
- `professional` — Corporate meeting room
- `creative` — Artistic studio
- `minimalist` — Clean workspace

**format values:**
- `VERTICAL` — 9:16 (Reels, Shorts)
- `HORIZONTAL` — 16:9 (YouTube)
- `SQUARE` — 1:1 (Instagram)

#### Example Request

```bash
curl -X POST http://localhost:3000/api/videos/create \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Привет! Это тестовое видео.",
    "photoUrl": "http://localhost:9000/avatar-videos/avatars/abc123.jpg",
    "backgroundStyle": "professional",
    "format": "VERTICAL"
  }'
```

#### Success Response (200)

```json
{
  "success": true,
  "data": {
    "videoId": "clx123abc456def789"
  }
}
```

#### Error Responses

| Status | Description |
|--------|-------------|
| 400 | Invalid input — check `details` for validation errors |
| 500 | Internal server error |

**400 Example (validation):**
```json
{
  "error": "Invalid input",
  "details": [
    {
      "code": "too_small",
      "minimum": 1,
      "type": "string",
      "path": ["text"]
    }
  ]
}
```

**400 Example (missing photo):**
```json
{
  "error": "Either photoUrl or avatarId must be provided"
}
```

---

### 2. GET /api/videos/:id

Get video status and result URL.

#### Request

| Parameter | Description |
|-----------|-------------|
| id | Video ID (from create response) |

#### Example Request

```bash
curl http://localhost:3000/api/videos/clx123abc456def789
```

#### Success Response (200)

```json
{
  "success": true,
  "data": {
    "id": "clx123abc456def789",
    "status": "COMPLETED",
    "progress": 100,
    "videoUrl": "http://localhost:9000/avatar-videos/videos/xyz789.mp4",
    "thumbnailUrl": "http://localhost:9000/avatar-videos/thumbnails/xyz789.jpg",
    "error": null
  }
}
```

**Status values:**
- `PENDING` — Queued, not yet started
- `PROCESSING` — Worker is generating
- `COMPLETED` — Ready; `videoUrl` and `thumbnailUrl` are set
- `FAILED` — Error; `error` contains message

#### Error Responses

| Status | Description |
|--------|-------------|
| 404 | Video not found |
| 500 | Internal server error |

```json
{
  "error": "Video not found"
}
```

---

### 3. DELETE /api/videos/:id

Delete a video and its associated files from storage.

#### Request

| Parameter | Description |
|-----------|-------------|
| id | Video ID |

#### Example Request

```bash
curl -X DELETE http://localhost:3000/api/videos/clx123abc456def789
```

#### Success Response (200)

```json
{
  "success": true,
  "data": {
    "message": "Video deleted successfully"
  }
}
```

#### Error Responses

| Status | Description |
|--------|-------------|
| 404 | Video not found |
| 500 | Internal server error |

---

### 4. POST /api/upload

Upload a file (avatar photo, background image, or audio). Returns a public URL for use in video creation.

#### Request

| Header | Required | Description |
|--------|----------|-------------|
| Content-Type | Yes | `multipart/form-data` |

**Form fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| file | File | Yes | Image (JPEG, PNG, WEBP) or audio (MP3, WAV) |
| type | string | No | `avatar`, `background`, or `temp` (default) |

**Constraints:**
- Max file size: 10 MB
- Allowed types: `image/jpeg`, `image/png`, `image/webp`, `audio/mpeg`, `audio/wav`

#### Example Request

```bash
curl -X POST http://localhost:3000/api/upload \
  -F "file=@avatar.jpg" \
  -F "type=avatar"
```

#### Success Response (200)

```json
{
  "success": true,
  "url": "http://localhost:9000/avatar-videos/avatars/abc123-avatar.jpg",
  "key": "avatars/abc123-avatar.jpg",
  "size": 245760,
  "type": "image/jpeg"
}
```

Use the `url` value as `photoUrl` or `backgroundUrl` in `POST /api/videos/create`.

#### Error Responses

| Status | Description |
|--------|-------------|
| 400 | No file, file too large, or invalid type |
| 500 | Upload failed (storage error) |

**400 Examples:**
```json
{ "error": "No file provided" }
```
```json
{ "error": "File too large. Max size is 10MB" }
```
```json
{ "error": "Invalid file type. Allowed: JPEG, PNG, WEBP, MP3, WAV" }
```

---

### 5. GET /api/health

System health check. Verifies database, Redis, GPU server, and storage (S3/MinIO).

#### Example Request

```bash
curl http://localhost:3000/api/health
```

#### Success Response (200)

```json
{
  "status": "healthy",
  "checks": {
    "database": true,
    "redis": true,
    "gpu": true,
    "storage": true
  },
  "metrics": {
    "timestamp": "2026-03-02T12:00:00.000Z",
    "queue": {
      "waiting": 0,
      "active": 1,
      "completed": 42,
      "failed": 0
    },
    "gpu": {
      "available": true,
      "name": "NVIDIA GeForce RTX 4070 Ti"
    },
    "videos": {
      "total": 43,
      "byStatus": {
        "PENDING": 1,
        "PROCESSING": 1,
        "COMPLETED": 40,
        "FAILED": 1
      }
    }
  },
  "version": "1.0.0"
}
```

**status values:**
- `healthy` — All checks passed
- `degraded` — One or more checks failed
- `error` — Health check itself failed (500)

#### Error Response (500)

```json
{
  "status": "error",
  "error": "Error message"
}
```

---

## Error Response Format

All API errors follow this structure:

```json
{
  "error": "Short error description",
  "message": "Optional detailed message",
  "details": []
}
```

- `error` — Always present
- `message` — Present for 500 errors
- `details` — Present for validation (400) errors; array of Zod validation objects

---

## Typical Workflow

1. **Upload avatar photo:** `POST /api/upload` with `type=avatar`
2. **Create video:** `POST /api/videos/create` with `photoUrl` from step 1
3. **Poll status:** `GET /api/videos/:id` until `status` is `COMPLETED` or `FAILED`
4. **Use result:** When `COMPLETED`, use `videoUrl` and `thumbnailUrl`

---

## Related Documentation

- [QUICKSTART.md](./QUICKSTART.md) — Setup and first video
- [gpu-worker/README.md](../gpu-worker/README.md) — GPU server setup
- [PROJECT_SUMMARY.md](./PROJECT_SUMMARY.md) — Architecture overview
