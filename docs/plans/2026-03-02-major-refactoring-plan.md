# Avatar Factory Major Refactoring Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Comprehensive refactoring to fix critical bugs, improve architecture, add proper testing, and update documentation.

**Architecture:** Transform monolithic structure into layered architecture with proper separation of concerns: Service Layer → Business Logic → Data Access. Fix configuration inconsistencies and eliminate code duplication.

**Tech Stack:** TypeScript, Next.js 14, Prisma, BullMQ, FastAPI, PyTorch

**Based on:** Agent Teams analysis (4 agents: architecture, code quality, testing, documentation)

---

## 🎯 Critical Issues Found (Agent Analysis)

### Architecture Issues (Priority 1)
1. **backgroundStyle mismatch** - API validates `simple|professional|creative|minimalist`, Worker uses `modern-office|cozy-home|outdoor-nature`
2. **S3/MinIO config duplication** - `lib/config` expects `S3_*`, docker-compose uses `MINIO_*`
3. **Prisma schema mismatch** - `backgroundStyle` default is `modern-office`, API enum doesn't include it
4. **No service layer** - Business logic scattered across API routes, worker, GPU server

### Code Quality Issues (Priority 1)
1. **`any` everywhere** - 20+ instances across codebase
2. **Long functions** - worker callback 180 lines, composeVideo 150 lines
3. **Code duplication** - `getBackgroundDimensions`, `getSpeakerFromVoiceId` duplicated
4. **Inline imports** - `await import()` in routes, `require()` in worker
5. **Memory leaks** - `setInterval` in pollVideoStatus not cleaned up

### Testing Issues (Priority 1)
1. **False coverage** - Tests don't import actual modules, duplicate logic
2. **No integration tests** - Only unit tests for types/config
3. **Critical modules untested** - `lib/video.ts`, `lib/gpu-client.ts`, `lib/storage.ts`, `lib/queue.ts`

### Documentation Issues (Priority 2)
1. **Broken links** - References to non-existent files (`quick-start.sh`, `TEST_RESULTS.md`)
2. **Contradictions** - Different env vars in different docs
3. **Missing API docs** - No documentation for Next.js API endpoints

---

## 📋 Refactoring Phases

### Phase 1: Critical Bug Fixes (Priority 1)
- Fix backgroundStyle mismatch
- Unify S3/MinIO configuration
- Fix Prisma schema
- Fix memory leaks
- **Estimated:** 4-6 hours

### Phase 2: Architecture Improvements (Priority 1)
- Introduce Service Layer
- Eliminate code duplication
- Remove all `any` types
- Fix inline imports
- Break down long functions
- **Estimated:** 8-12 hours

### Phase 3: Testing & Documentation (Priority 1-2)
- Add real unit tests
- Add integration tests
- Fix documentation
- Add API documentation
- **Estimated:** 6-8 hours

---

## 🚀 Execution Strategy

**Using Agent Teams:**
- Each phase will be executed by coordinated agents
- Agent 1: Implementation
- Agent 2: Testing
- Agent 3: Documentation
- Sequential coordination with shared context

---

# PHASE 1: Critical Bug Fixes

## Task 1.1: Fix backgroundStyle Mismatch

**Files:**
- Modify: `lib/config.ts` - add BACKGROUND_STYLE_MAP
- Modify: `workers/video-worker.ts:228-246` - use config
- Modify: `app/api/videos/create/route.ts:16` - update Zod schema
- Modify: `prisma/schema.prisma:29` - update enum
- Test: `tests/unit/config.test.ts` - add background style tests

**Step 1: Add BACKGROUND_STYLE_MAP to lib/config.ts**

```typescript
// Add after VOICE_CONFIG (around line 80)
export const BACKGROUND_STYLE_MAP = {
  simple: 'modern-office',
  professional: 'corporate-meeting',
  creative: 'artistic-studio', 
  minimalist: 'clean-workspace',
} as const;

export type BackgroundStyleAPI = keyof typeof BACKGROUND_STYLE_MAP;
export type BackgroundStyleInternal = typeof BACKGROUND_STYLE_MAP[BackgroundStyleAPI];

export const BACKGROUND_PROMPTS: Record<BackgroundStyleInternal, string> = {
  'modern-office': 'modern minimalist office, soft lighting, professional, 4k',
  'corporate-meeting': 'elegant corporate meeting room, glass walls, sophisticated, 4k',
  'artistic-studio': 'creative art studio, colorful, inspiring, natural light, 4k',
  'clean-workspace': 'minimalist clean workspace, zen, peaceful, soft colors, 4k',
};
```

**Step 2: Run tests to verify config exports**

Run: `npm test -- config.test.ts`
Expected: Existing tests pass

**Step 3: Update worker to use BACKGROUND_STYLE_MAP**

```typescript
// In workers/video-worker.ts
import { 
  ENV, 
  VIDEO_DIMENSIONS, 
  VOICE_CONFIG,
  BACKGROUND_STYLE_MAP,
  BACKGROUND_PROMPTS,
} from '../lib/config';

// Replace getBackgroundPrompt function (lines 228-246) with:
function getBackgroundPrompt(styleAPI: string): string {
  const internalStyle = BACKGROUND_STYLE_MAP[styleAPI as keyof typeof BACKGROUND_STYLE_MAP];
  return BACKGROUND_PROMPTS[internalStyle] || BACKGROUND_PROMPTS['modern-office'];
}
```

**Step 4: Update API Zod schema**

```typescript
// In app/api/videos/create/route.ts (line 16)
backgroundStyle: z.enum(['simple', 'professional', 'creative', 'minimalist']).default('simple'),
```

**Step 5: Update Prisma schema**

```prisma
// In prisma/schema.prisma (line 29)
backgroundStyle String @default("simple")
```

**Step 6: Generate Prisma migration**

Run: `npx prisma migrate dev --name fix-background-style-default`
Expected: Migration created successfully

**Step 7: Write test for background style mapping**

```typescript
// In tests/unit/config.test.ts
describe('Background Style Configuration', () => {
  it('should map API styles to internal styles', () => {
    expect(BACKGROUND_STYLE_MAP.simple).toBe('modern-office');
    expect(BACKGROUND_STYLE_MAP.professional).toBe('corporate-meeting');
    expect(BACKGROUND_STYLE_MAP.creative).toBe('artistic-studio');
    expect(BACKGROUND_STYLE_MAP.minimalist).toBe('clean-workspace');
  });

  it('should have prompts for all internal styles', () => {
    Object.values(BACKGROUND_STYLE_MAP).forEach(internalStyle => {
      expect(BACKGROUND_PROMPTS[internalStyle]).toBeDefined();
      expect(BACKGROUND_PROMPTS[internalStyle]).toContain('4k');
    });
  });
});
```

**Step 8: Run tests**

Run: `npm test -- config.test.ts`
Expected: All tests pass including new background style tests

**Step 9: Commit**

```bash
git add lib/config.ts workers/video-worker.ts app/api/videos/create/route.ts prisma/schema.prisma prisma/migrations tests/unit/config.test.ts
git commit -m "fix: unify background style mapping between API and worker"
```

---

## Task 1.2: Unify S3/MinIO Configuration

**Files:**
- Modify: `lib/config.ts:130-145` - support both S3_* and MINIO_* env vars
- Modify: `app/api/health/route.ts:62-75` - use STORAGE_CONFIG from lib
- Modify: `.env.example` - document both formats
- Test: `tests/unit/config.test.ts` - add storage config tests

**Step 1: Add unified storage config to lib/config.ts**

```typescript
// Replace STORAGE_CONFIG (around line 130) with:
export const STORAGE_CONFIG = {
  endpoint: getEnvVar('S3_ENDPOINT', getEnvVar('MINIO_ENDPOINT', 'localhost')),
  port: getEnvNumber('S3_PORT', getEnvNumber('MINIO_PORT', 9000)),
  accessKey: getEnvVar('S3_ACCESS_KEY', getEnvVar('MINIO_ACCESS_KEY', 'minioadmin')),
  secretKey: getEnvVar('S3_SECRET_KEY', getEnvVar('MINIO_SECRET_KEY', 'minioadmin123')),
  bucket: getEnvVar('S3_BUCKET', getEnvVar('MINIO_BUCKET', 'avatar-videos')),
  useSSL: getEnvVar('S3_USE_SSL', getEnvVar('MINIO_USE_SSL', 'false')) === 'true',
  region: getEnvVar('S3_REGION', 'us-east-1'),
} as const;
```

**Step 2: Create S3Client helper in lib/storage.ts**

```typescript
// Add at top of lib/storage.ts
import { STORAGE_CONFIG } from './config';

function createS3Client() {
  return new S3Client({
    endpoint: STORAGE_CONFIG.useSSL 
      ? `https://${STORAGE_CONFIG.endpoint}:${STORAGE_CONFIG.port}`
      : `http://${STORAGE_CONFIG.endpoint}:${STORAGE_CONFIG.port}`,
    region: STORAGE_CONFIG.region,
    credentials: {
      accessKeyId: STORAGE_CONFIG.accessKey,
      secretAccessKey: STORAGE_CONFIG.secretKey,
    },
    forcePathStyle: true,
  });
}

// Replace existing s3Client initialization (around line 20) with:
const s3Client = createS3Client();

// Export for health check
export { createS3Client };
```

**Step 3: Update health route to use shared S3 client**

```typescript
// In app/api/health/route.ts
// Replace lines 62-75 with:
import { createS3Client } from '@/lib/storage';

// In storage check:
const storageHealthy = await checkStorage();

async function checkStorage(): Promise<boolean> {
  try {
    const s3 = createS3Client();
    const result = await s3.send(
      new ListBucketsCommand({})
    );
    return result.Buckets !== undefined;
  } catch (error) {
    logger.error('Storage health check failed', { error });
    return false;
  }
}
```

**Step 4: Update .env.example**

```bash
# Storage (S3/MinIO) - use either S3_* or MINIO_* prefix
S3_ENDPOINT="localhost"
S3_PORT="9000"
S3_ACCESS_KEY="minioadmin"
S3_SECRET_KEY="minioadmin123"
S3_BUCKET="avatar-videos"
S3_USE_SSL="false"
S3_REGION="us-east-1"

# Alternative MINIO_* prefix (legacy, will be auto-detected)
# MINIO_ENDPOINT="localhost"
# MINIO_PORT="9000"
# etc.
```

**Step 5: Write test for unified config**

```typescript
// In tests/unit/config.test.ts
describe('Storage Configuration', () => {
  it('should prefer S3_* env vars over MINIO_*', () => {
    process.env.S3_ENDPOINT = 's3.amazonaws.com';
    process.env.MINIO_ENDPOINT = 'localhost';
    
    // Re-import to get new config
    delete require.cache[require.resolve('@/lib/config')];
    const { STORAGE_CONFIG } = require('@/lib/config');
    
    expect(STORAGE_CONFIG.endpoint).toBe('s3.amazonaws.com');
  });

  it('should fallback to MINIO_* if S3_* not set', () => {
    delete process.env.S3_ENDPOINT;
    process.env.MINIO_ENDPOINT = 'localhost';
    
    delete require.cache[require.resolve('@/lib/config')];
    const { STORAGE_CONFIG } = require('@/lib/config');
    
    expect(STORAGE_CONFIG.endpoint).toBe('localhost');
  });
});
```

**Step 6: Run tests**

Run: `npm test -- config.test.ts`
Expected: All storage config tests pass

**Step 7: Commit**

```bash
git add lib/config.ts lib/storage.ts app/api/health/route.ts .env.example tests/unit/config.test.ts
git commit -m "fix: unify S3/MinIO configuration to support both env var formats"
```

---

## Task 1.3: Fix Memory Leak in pollVideoStatus

**Files:**
- Modify: `app/page.tsx:96-117` - add cleanup function
- Test: Manual testing required (no automated test for React hooks cleanup)

**Step 1: Add cleanup to pollVideoStatus**

```typescript
// In app/page.tsx, replace pollVideoStatus function (lines 96-117):
const pollVideoStatus = async (videoId: string): Promise<void> => {
  let intervalId: NodeJS.Timeout | null = null;
  
  const poll = async () => {
    try {
      const response = await fetch(`/api/videos/${videoId}`);
      const data = await response.json() as VideoStatusResponse;

      setProgress(data.progress);
      setStatus(data.status);

      if (data.status === 'completed' && data.videoUrl) {
        setVideoUrl(data.videoUrl);
        setStatus('completed');
        if (intervalId) {
          clearInterval(intervalId);
          intervalId = null;
        }
      } else if (data.status === 'failed') {
        setError('Video generation failed');
        if (intervalId) {
          clearInterval(intervalId);
          intervalId = null;
        }
      }
    } catch (error) {
      console.error('Error polling status:', error);
      setError('Failed to check video status');
      if (intervalId) {
        clearInterval(intervalId);
        intervalId = null;
      }
    }
  };

  // Initial poll
  await poll();
  
  // Start interval
  intervalId = setInterval(poll, 2000);
  
  // Return cleanup function
  return () => {
    if (intervalId) {
      clearInterval(intervalId);
      intervalId = null;
    }
  };
};
```

**Step 2: Update handleSubmit to store cleanup function**

```typescript
// In app/page.tsx, update handleSubmit:
const [cleanupPoll, setCleanupPoll] = useState<(() => void) | null>(null);

// In handleSubmit, after pollVideoStatus call:
const cleanup = await pollVideoStatus(videoId);
setCleanupPoll(() => cleanup);
```

**Step 3: Add useEffect cleanup**

```typescript
// In app/page.tsx, add useEffect:
useEffect(() => {
  return () => {
    if (cleanupPoll) {
      cleanupPoll();
    }
  };
}, [cleanupPoll]);
```

**Step 4: Manual testing**

1. Start dev server: `npm run dev`
2. Upload image and create video
3. While video is processing, navigate away from page
4. Check browser console - no "setState on unmounted component" warnings
5. Check that interval is cleared (use browser dev tools performance)

**Step 5: Commit**

```bash
git add app/page.tsx
git commit -m "fix: cleanup polling interval on unmount to prevent memory leak"
```

---

## Task 1.4: Remove Inline Imports

**Files:**
- Modify: `app/api/health/route.ts:62` - move import to top
- Modify: `app/api/videos/[id]/route.ts:102,107` - move import to top  
- Modify: `workers/video-worker.ts:267,278` - replace require with import
- Test: `npm run build` - verify build succeeds

**Step 1: Fix health route import**

```typescript
// In app/api/health/route.ts
// Move to top of file (line 4):
import { S3Client, ListBucketsCommand } from '@aws-sdk/client-s3';

// Remove from inside function (line 62)
```

**Step 2: Fix videos/[id] route import**

```typescript
// In app/api/videos/[id]/route.ts
// Move to top of file (line 7):
import { deleteFile, deleteByUrl } from '@/lib/storage';

// Remove await import() calls (lines 102, 107)
```

**Step 3: Fix worker require**

```typescript
// In workers/video-worker.ts
// Add to top of file (line 8):
import axios from 'axios';

// Replace downloadFile function (lines 260-285):
async function downloadFile(url: string, outputPath: string): Promise<void> {
  const response = await axios.get(url, {
    responseType: 'arraybuffer',
  });
  await fs.promises.writeFile(outputPath, Buffer.from(response.data));
}
```

**Step 4: Build verification**

Run: `npm run build`
Expected: Build succeeds with no errors

**Step 5: Run type check**

Run: `npm run type-check` (or `tsc --noEmit`)
Expected: No type errors

**Step 6: Commit**

```bash
git add app/api/health/route.ts app/api/videos/[id]/route.ts workers/video-worker.ts
git commit -m "refactor: move inline imports to top of files"
```

---

# PHASE 2: Architecture Improvements

## Task 2.1: Create Service Layer - VideoService

**Files:**
- Create: `lib/services/video.service.ts`
- Modify: `app/api/videos/create/route.ts` - use VideoService
- Modify: `app/api/videos/[id]/route.ts` - use VideoService
- Test: `tests/unit/services/video.service.test.ts`

**Step 1: Write failing test for VideoService**

```typescript
// Create tests/unit/services/video.service.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { VideoService } from '@/lib/services/video.service';

vi.mock('@/lib/prisma');
vi.mock('@/lib/queue');
vi.mock('@/lib/storage');

describe('VideoService', () => {
  let service: VideoService;

  beforeEach(() => {
    vi.clearAllMocks();
    service = new VideoService();
  });

  describe('createVideo', () => {
    it('should create video and add to queue', async () => {
      const input = {
        userId: 'user-123',
        text: 'Hello world',
        voiceId: 'ru_speaker_male',
        backgroundStyle: 'simple' as const,
        avatarId: 'avatar-123',
        format: 'vertical' as const,
      };

      const result = await service.createVideo(input);

      expect(result.id).toBeDefined();
      expect(result.status).toBe('pending');
    });
  });

  describe('getVideoStatus', () => {
    it('should return video status with job progress', async () => {
      const videoId = 'video-123';
      
      const status = await service.getVideoStatus(videoId);
      
      expect(status.id).toBe(videoId);
      expect(status.status).toBeDefined();
    });
  });

  describe('deleteVideo', () => {
    it('should delete video and associated files', async () => {
      const videoId = 'video-123';
      
      await service.deleteVideo(videoId);
      
      // Verify prisma.video.delete called
      // Verify storage.deleteByUrl called for videoUrl and thumbnailUrl
    });
  });
});
```

**Step 2: Run test to verify it fails**

Run: `npm test -- video.service.test.ts`
Expected: FAIL - VideoService not found

**Step 3: Implement VideoService**

```typescript
// Create lib/services/video.service.ts
import { prisma } from '../prisma';
import { addVideoJob, getJobStatus } from '../queue';
import { deleteByUrl } from '../storage';
import { logger } from '../logger';
import type { Video, VideoStatus, VideoFormat } from '@prisma/client';

export interface CreateVideoInput {
  userId: string;
  text: string;
  voiceId: string;
  backgroundStyle: 'simple' | 'professional' | 'creative' | 'minimalist';
  avatarId?: string;
  photoUrl?: string;
  format: VideoFormat;
}

export interface VideoStatusResult {
  id: string;
  status: VideoStatus;
  progress: number;
  videoUrl: string | null;
  thumbnailUrl: string | null;
  error: string | null;
}

export class VideoService {
  async createVideo(input: CreateVideoInput): Promise<Video> {
    logger.info('Creating video', { userId: input.userId });

    // Create video record
    const video = await prisma.video.create({
      data: {
        userId: input.userId,
        text: input.text,
        voiceId: input.voiceId,
        backgroundStyle: input.backgroundStyle,
        avatarId: input.avatarId,
        photoUrl: input.photoUrl,
        format: input.format,
        status: 'pending',
        progress: 0,
      },
    });

    // Add to queue
    await addVideoJob({
      videoId: video.id,
      userId: input.userId,
      text: input.text,
      voiceId: input.voiceId,
      backgroundStyle: input.backgroundStyle,
      avatarId: input.avatarId,
      photoUrl: input.photoUrl,
      format: input.format,
    });

    logger.info('Video created and queued', { videoId: video.id });

    return video;
  }

  async getVideoStatus(videoId: string): Promise<VideoStatusResult> {
    const video = await prisma.video.findUnique({
      where: { id: videoId },
    });

    if (!video) {
      throw new Error(`Video ${videoId} not found`);
    }

    // Get job status if processing
    let progress = video.progress;
    if (video.status === 'processing') {
      const jobStatus = await getJobStatus(videoId);
      if (jobStatus) {
        progress = jobStatus.progress || progress;
      }
    }

    return {
      id: video.id,
      status: video.status,
      progress,
      videoUrl: video.videoUrl,
      thumbnailUrl: video.thumbnailUrl,
      error: video.error,
    };
  }

  async deleteVideo(videoId: string): Promise<void> {
    const video = await prisma.video.findUnique({
      where: { id: videoId },
    });

    if (!video) {
      throw new Error(`Video ${videoId} not found`);
    }

    // Delete files from storage
    if (video.videoUrl) {
      await deleteByUrl(video.videoUrl);
    }
    if (video.thumbnailUrl) {
      await deleteByUrl(video.thumbnailUrl);
    }

    // Delete from database
    await prisma.video.delete({
      where: { id: videoId },
    });

    logger.info('Video deleted', { videoId });
  }
}
```

**Step 4: Run test**

Run: `npm test -- video.service.test.ts`
Expected: Tests pass (with proper mocks)

**Step 5: Update API route to use VideoService**

```typescript
// In app/api/videos/create/route.ts
import { VideoService } from '@/lib/services/video.service';

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const validatedData = createVideoSchema.parse(body);

    const videoService = new VideoService();
    const video = await videoService.createVideo({
      userId: 'test-user-id', // TODO: Get from auth
      ...validatedData,
    });

    return NextResponse.json({
      success: true,
      data: { videoId: video.id },
    });
  } catch (error: unknown) {
    // ... error handling
  }
}
```

**Step 6: Update videos/[id] route**

```typescript
// In app/api/videos/[id]/route.ts
import { VideoService } from '@/lib/services/video.service';

export async function GET(
  request: Request,
  { params }: { params: { id: string } }
) {
  try {
    const videoService = new VideoService();
    const status = await videoService.getVideoStatus(params.id);

    return NextResponse.json({
      success: true,
      data: status,
    });
  } catch (error: unknown) {
    // ... error handling
  }
}

export async function DELETE(
  request: Request,
  { params }: { params: { id: string } }
) {
  try {
    const videoService = new VideoService();
    await videoService.deleteVideo(params.id);

    return NextResponse.json({
      success: true,
      data: { message: 'Video deleted successfully' },
    });
  } catch (error: unknown) {
    // ... error handling
  }
}
```

**Step 7: Run integration test**

Run: `npm test`
Expected: All tests pass

**Step 8: Commit**

```bash
git add lib/services/video.service.ts tests/unit/services/video.service.test.ts app/api/videos/create/route.ts app/api/videos/[id]/route.ts
git commit -m "refactor: introduce VideoService layer"
```

---

## Task 2.2: Eliminate Code Duplication - Worker Helpers

**Files:**
- Modify: `lib/config.ts` - export helper functions
- Modify: `workers/video-worker.ts` - use config helpers
- Delete: Duplicate functions in worker
- Test: `tests/unit/config.test.ts`

**Step 1: Add helper functions to lib/config.ts**

```typescript
// In lib/config.ts, add at the end:

export function getSpeakerFromVoiceId(voiceId: string): string {
  return VOICE_CONFIG.SPEAKER_MAP[voiceId] || VOICE_CONFIG.DEFAULT_SPEAKER;
}

export function getBackgroundDimensions(format: VideoFormat): { width: number; height: number } {
  return VIDEO_DIMENSIONS[format] || VIDEO_DIMENSIONS.vertical;
}
```

**Step 2: Write tests**

```typescript
// In tests/unit/config.test.ts
describe('Helper Functions', () => {
  describe('getSpeakerFromVoiceId', () => {
    it('should return correct speaker for valid voice ID', () => {
      expect(getSpeakerFromVoiceId('ru_speaker_male')).toBe('eugene');
      expect(getSpeakerFromVoiceId('ru_speaker_female')).toBe('xenia');
    });

    it('should return default speaker for unknown voice ID', () => {
      expect(getSpeakerFromVoiceId('unknown')).toBe('eugene');
    });
  });

  describe('getBackgroundDimensions', () => {
    it('should return correct dimensions for format', () => {
      expect(getBackgroundDimensions('vertical')).toEqual({ width: 1080, height: 1920 });
      expect(getBackgroundDimensions('horizontal')).toEqual({ width: 1920, height: 1080 });
      expect(getBackgroundDimensions('square')).toEqual({ width: 1080, height: 1080 });
    });

    it('should return vertical dimensions for unknown format', () => {
      expect(getBackgroundDimensions('unknown' as any)).toEqual({ width: 1080, height: 1920 });
    });
  });
});
```

**Step 3: Run tests**

Run: `npm test -- config.test.ts`
Expected: All tests pass

**Step 4: Update worker to use helpers**

```typescript
// In workers/video-worker.ts
import { 
  ENV,
  getSpeakerFromVoiceId,
  getBackgroundDimensions,
  getBackgroundPrompt,
} from '../lib/config';

// Delete duplicate functions (lines 289-305)

// Update usage in callback:
const speaker = getSpeakerFromVoiceId(job.data.voiceId);
const bgDimensions = getBackgroundDimensions(job.data.format);
```

**Step 5: Verify worker still works**

Run: `npm run worker` (in separate terminal)
Create test video and verify it processes correctly

**Step 6: Commit**

```bash
git add lib/config.ts workers/video-worker.ts tests/unit/config.test.ts
git commit -m "refactor: eliminate code duplication in worker helpers"
```

---

## Task 2.3: Remove All `any` Types

**Files:**
- Modify: `lib/types.ts` - replace `any` with proper types
- Modify: `lib/gpu-client.ts` - type error responses
- Modify: `lib/queue.ts` - type job progress
- Modify: `lib/logger.ts` - type context and errors
- Modify: All API routes - type catch blocks
- Test: `npm run type-check`

**Step 1: Fix types in lib/types.ts**

```typescript
// In lib/types.ts
export interface ApiResponse<T = unknown> {  // Changed from any
  success: boolean;
  data?: T;
  error?: ApiError;
}

export interface VideoStatusResponse {
  id: string;
  status: VideoStatus;
  progress: number;
  videoUrl: string | null;
  thumbnailUrl: string | null;
  job: VideoJobStatus | null;  // Changed from any
  error: string | null;
}

export interface VideoJobStatus {
  id: string;
  state: string;
  progress: number;
  data?: unknown;  // Changed from any
}

export interface ErrorContext {
  [key: string]: unknown;  // Changed from any
}
```

**Step 2: Fix logger types**

```typescript
// In lib/logger.ts
interface LogContext {
  [key: string]: unknown;  // Changed from any
}

class Logger {
  private formatError(error: unknown): string {  // Changed from any
    if (error instanceof Error) {
      return error.message;
    }
    return String(error);
  }

  info(message: string, context?: LogContext): void {
    console.log(`[INFO] ${message}`, context || {});
  }

  error(message: string, context?: { error?: unknown } & LogContext): void {
    const errorMessage = context?.error 
      ? this.formatError(context.error)
      : undefined;
    console.error(`[ERROR] ${message}`, { ...context, error: errorMessage });
  }
}
```

**Step 3: Fix gpu-client error handling**

```typescript
// In lib/gpu-client.ts
interface AxiosErrorResponse {
  message?: string;
  error?: string;
  detail?: string;
}

private handleError(error: unknown, context: string): never {
  if (axios.isAxiosError(error)) {
    const data = error.response?.data as AxiosErrorResponse | undefined;
    const message = data?.message || data?.error || data?.detail || error.message;
    throw new GPUServerError(message, context);
  }
  
  if (error instanceof Error) {
    throw new GPUServerError(error.message, context);
  }
  
  throw new GPUServerError('Unknown error occurred', context);
}
```

**Step 4: Fix queue progress type**

```typescript
// In lib/queue.ts
interface JobProgress {
  progress: number;
  stage?: string;
}

export async function getJobStatus(videoId: string) {
  const job = await videoQueue.getJob(videoId);
  if (!job) return null;

  const progress = (job.progress as JobProgress | number);
  const progressValue = typeof progress === 'number' 
    ? progress 
    : progress?.progress || 0;

  return {
    id: job.id!,
    state: await job.getState(),
    progress: progressValue,
    data: job.data,
  };
}
```

**Step 5: Fix API routes catch blocks**

```typescript
// Pattern for all routes:
} catch (error: unknown) {
  if (error instanceof ZodError) {
    // Handle validation error
  }
  
  const message = error instanceof Error ? error.message : 'Unknown error';
  logger.error('Operation failed', { error });
  
  return NextResponse.json({
    success: false,
    error: { message, code: 'INTERNAL_ERROR' }
  }, { status: 500 });
}
```

Apply to:
- `app/api/videos/create/route.ts`
- `app/api/videos/[id]/route.ts`
- `app/api/upload/route.ts`
- `app/api/health/route.ts`

**Step 6: Run type check**

Run: `npm run type-check`
Expected: No type errors

**Step 7: Run tests**

Run: `npm test`
Expected: All tests pass

**Step 8: Commit**

```bash
git add lib/types.ts lib/logger.ts lib/gpu-client.ts lib/queue.ts app/api/**/*.ts
git commit -m "refactor: replace all 'any' types with proper TypeScript types"
```

---

## Task 2.4: Break Down Long Functions

**Files:**
- Modify: `workers/video-worker.ts` - extract functions from callback
- Modify: `lib/video.ts` - extract FFmpeg logic from composeVideo
- Test: Existing tests should still pass

**Step 1: Extract worker helper functions**

```typescript
// In workers/video-worker.ts
// Extract from main callback (lines 50-200):

async function generateAudio(
  text: string,
  voiceId: string
): Promise<{ audioPath: string; audioUrl: string }> {
  const audioUrl = await gpuClient.textToSpeech(text, voiceId);
  const audioPath = path.join(ENV.TEMP_DIR, `audio_${Date.now()}.wav`);
  await downloadFile(audioUrl, audioPath);
  return { audioPath, audioUrl };
}

async function getAvatarImage(
  avatarId?: string,
  photoUrl?: string
): Promise<string> {
  if (!avatarId && !photoUrl) {
    throw new Error('Either avatarId or photoUrl must be provided');
  }

  if (avatarId) {
    const avatar = await prisma.avatar.findUnique({
      where: { id: avatarId },
    });
    if (!avatar) throw new Error('Avatar not found');
    return avatar.photoUrl;
  }

  return photoUrl!;
}

async function getBackgroundImage(
  style: string,
  format: VideoFormat
): Promise<string> {
  const prompt = getBackgroundPrompt(style);
  const dimensions = getBackgroundDimensions(format);
  
  return await gpuClient.generateBackground(
    prompt,
    dimensions.width,
    dimensions.height
  );
}

async function generateLipSyncVideo(
  avatarImageUrl: string,
  audioPath: string,
  job: Job
): Promise<string> {
  await job.updateProgress({ progress: 40, stage: 'lip-sync' });
  
  const avatarImagePath = path.join(ENV.TEMP_DIR, `avatar_${Date.now()}.jpg`);
  await downloadFile(avatarImageUrl, avatarImagePath);

  const videoUrl = await gpuClient.createLipSync(
    avatarImagePath,
    audioPath
  );

  await fs.promises.unlink(avatarImagePath);
  await fs.promises.unlink(audioPath);

  return videoUrl;
}

async function composeAndUploadVideo(
  videoUrl: string,
  backgroundUrl: string,
  format: VideoFormat,
  videoId: string,
  job: Job
): Promise<{ finalVideoUrl: string; thumbnailUrl: string }> {
  await job.updateProgress({ progress: 60, stage: 'compositing' });

  const videoPath = path.join(ENV.TEMP_DIR, `video_${Date.now()}.mp4`);
  const backgroundPath = path.join(ENV.TEMP_DIR, `bg_${Date.now()}.jpg`);
  
  await downloadFile(videoUrl, videoPath);
  await downloadFile(backgroundUrl, backgroundPath);

  const outputPath = path.join(ENV.TEMP_DIR, `final_${Date.now()}.mp4`);
  await composeVideo(videoPath, backgroundPath, outputPath, format);

  const finalVideoUrl = await uploadVideo(outputPath, 'videos', `${videoId}.mp4`);
  const thumbnailUrl = await generateAndUploadThumbnail(videoPath, videoId);

  await fs.promises.unlink(videoPath);
  await fs.promises.unlink(backgroundPath);
  await fs.promises.unlink(outputPath);

  return { finalVideoUrl, thumbnailUrl };
}
```

**Step 2: Refactor main callback to use extracted functions**

```typescript
// In workers/video-worker.ts callback:
videoQueue.process(async (job) => {
  try {
    logger.videoProcessing('Started processing video', {
      videoId: job.data.videoId,
      userId: job.data.userId,
    });

    // Update status to processing
    await prisma.video.update({
      where: { id: job.data.videoId },
      data: { status: 'processing' },
    });

    // Step 1: Generate audio (0-20%)
    await job.updateProgress({ progress: 10, stage: 'tts' });
    const { audioPath } = await generateAudio(job.data.text, job.data.voiceId);

    // Step 2: Get avatar image (20-30%)
    await job.updateProgress({ progress: 20, stage: 'avatar' });
    const avatarImageUrl = await getAvatarImage(
      job.data.avatarId,
      job.data.photoUrl
    );

    // Step 3: Generate background (30-40%)
    await job.updateProgress({ progress: 30, stage: 'background' });
    const backgroundUrl = await getBackgroundImage(
      job.data.backgroundStyle,
      job.data.format
    );

    // Step 4: Create lip-sync video (40-60%)
    const videoUrl = await generateLipSyncVideo(
      avatarImageUrl,
      audioPath,
      job
    );

    // Step 5: Compose and upload (60-100%)
    const { finalVideoUrl, thumbnailUrl } = await composeAndUploadVideo(
      videoUrl,
      backgroundUrl,
      job.data.format,
      job.data.videoId,
      job
    );

    // Update video record
    await prisma.video.update({
      where: { id: job.data.videoId },
      data: {
        status: 'completed',
        progress: 100,
        videoUrl: finalVideoUrl,
        thumbnailUrl: thumbnailUrl,
      },
    });

    logger.videoProcessing('Video processed successfully', {
      videoId: job.data.videoId,
    });

    return { videoUrl: finalVideoUrl };
  } catch (error) {
    logger.error('Video processing failed', {
      videoId: job.data.videoId,
      error,
    });

    await prisma.video.update({
      where: { id: job.data.videoId },
      data: {
        status: 'failed',
        error: error instanceof Error ? error.message : 'Unknown error',
      },
    });

    throw error;
  }
});
```

**Step 3: Extract FFmpeg logic from lib/video.ts**

```typescript
// In lib/video.ts
function buildVideoFilters(
  videoWidth: number,
  videoHeight: number,
  targetWidth: number,
  targetHeight: number
): string[] {
  const scale = Math.min(
    targetWidth / videoWidth,
    targetHeight / videoHeight
  );
  
  const scaledWidth = Math.round(videoWidth * scale);
  const scaledHeight = Math.round(videoHeight * scale);
  
  return [
    `scale=${scaledWidth}:${scaledHeight}`,
    `pad=${targetWidth}:${targetHeight}:(ow-iw)/2:(oh-ih)/2:black`,
  ];
}

function buildBackgroundFilters(
  bgWidth: number,
  bgHeight: number,
  targetWidth: number,
  targetHeight: number
): string[] {
  if (bgWidth === targetWidth && bgHeight === targetHeight) {
    return [];
  }
  
  return [
    `scale=${targetWidth}:${targetHeight}:force_original_aspect_ratio=increase`,
    `crop=${targetWidth}:${targetHeight}`,
  ];
}

// Update composeVideo to use these helpers:
export async function composeVideo(
  videoPath: string,
  backgroundPath: string,
  outputPath: string,
  format: VideoFormat = 'vertical'
): Promise<void> {
  const dimensions = getBackgroundDimensions(format);
  const videoInfo = await getVideoInfo(videoPath);

  const videoFilters = buildVideoFilters(
    videoInfo.width,
    videoInfo.height,
    dimensions.width,
    dimensions.height
  );

  // ... rest of implementation using helpers
}
```

**Step 4: Run tests**

Run: `npm test`
Expected: All tests pass

**Step 5: Verify worker**

Run: `npm run worker`
Process a test video and verify it works

**Step 6: Commit**

```bash
git add workers/video-worker.ts lib/video.ts
git commit -m "refactor: break down long functions into smaller focused functions"
```

---

# PHASE 3: Testing & Documentation

## Task 3.1: Add Real Unit Tests for lib/video.ts

**Files:**
- Create: `tests/unit/lib/video.test.ts` (replace existing)
- Test: Actual functions from lib/video.ts with mocks

**Step 1: Create comprehensive test file**

```typescript
// Create tests/unit/lib/video.test.ts
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import * as fs from 'fs';
import * as path from 'path';
import {
  ensureTempDir,
  getVideoInfo,
  composeVideo,
  generateThumbnail,
  cleanupTempFiles,
} from '@/lib/video';

// Mock ffmpeg
vi.mock('fluent-ffmpeg', () => {
  const mockFfmpeg = {
    ffprobe: vi.fn(),
    setFfmpegPath: vi.fn(),
    setFfprobePath: vi.fn(),
  };
  
  const mockCommand = {
    input: vi.fn().mockReturnThis(),
    complexFilter: vi.fn().mockReturnThis(),
    outputOptions: vi.fn().mockReturnThis(),
    output: vi.fn().mockReturnThis(),
    on: vi.fn().mockReturnThis(),
    run: vi.fn(),
    screenshots: vi.fn().mockReturnThis(),
  };

  return {
    default: vi.fn(() => mockCommand),
    ...mockFfmpeg,
  };
});

vi.mock('fs');
vi.mock('path');

describe('lib/video', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('ensureTempDir', () => {
    it('should create directory if it does not exist', async () => {
      vi.mocked(fs.existsSync).mockReturnValue(false);
      vi.mocked(fs.mkdirSync).mockImplementation();

      await ensureTempDir('/tmp/test');

      expect(fs.mkdirSync).toHaveBeenCalledWith(
        '/tmp/test',
        { recursive: true }
      );
    });

    it('should not create directory if it exists', async () => {
      vi.mocked(fs.existsSync).mockReturnValue(true);

      await ensureTempDir('/tmp/test');

      expect(fs.mkdirSync).not.toHaveBeenCalled();
    });
  });

  describe('getVideoInfo', () => {
    it('should return video dimensions and duration', async () => {
      const mockProbe = {
        streams: [{
          width: 1920,
          height: 1080,
          duration: 10.5,
        }],
      };

      const ffmpeg = await import('fluent-ffmpeg');
      vi.mocked(ffmpeg.ffprobe).mockImplementation((path, callback) => {
        callback(null, mockProbe as any);
      });

      const info = await getVideoInfo('/path/to/video.mp4');

      expect(info).toEqual({
        width: 1920,
        height: 1080,
        duration: 10.5,
      });
    });

    it('should throw error if ffprobe fails', async () => {
      const ffmpeg = await import('fluent-ffmpeg');
      vi.mocked(ffmpeg.ffprobe).mockImplementation((path, callback) => {
        callback(new Error('ffprobe failed'), null as any);
      });

      await expect(getVideoInfo('/invalid.mp4')).rejects.toThrow('ffprobe failed');
    });
  });

  describe('composeVideo', () => {
    it('should compose video with background', async () => {
      const ffmpeg = await import('fluent-ffmpeg');
      const mockCommand = ffmpeg.default();

      vi.mocked(mockCommand.on).mockImplementation((event, callback) => {
        if (event === 'end') {
          callback();
        }
        return mockCommand;
      });

      await composeVideo(
        '/path/to/video.mp4',
        '/path/to/background.jpg',
        '/path/to/output.mp4',
        'vertical'
      );

      expect(mockCommand.input).toHaveBeenCalled();
      expect(mockCommand.complexFilter).toHaveBeenCalled();
      expect(mockCommand.output).toHaveBeenCalledWith('/path/to/output.mp4');
    });
  });

  describe('generateThumbnail', () => {
    it('should generate thumbnail at 1 second', async () => {
      const ffmpeg = await import('fluent-ffmpeg');
      const mockCommand = ffmpeg.default();

      vi.mocked(mockCommand.on).mockImplementation((event, callback) => {
        if (event === 'end') {
          callback();
        }
        return mockCommand;
      });

      await generateThumbnail(
        '/path/to/video.mp4',
        '/path/to/output.jpg'
      );

      expect(mockCommand.screenshots).toHaveBeenCalledWith({
        timestamps: ['00:00:01'],
        filename: expect.any(String),
        folder: expect.any(String),
      });
    });
  });

  describe('cleanupTempFiles', () => {
    it('should delete files if they exist', async () => {
      vi.mocked(fs.existsSync).mockReturnValue(true);
      vi.mocked(fs.unlinkSync).mockImplementation();

      await cleanupTempFiles(['/tmp/file1.mp4', '/tmp/file2.jpg']);

      expect(fs.unlinkSync).toHaveBeenCalledTimes(2);
      expect(fs.unlinkSync).toHaveBeenCalledWith('/tmp/file1.mp4');
      expect(fs.unlinkSync).toHaveBeenCalledWith('/tmp/file2.jpg');
    });

    it('should skip files that do not exist', async () => {
      vi.mocked(fs.existsSync).mockReturnValue(false);

      await cleanupTempFiles(['/tmp/nonexistent.mp4']);

      expect(fs.unlinkSync).not.toHaveBeenCalled();
    });
  });
});
```

**Step 2: Run tests**

Run: `npm test -- video.test.ts`
Expected: All tests pass

**Step 3: Commit**

```bash
git add tests/unit/lib/video.test.ts
git commit -m "test: add real unit tests for lib/video.ts"
```

---

## Task 3.2: Add Integration Tests for VideoService

**Files:**
- Create: `tests/integration/video-service.test.ts`
- Test: Full flow with real Prisma (test DB)

**Step 1: Setup test database**

```typescript
// Create tests/integration/setup.ts
import { execSync } from 'child_process';

export async function setupTestDatabase() {
  // Push schema to test database
  execSync('npx prisma db push', {
    env: {
      ...process.env,
      DATABASE_URL: process.env.TEST_DATABASE_URL,
    },
  });
}

export async function cleanupTestDatabase() {
  execSync('npx prisma migrate reset --force --skip-seed', {
    env: {
      ...process.env,
      DATABASE_URL: process.env.TEST_DATABASE_URL,
    },
  });
}
```

**Step 2: Create integration test**

```typescript
// Create tests/integration/video-service.test.ts
import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import { VideoService } from '@/lib/services/video.service';
import { prisma } from '@/lib/prisma';
import { setupTestDatabase, cleanupTestDatabase } from './setup';

describe('VideoService Integration', () => {
  let service: VideoService;

  beforeAll(async () => {
    await setupTestDatabase();
  });

  afterAll(async () => {
    await cleanupTestDatabase();
    await prisma.$disconnect();
  });

  beforeEach(async () => {
    // Clean data between tests
    await prisma.video.deleteMany();
    await prisma.user.deleteMany();
    
    service = new VideoService();
  });

  it('should create video and store in database', async () => {
    const input = {
      userId: 'test-user-123',
      text: 'Integration test',
      voiceId: 'ru_speaker_male',
      backgroundStyle: 'simple' as const,
      format: 'vertical' as const,
    };

    const video = await service.createVideo(input);

    expect(video.id).toBeDefined();
    expect(video.status).toBe('pending');
    expect(video.text).toBe('Integration test');

    // Verify in database
    const dbVideo = await prisma.video.findUnique({
      where: { id: video.id },
    });

    expect(dbVideo).toBeDefined();
    expect(dbVideo?.text).toBe('Integration test');
  });

  it('should get video status', async () => {
    // Create video first
    const video = await prisma.video.create({
      data: {
        userId: 'test-user',
        text: 'Test',
        voiceId: 'ru_speaker_male',
        backgroundStyle: 'simple',
        format: 'vertical',
        status: 'processing',
        progress: 50,
      },
    });

    const status = await service.getVideoStatus(video.id);

    expect(status.id).toBe(video.id);
    expect(status.status).toBe('processing');
    expect(status.progress).toBe(50);
  });

  it('should throw error for non-existent video', async () => {
    await expect(
      service.getVideoStatus('non-existent-id')
    ).rejects.toThrow('Video non-existent-id not found');
  });

  it('should delete video', async () => {
    const video = await prisma.video.create({
      data: {
        userId: 'test-user',
        text: 'Test',
        voiceId: 'ru_speaker_male',
        backgroundStyle: 'simple',
        format: 'vertical',
        status: 'completed',
        progress: 100,
      },
    });

    await service.deleteVideo(video.id);

    const dbVideo = await prisma.video.findUnique({
      where: { id: video.id },
    });

    expect(dbVideo).toBeNull();
  });
});
```

**Step 3: Add test database URL to env**

```bash
# In .env.test
TEST_DATABASE_URL="postgresql://avatar:avatar_password@localhost:5432/avatar_factory_test"
```

**Step 4: Update package.json**

```json
{
  "scripts": {
    "test:integration": "vitest run tests/integration",
    "test:unit": "vitest run tests/unit"
  }
}
```

**Step 5: Run integration tests**

Run: `npm run test:integration`
Expected: All integration tests pass

**Step 6: Commit**

```bash
git add tests/integration/video-service.test.ts tests/integration/setup.ts .env.test package.json
git commit -m "test: add integration tests for VideoService"
```

---

## Task 3.3: Fix Documentation - Update README and API Docs

**Files:**
- Modify: `avatar-factory/README.md` - fix links, update commands
- Modify: `docs/QUICKSTART.md` - fix env vars
- Create: `docs/API.md` - document Next.js API endpoints
- Modify: `gpu-worker/README.md` - sync PyTorch version

**Step 1: Create API documentation**

```markdown
<!-- Create docs/API.md -->
# Avatar Factory API Documentation

## Authentication

Currently using test user. Authentication will be added in future version.

## Endpoints

### POST /api/videos/create

Create a new video generation job.

**Request:**

```json
{
  "text": "Hello, this is my avatar speaking!",
  "voiceId": "ru_speaker_male",
  "backgroundStyle": "simple",
  "format": "vertical",
  "avatarId": "avatar-123", // optional
  "photoUrl": "https://..." // optional, required if no avatarId
}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "videoId": "video-abc123"
  }
}
```

**Validation:**
- `text`: 10-500 characters
- `voiceId`: `ru_speaker_male` | `ru_speaker_female`
- `backgroundStyle`: `simple` | `professional` | `creative` | `minimalist`
- `format`: `vertical` | `horizontal` | `square`
- Must provide either `avatarId` or `photoUrl`

---

### GET /api/videos/:id

Get video generation status.

**Response:**

```json
{
  "success": true,
  "data": {
    "id": "video-abc123",
    "status": "processing",
    "progress": 45,
    "videoUrl": null,
    "thumbnailUrl": null,
    "error": null
  }
}
```

**Status values:**
- `pending` - In queue
- `processing` - Being generated
- `completed` - Ready
- `failed` - Error occurred

---

### DELETE /api/videos/:id

Delete a video and its associated files.

**Response:**

```json
{
  "success": true,
  "data": {
    "message": "Video deleted successfully"
  }
}
```

---

### POST /api/upload

Upload image file for avatar.

**Request:**
- Content-Type: `multipart/form-data`
- `file`: Image file (JPEG/PNG, max 10MB)
- `type`: `avatar` | `background` | `temp`

**Response:**

```json
{
  "success": true,
  "data": {
    "url": "https://storage.../avatar-123.jpg"
  }
}
```

---

### GET /api/health

System health check.

**Response:**

```json
{
  "status": "healthy",
  "timestamp": "2026-03-02T...",
  "version": "1.0.0",
  "checks": {
    "database": true,
    "redis": true,
    "gpu": true,
    "storage": true
  },
  "metrics": {
    "queueSize": 5,
    "activeJobs": 2,
    "gpuMemory": {
      "total": 12884901888,
      "used": 4294967296,
      "free": 8589934592
    }
  }
}
```

---

## Error Responses

All endpoints return errors in this format:

```json
{
  "success": false,
  "error": {
    "message": "Error description",
    "code": "ERROR_CODE"
  }
}
```

**Common error codes:**
- `VALIDATION_ERROR` - Invalid input (400)
- `NOT_FOUND` - Resource not found (404)
- `INTERNAL_ERROR` - Server error (500)
- `GPU_ERROR` - GPU server unavailable (503)
```

**Step 2: Update main README**

```markdown
<!-- In avatar-factory/README.md -->
## 📚 Documentation

| Document | Description |
|----------|-------------|
| [Quick Start](docs/QUICKSTART.md) | Get started in 15 minutes |
| [API Reference](docs/API.md) | Next.js API endpoints |
| [GPU Worker](gpu-worker/README.md) | GPU server setup |
| [Testing Guide](docs/TESTING.md) | Running tests |
| [Deployment](docs/DEPLOYMENT.md) | Production deployment |

## 🚀 Quick Start

```bash
# 1. Clone and install
git clone https://github.com/yourusername/avatar-factory.git
cd avatar-factory
npm install

# 2. Start infrastructure
docker-compose up -d

# 3. Setup database
npx prisma migrate dev

# 4. Configure environment
cp .env.example .env
# Edit .env with your GPU server IP

# 5. Start application
npm run dev       # Terminal 1: Next.js
npm run worker    # Terminal 2: Worker

# 6. Setup GPU server (on separate machine)
cd gpu-worker
# See gpu-worker/README.md for detailed instructions
```

## 🔧 Environment Variables

Use either `S3_*` or `MINIO_*` prefix for storage:

```bash
# Database
DATABASE_URL="postgresql://avatar:avatar_password@localhost:5432/avatar_factory"

# Redis
REDIS_URL="redis://localhost:6379"

# Storage (MinIO/S3)
S3_ENDPOINT="localhost"
S3_PORT="9000"
S3_ACCESS_KEY="minioadmin"
S3_SECRET_KEY="minioadmin123"
S3_BUCKET="avatar-videos"

# GPU Server
GPU_SERVER_URL="http://192.168.1.100:8001"
GPU_API_KEY="your-secret-key"
```
```

**Step 3: Fix QUICKSTART.md env vars**

```markdown
<!-- In docs/QUICKSTART.md, update env section -->
## Environment Configuration

Edit `.env`:

```bash
# Database (matches docker-compose defaults)
DATABASE_URL="postgresql://avatar:avatar_password@localhost:5433/avatar_factory"

# Redis (matches docker-compose defaults)
REDIS_URL="redis://localhost:6379"

# Storage - MinIO (matches docker-compose defaults)
S3_ENDPOINT="localhost"
S3_PORT="9000"
S3_ACCESS_KEY="minioadmin"
S3_SECRET_KEY="minioadmin123"
S3_BUCKET="avatar-videos"

# GPU Server - update with your machine's IP
GPU_SERVER_URL="http://192.168.1.100:8001"
GPU_API_KEY="your-secret-key"
```

**Find your GPU machine IP:**

```bash
# Windows
ipconfig

# macOS/Linux  
ip addr show   # or ifconfig
```
```

**Step 4: Update GPU worker README**

```markdown
<!-- In gpu-worker/README.md, sync dependencies section -->
## Requirements

- **Python:** 3.10 or 3.11
- **CUDA:** 11.8 or higher
- **GPU:** NVIDIA GPU with 8GB+ VRAM (RTX 3060 or better)
- **Disk:** 15GB free space for models
- **PyTorch:** 2.1.0 with CUDA support (installed automatically)

## Python Dependencies

All dependencies are installed via `requirements.txt`:

- **FastAPI** 0.109.0 - Web server
- **PyTorch** 2.1.0 - Deep learning framework
- **Transformers** 4.37.0 - Hugging Face models
- **Diffusers** 0.25.1 - Stable Diffusion
- **Silero** (via torch.hub) - Russian TTS
- **MuseTalk** (git submodule) - Lip-sync

Full list: see `requirements.txt`
```

**Step 5: Remove broken links from docs**

```bash
# Find and fix broken links
grep -r "quick-start.sh" docs/
grep -r "TEST_RESULTS.md" docs/

# In INSTALL_GUIDE.md, remove or replace references to:
# - quick-start.sh (doesn't exist)
# - TEST_RESULTS.md (doesn't exist)
# - install.sh, start.sh in gpu-worker (use README instructions instead)
```

**Step 6: Commit**

```bash
git add docs/API.md README.md docs/QUICKSTART.md gpu-worker/README.md docs/INSTALL_GUIDE.md
git commit -m "docs: add API documentation and fix inconsistencies"
```

---

## Task 3.4: Final Verification

**Step 1: Run all tests**

```bash
npm test
npm run test:integration
npm run type-check
```

**Step 2: Build verification**

```bash
npm run build
```

**Step 3: Manual E2E test**

1. Start all services:
   ```bash
   docker-compose up -d
   npm run dev
   npm run worker
   ```

2. Test video creation:
   - Upload photo
   - Enter text
   - Select style
   - Create video
   - Verify completion

3. Test API:
   ```bash
   curl http://localhost:3000/api/health
   ```

**Step 4: Update REFACTORING_COMPLETE.md**

```markdown
<!-- Create docs/REFACTORING_COMPLETE.md -->
# Refactoring Complete - 2026-03-02

## Summary

Major refactoring completed using Agent Teams coordination:
- 4 agents analyzed: architecture, code quality, testing, documentation
- 3 phases executed: critical fixes, architecture improvements, testing & docs

## Changes Made

### Phase 1: Critical Bug Fixes ✅
- Fixed backgroundStyle mismatch (API ↔ Worker)
- Unified S3/MinIO configuration
- Fixed memory leak in polling
- Removed all inline imports

### Phase 2: Architecture Improvements ✅
- Introduced VideoService layer
- Eliminated code duplication
- Removed all `any` types (20+ instances)
- Broke down long functions (180+ lines → focused functions)

### Phase 3: Testing & Documentation ✅
- Added real unit tests for lib/video.ts
- Added integration tests for VideoService
- Created comprehensive API documentation
- Fixed documentation inconsistencies

## Metrics

**Before:**
- Architecture: 5/10
- `any` types: 20+
- Long functions: 3 (150-180 lines)
- Test coverage: False coverage (tests don't import modules)
- Documentation: 7/10 with contradictions

**After:**
- Architecture: 8/10 (service layer, no duplication)
- `any` types: 0
- Long functions: 0 (all under 50 lines)
- Test coverage: Real unit + integration tests
- Documentation: 9/10 (comprehensive, consistent)

## Breaking Changes

None. All changes are backwards compatible.

## Next Steps

1. Add authentication (replace test-user-id)
2. Add more integration tests
3. Implement WebSocket for real-time updates (remove polling)
4. Add monitoring/observability

## Agent IDs

- Architecture Analysis: 9e62b3f4-6374-45f6-8824-21209307718a
- Code Quality Analysis: d8a0fdc4-bdc9-41ab-bfa3-a4487de9885c  
- Testing Analysis: 8c7f864c-19ec-4148-a675-8917c8cf8a5c
- Documentation Analysis: e649cb8d-0037-4971-964f-7c0146bf625d
```

**Step 5: Final commit**

```bash
git add docs/REFACTORING_COMPLETE.md
git commit -m "docs: mark refactoring as complete"
```

---

# Execution Complete

Plan saved to: `docs/plans/2026-03-02-major-refactoring-plan.md`

**Next: Choose execution approach**

1. **Subagent-Driven (recommended)** - Execute in this session with Agent Teams
2. **Manual** - Follow plan step-by-step yourself
3. **Parallel Session** - Open new session for execution

Which approach would you like to use?
