/**
 * Unit Tests: lib/video.ts
 * Comprehensive tests for video processing functions with FFmpeg mocks
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import {
  ensureTempDir,
  getVideoInfo,
  composeVideo,
  generateThumbnail,
  cleanupTempFiles,
} from '@/lib/video';
import type { VideoFormat } from '@/lib/types';

// Create mock command that supports chaining
const createMockCommand = () => {
  const mockCommand = {
    input: vi.fn().mockReturnThis(),
    complexFilter: vi.fn().mockReturnThis(),
    outputOptions: vi.fn().mockReturnThis(),
    output: vi.fn().mockReturnThis(),
    on: vi.fn().mockReturnThis(),
    run: vi.fn(),
  };
  return mockCommand;
};

const mockCommandInstance = createMockCommand();

vi.mock('fluent-ffmpeg', () => {
  const ffprobe = vi.fn();
  const mockDefault = vi.fn(() => mockCommandInstance);
  (mockDefault as { ffprobe: typeof ffprobe }).ffprobe = ffprobe;
  return {
    default: mockDefault,
  };
});

vi.mock('fs', () => ({
  promises: {
    mkdir: vi.fn(),
    access: vi.fn(),
    readdir: vi.fn(),
    stat: vi.fn(),
    unlink: vi.fn(),
  },
}));

vi.mock('@/lib/logger', () => ({
  logger: {
    debug: vi.fn(),
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
  },
}));

vi.mock('nanoid', () => ({
  nanoid: vi.fn(() => 'test-id-123'),
}));

const fs = await import('fs');
const { promises: fsPromises } = fs;
const ffmpegModule = await import('fluent-ffmpeg');
const ffprobeMock = (ffmpegModule.default as { ffprobe: ReturnType<typeof vi.fn> })
  .ffprobe;

describe('lib/video', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(fsPromises.mkdir).mockResolvedValue(undefined);
    vi.mocked(fsPromises.access).mockResolvedValue(undefined);
    vi.mocked(mockCommandInstance.on).mockImplementation(function (
      this: typeof mockCommandInstance,
      event: string,
      callback: () => void
    ) {
      if (event === 'end') {
        setImmediate(() => callback());
      }
      return this;
    });
    mockCommandInstance.run.mockImplementation(function (
      this: typeof mockCommandInstance
    ) {
      const onHandler = vi.mocked(this.on).mock.calls.find(
        (c) => c[0] === 'end'
      )?.[1];
      if (onHandler) {
        setImmediate(onHandler as () => void);
      }
    });
  });

  describe('ensureTempDir', () => {
    it('should create directory with recursive option', async () => {
      await ensureTempDir();

      expect(fsPromises.mkdir).toHaveBeenCalledWith(
        expect.stringContaining('avatar-factory'),
        { recursive: true }
      );
    });

    it('should throw VideoProcessingError if mkdir fails', async () => {
      vi.mocked(fsPromises.mkdir).mockRejectedValue(new Error('Permission denied'));

      const err = await ensureTempDir().catch((e) => e) as Error;
      expect(err.name).toBe('VideoProcessingError');
      expect(err.message).toContain('Failed to create temp directory');
    });
  });

  describe('getVideoInfo', () => {
    it('should return video metadata with dimensions and duration', async () => {
      const mockMetadata = {
        streams: [
          {
            codec_type: 'video',
            width: 1920,
            height: 1080,
            r_frame_rate: '30/1',
            codec_name: 'h264',
          },
        ],
        format: {
          duration: 10.5,
          bit_rate: 1500000,
        },
      };

      vi.mocked(ffprobeMock).mockImplementation(
        (_path: string, callback: (err: Error | null, data: unknown) => void) => {
          callback(null, mockMetadata);
        }
      );

      const info = await getVideoInfo('/path/to/video.mp4');

      expect(info).toEqual({
        duration: 10.5,
        width: 1920,
        height: 1080,
        fps: 30,
        codec: 'h264',
        bitrate: 1500000,
      });
    });

    it('should use default FPS when r_frame_rate is invalid', async () => {
      const mockMetadata = {
        streams: [
          {
            codec_type: 'video',
            width: 1080,
            height: 1920,
            r_frame_rate: 'invalid',
            codec_name: 'h264',
          },
        ],
        format: { duration: 5, bit_rate: 1000000 },
      };

      vi.mocked(ffprobeMock).mockImplementation(
        (_path: string, callback: (err: Error | null, data: unknown) => void) => {
          callback(null, mockMetadata);
        }
      );

      const info = await getVideoInfo('/path/to/video.mp4');

      expect(info.fps).toBe(25); // VIDEO_CONFIG.DEFAULT_FPS
    });

    it('should throw ValidationError for empty path', async () => {
      const err1 = await getVideoInfo('').catch((e) => e) as Error;
      expect(err1.name).toBe('ValidationError');
      expect(err1.message).toContain('Video path cannot be empty');

      const err2 = await getVideoInfo('   ').catch((e) => e) as Error;
      expect(err2.name).toBe('ValidationError');
    });

    it('should throw ValidationError when file does not exist', async () => {
      vi.mocked(fsPromises.access).mockRejectedValue(new Error('ENOENT'));

      const err = await getVideoInfo('/nonexistent/video.mp4').catch((e) => e) as Error;
      expect(err.name).toBe('ValidationError');
      expect(err.message).toContain('Video file not found');
    });

    it('should throw VideoProcessingError if ffprobe fails', async () => {
      vi.mocked(ffprobeMock).mockImplementation(
        (_path: string, callback: (err: Error | null, data: unknown) => void) => {
          callback(new Error('ffprobe failed'), null);
        }
      );

      const err = await getVideoInfo('/path/to/video.mp4').catch((e) => e) as Error;
      expect(err.name).toBe('VideoProcessingError');
      expect(err.message).toContain('Failed to probe video');
    });

    it('should throw VideoProcessingError when no video stream found', async () => {
      const mockMetadata = {
        streams: [{ codec_type: 'audio' }],
        format: { duration: 5 },
      };

      vi.mocked(ffprobeMock).mockImplementation(
        (_path: string, callback: (err: Error | null, data: unknown) => void) => {
          callback(null, mockMetadata);
        }
      );

      const err = await getVideoInfo('/path/to/audio-only.mp3').catch((e) => e) as Error;
      expect(err.name).toBe('VideoProcessingError');
      expect(err.message).toContain('No video stream found');
    });
  });

  describe('composeVideo', () => {
    const baseOptions = {
      avatarVideoPath: '/path/to/avatar.mp4',
      backgroundImagePath: '/path/to/background.jpg',
      format: 'VERTICAL' as VideoFormat,
    };

    it('should compose video and return output path', async () => {
      vi.mocked(mockCommandInstance.on).mockImplementation(function (
        this: typeof mockCommandInstance,
        event: string,
        callback: () => void
      ) {
        if (event === 'end') {
          setImmediate(() => callback());
        }
        return this;
      });
      mockCommandInstance.run.mockImplementation(function (
        this: typeof mockCommandInstance
      ) {
        const onHandler = vi.mocked(this.on).mock.calls.find(
          (c) => c[0] === 'end'
        )?.[1];
        if (onHandler) {
          setImmediate(onHandler as () => void);
        }
      });

      const result = await composeVideo(baseOptions);

      expect(result).toBeDefined();
      expect(result).toContain('.mp4');
      expect(mockCommandInstance.input).toHaveBeenCalledWith(
        '/path/to/background.jpg'
      );
      expect(mockCommandInstance.input).toHaveBeenCalledWith(
        '/path/to/avatar.mp4'
      );
      expect(mockCommandInstance.complexFilter).toHaveBeenCalled();
      expect(mockCommandInstance.outputOptions).toHaveBeenCalled();
      expect(mockCommandInstance.output).toHaveBeenCalled();
      expect(mockCommandInstance.run).toHaveBeenCalled();
    });

    it('should use provided outputPath when given', async () => {
      const customOutput = '/custom/output.mp4';
      await composeVideo({ ...baseOptions, outputPath: customOutput });

      expect(mockCommandInstance.output).toHaveBeenCalledWith(customOutput);
    });

    it('should include music input when musicPath provided', async () => {
      await composeVideo({
        ...baseOptions,
        musicPath: '/path/to/music.mp3',
      });

      expect(mockCommandInstance.input).toHaveBeenCalledWith('/path/to/music.mp3');
      expect(mockCommandInstance.input).toHaveBeenCalledTimes(3);
    });

    it('should throw ValidationError when avatar or background missing', async () => {
      const err1 = await composeVideo({
        ...baseOptions,
        avatarVideoPath: '',
        backgroundImagePath: '/path/to/bg.jpg',
      }).catch((e) => e) as Error;
      expect(err1.name).toBe('ValidationError');

      const err2 = await composeVideo({
        ...baseOptions,
        avatarVideoPath: '/path/to/avatar.mp4',
        backgroundImagePath: '',
      }).catch((e) => e) as Error;
      expect(err2.name).toBe('ValidationError');
    });

    it('should throw ValidationError for invalid format', async () => {
      const err = await composeVideo({
        ...baseOptions,
        format: 'INVALID' as VideoFormat,
      }).catch((e) => e) as Error;
      expect(err.name).toBe('ValidationError');
      expect(err.message).toContain('Invalid video format');
    });

    it('should throw ValidationError when input file not found', async () => {
      vi.mocked(fsPromises.access)
        .mockResolvedValueOnce(undefined)
        .mockRejectedValueOnce(new Error('ENOENT'));

      const err = await composeVideo(baseOptions).catch((e) => e) as Error;
      expect(err.name).toBe('ValidationError');
      expect(err.message).toContain('Input file not found');
    });

    it('should reject with VideoProcessingError on FFmpeg error', async () => {
      vi.mocked(mockCommandInstance.on).mockImplementation(function (
        this: typeof mockCommandInstance,
        event: string,
        callback: (err: Error) => void
      ) {
        if (event === 'error') {
          setImmediate(() => callback(new Error('FFmpeg failed')));
        }
        return this;
      });
      mockCommandInstance.run.mockImplementation(function (
        this: typeof mockCommandInstance
      ) {
        const onHandler = vi.mocked(this.on).mock.calls.find(
          (c) => c[0] === 'error'
        )?.[1];
        if (onHandler) {
          setImmediate(() =>
            (onHandler as (err: Error) => void)(new Error('FFmpeg failed'))
          );
        }
      });

      const err = await composeVideo(baseOptions).catch((e) => e) as Error;
      expect(err.name).toBe('VideoProcessingError');
      expect(err.message).toContain('Video composition failed');
    });
  });

  describe('generateThumbnail', () => {
    it('should generate thumbnail and return path', async () => {
      const result = await generateThumbnail(
        '/path/to/video.mp4',
        '/path/to/output.png'
      );

      expect(result).toBe('/path/to/output.png');
      expect(mockCommandInstance.outputOptions).toHaveBeenCalledWith(
        expect.arrayContaining([
          '-vframes',
          '1',
          '-update',
          '1',
          '-ss',
          '00:00:00.1',
        ])
      );
      expect(mockCommandInstance.output).toHaveBeenCalledWith(
        '/path/to/output.png'
      );
      expect(mockCommandInstance.run).toHaveBeenCalled();
    });

    it('should use custom time position when provided', async () => {
      await generateThumbnail(
        '/path/to/video.mp4',
        '/path/to/out.jpg',
        '00:00:05'
      );

      expect(mockCommandInstance.outputOptions).toHaveBeenCalledWith(
        expect.arrayContaining(['-ss', '00:00:05'])
      );
    });

    it('should throw ValidationError for empty path', async () => {
      const err = await generateThumbnail('', '/path/to/output.png').catch(
        (e) => e
      ) as Error;
      expect(err.name).toBe('ValidationError');
      expect(err.message).toContain('Video path cannot be empty');
    });

    it('should throw ValidationError when file not found', async () => {
      vi.mocked(fsPromises.access).mockRejectedValue(new Error('ENOENT'));

      const err = await generateThumbnail('/nonexistent.mp4', '/out.png').catch(
        (e) => e
      ) as Error;
      expect(err.name).toBe('ValidationError');
      expect(err.message).toContain('Video file not found');
    });

    it('should reject with VideoProcessingError on FFmpeg error', async () => {
      vi.mocked(mockCommandInstance.on).mockImplementation(function (
        this: typeof mockCommandInstance,
        event: string,
        callback: (err: Error) => void
      ) {
        if (event === 'error') {
          setImmediate(() =>
            callback(new Error('Thumbnail generation failed'))
          );
        }
        return this;
      });
      mockCommandInstance.run.mockImplementation(function (
        this: typeof mockCommandInstance
      ) {
        const onHandler = vi.mocked(this.on).mock.calls.find(
          (c) => c[0] === 'error'
        )?.[1];
        if (onHandler) {
          setImmediate(() =>
            (onHandler as (err: Error) => void)(
              new Error('Thumbnail generation failed')
            )
          );
        }
      });

      const err = await generateThumbnail('/path/to/video.mp4', '/out.png').catch(
        (e) => e
      ) as Error;
      expect(err.name).toBe('VideoProcessingError');
      expect(err.message).toContain('Failed to generate thumbnail');
    });
  });

  describe('cleanupTempFiles', () => {
    it('should delete files older than maxAgeHours', async () => {
      const oldFile = 'old_video.mp4';
      const newFile = 'new_video.mp4';
      vi.mocked(fsPromises.readdir).mockResolvedValue([oldFile, newFile]);
      vi.mocked(fsPromises.stat)
        .mockResolvedValueOnce({
          mtimeMs: Date.now() - 25 * 60 * 60 * 1000,
        } as unknown as import('fs').Stats)
        .mockResolvedValueOnce({
          mtimeMs: Date.now() - 1 * 60 * 60 * 1000,
        } as unknown as import('fs').Stats);
      const consoleSpy = vi.spyOn(console, 'log').mockImplementation(() => {});

      await cleanupTempFiles(24);

      expect(fsPromises.unlink).toHaveBeenCalledTimes(1);
      expect(fsPromises.unlink).toHaveBeenCalledWith(
        expect.stringContaining(oldFile)
      );

      consoleSpy.mockRestore();
    });

    it('should not delete files newer than maxAgeHours', async () => {
      vi.mocked(fsPromises.readdir).mockResolvedValue(['recent.mp4']);
      vi.mocked(fsPromises.stat).mockResolvedValue({
        mtimeMs: Date.now() - 1 * 60 * 60 * 1000, // 1 hour ago
      } as unknown as import('fs').Stats);

      await cleanupTempFiles(24);

      expect(fsPromises.unlink).not.toHaveBeenCalled();
    });

    it('should use default 24 hours when maxAgeHours not provided', async () => {
      vi.mocked(fsPromises.readdir).mockResolvedValue([]);

      await cleanupTempFiles();

      expect(fsPromises.readdir).toHaveBeenCalled();
      expect(fsPromises.unlink).not.toHaveBeenCalled();
    });

    it('should handle readdir errors gracefully', async () => {
      vi.mocked(fsPromises.readdir).mockRejectedValue(
        new Error('Permission denied')
      );
      const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});

      await expect(cleanupTempFiles(24)).resolves.not.toThrow();

      consoleSpy.mockRestore();
    });
  });
});
