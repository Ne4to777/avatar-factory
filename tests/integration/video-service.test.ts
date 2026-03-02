import { describe, it, expect, beforeAll, afterAll, beforeEach, vi } from 'vitest';
import { VideoService } from '@/lib/services/video.service';
import { prisma } from '@/lib/prisma';
import { deleteByUrl } from '@/lib/storage';

// Mock queue and storage (not testing those integrations)
vi.mock('@/lib/queue', () => ({
  addVideoJob: vi.fn(),
  getJobStatus: vi.fn().mockResolvedValue(null),
}));

vi.mock('@/lib/storage', () => ({
  deleteByUrl: vi.fn(),
}));

let dbAvailable = false;

describe('VideoService Integration', () => {
  let service: VideoService;
  let testUserId: string;

  beforeAll(async () => {
    try {
      await prisma.$connect();
      dbAvailable = true;
      await prisma.video.deleteMany();
      await prisma.user.deleteMany();
    } catch {
      dbAvailable = false;
    }
  });

  afterAll(async () => {
    if (dbAvailable) await prisma.$disconnect();
  });

  beforeEach(async () => {
    if (!dbAvailable) return;
    // Clean data between tests (Video first due to FK to User)
    await prisma.video.deleteMany();
    await prisma.user.deleteMany();

    // Create test user (required for Video FK)
    const user = await prisma.user.create({
      data: {
        email: `test-${Date.now()}-${Math.random().toString(36).slice(2)}@test.com`,
        name: 'Test User',
      },
    });
    testUserId = user.id;

    vi.clearAllMocks();
    service = new VideoService();
  });

  it.skipIf(() => !dbAvailable)(
    'should create video and store in database',
    async () => {
    const input = {
      userId: testUserId,
      text: 'Integration test',
      voiceId: 'ru_speaker_male',
      backgroundStyle: 'simple' as const,
      format: 'VERTICAL' as const,
    };

    const video = await service.createVideo(input);

    expect(video.id).toBeDefined();
    expect(video.status).toBe('PENDING');
    expect(video.text).toBe('Integration test');

    // Verify in database
    const dbVideo = await prisma.video.findUnique({
      where: { id: video.id },
    });

    expect(dbVideo).toBeDefined();
    expect(dbVideo?.text).toBe('Integration test');
  }
  );

  it.skipIf(() => !dbAvailable)('should get video status', async () => {
    // Create video first (using test user)
    const video = await prisma.video.create({
      data: {
        userId: testUserId,
        text: 'Test',
        voiceId: 'ru_speaker_male',
        backgroundStyle: 'simple',
        format: 'VERTICAL',
        status: 'PROCESSING',
        progress: 50,
      },
    });

    const status = await service.getVideoStatus(video.id);

    expect(status.id).toBe(video.id);
    expect(status.status).toBe('PROCESSING');
    expect(status.progress).toBe(50);
  });

  it.skipIf(() => !dbAvailable)(
    'should throw error for non-existent video',
    async () => {
    await expect(service.getVideoStatus('non-existent-id')).rejects.toThrow(
      'Video non-existent-id not found'
    );
  }
  );

  it.skipIf(() => !dbAvailable)('should delete video from database', async () => {
    const video = await prisma.video.create({
      data: {
        userId: testUserId,
        text: 'Test',
        voiceId: 'ru_speaker_male',
        backgroundStyle: 'simple',
        format: 'VERTICAL',
        status: 'COMPLETED',
        progress: 100,
      },
    });

    await service.deleteVideo(video.id);

    const dbVideo = await prisma.video.findUnique({
      where: { id: video.id },
    });

    expect(dbVideo).toBeNull();
  });

  it.skipIf(() => !dbAvailable)(
    'should handle video with URLs during delete',
    async () => {
    const video = await prisma.video.create({
      data: {
        userId: testUserId,
        text: 'Test',
        voiceId: 'ru_speaker_male',
        backgroundStyle: 'simple',
        format: 'VERTICAL',
        status: 'COMPLETED',
        progress: 100,
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      },
    });

    await service.deleteVideo(video.id);

    // Should call storage deletion
    expect(deleteByUrl).toHaveBeenCalledWith('https://example.com/video.mp4');
    expect(deleteByUrl).toHaveBeenCalledWith('https://example.com/thumb.jpg');
  }
  );
});
