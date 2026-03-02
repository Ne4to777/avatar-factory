import { describe, it, expect, vi, beforeEach } from 'vitest';
import { VideoService } from '@/lib/services/video.service';
import { prisma } from '@/lib/prisma';
import { addVideoJob, getJobStatus } from '@/lib/queue';
import { deleteByUrl } from '@/lib/storage';

vi.mock('@/lib/prisma', () => ({
  prisma: {
    video: {
      create: vi.fn(),
      findUnique: vi.fn(),
      delete: vi.fn(),
    },
  },
}));

vi.mock('@/lib/queue', () => ({
  addVideoJob: vi.fn(),
  getJobStatus: vi.fn(),
}));

vi.mock('@/lib/storage', () => ({
  deleteByUrl: vi.fn(),
}));

vi.mock('@/lib/logger', () => ({
  logger: {
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
    debug: vi.fn(),
  },
}));

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
        format: 'VERTICAL' as const,
      };

      const mockVideo = {
        id: 'video-456',
        userId: input.userId,
        text: input.text,
        voiceId: input.voiceId,
        backgroundStyle: input.backgroundStyle,
        avatarId: input.avatarId,
        photoUrl: null,
        backgroundUrl: null,
        status: 'PENDING',
        progress: 0,
        format: input.format,
        videoUrl: null,
        thumbnailUrl: null,
        errorMessage: null,
        duration: null,
        audioPath: null,
        processedAt: null,
        viewCount: 0,
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      vi.mocked(prisma.video.create).mockResolvedValue(mockVideo as any);
      vi.mocked(addVideoJob).mockResolvedValue({} as any);

      const result = await service.createVideo(input);

      expect(result.id).toBeDefined();
      expect(result.status).toBe('PENDING');
      expect(prisma.video.create).toHaveBeenCalledWith({
        data: {
          userId: input.userId,
          text: input.text,
          voiceId: input.voiceId,
          backgroundStyle: input.backgroundStyle,
          avatarId: input.avatarId,
          photoUrl: undefined,
          backgroundUrl: undefined,
          format: input.format,
          status: 'PENDING',
          progress: 0,
        },
      });
      expect(addVideoJob).toHaveBeenCalledWith(
        expect.objectContaining({
          videoId: mockVideo.id,
          userId: input.userId,
          text: input.text,
          voiceId: input.voiceId,
          backgroundStyle: input.backgroundStyle,
          avatarId: input.avatarId,
          format: input.format,
        })
      );
    });
  });

  describe('getVideoStatus', () => {
    it('should return video status with job progress', async () => {
      const videoId = 'video-123';
      const mockVideo = {
        id: videoId,
        status: 'PROCESSING',
        progress: 50,
        videoUrl: null,
        thumbnailUrl: null,
        errorMessage: null,
      };

      vi.mocked(prisma.video.findUnique).mockResolvedValue(mockVideo as any);
      vi.mocked(getJobStatus).mockResolvedValue({
        id: videoId,
        state: 'active',
        progress: 75,
        data: {},
        returnvalue: null,
        failedReason: null,
        timestamp: 0,
        processedOn: 0,
        finishedOn: null,
      });

      const status = await service.getVideoStatus(videoId);

      expect(status.id).toBe(videoId);
      expect(status.status).toBeDefined();
      expect(status.progress).toBe(75);
    });

    it('should throw when video not found', async () => {
      vi.mocked(prisma.video.findUnique).mockResolvedValue(null);

      await expect(service.getVideoStatus('non-existent')).rejects.toThrow(
        'Video non-existent not found'
      );
    });
  });

  describe('deleteVideo', () => {
    it('should delete video and associated files', async () => {
      const videoId = 'video-123';
      const mockVideo = {
        id: videoId,
        videoUrl: 'http://storage.com/video.mp4',
        thumbnailUrl: 'http://storage.com/thumb.jpg',
      };

      vi.mocked(prisma.video.findUnique).mockResolvedValue(mockVideo as any);
      vi.mocked(deleteByUrl).mockResolvedValue(undefined);
      vi.mocked(prisma.video.delete).mockResolvedValue(mockVideo as any);

      await service.deleteVideo(videoId);

      expect(deleteByUrl).toHaveBeenCalledWith('http://storage.com/video.mp4');
      expect(deleteByUrl).toHaveBeenCalledWith('http://storage.com/thumb.jpg');
      expect(prisma.video.delete).toHaveBeenCalledWith({
        where: { id: videoId },
      });
    });

    it('should throw when video not found', async () => {
      vi.mocked(prisma.video.findUnique).mockResolvedValue(null);

      await expect(service.deleteVideo('non-existent')).rejects.toThrow(
        'Video non-existent not found'
      );
    });
  });
});
