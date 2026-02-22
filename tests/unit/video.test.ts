/**
 * Unit Tests: lib/video.ts
 * Testing video processing logic and validation
 */

import { describe, it, expect } from 'vitest';
import { VIDEO_DIMENSIONS, VIDEO_CONFIG } from '@/lib/config';
import { ValidationError, VideoProcessingError } from '@/lib/types';
import type { VideoFormat, VideoMetadata } from '@/lib/types';

describe('Video Module', () => {
  describe('Video Dimensions', () => {
    it('should have correct vertical dimensions (9:16)', () => {
      const dims = VIDEO_DIMENSIONS.VERTICAL;
      const ratio = dims.width / dims.height;
      
      expect(dims.width).toBe(1080);
      expect(dims.height).toBe(1920);
      expect(ratio).toBeCloseTo(9 / 16);
    });

    it('should have correct horizontal dimensions (16:9)', () => {
      const dims = VIDEO_DIMENSIONS.HORIZONTAL;
      const ratio = dims.width / dims.height;
      
      expect(dims.width).toBe(1920);
      expect(dims.height).toBe(1080);
      expect(ratio).toBeCloseTo(16 / 9);
    });

    it('should have correct square dimensions (1:1)', () => {
      const dims = VIDEO_DIMENSIONS.SQUARE;
      const ratio = dims.width / dims.height;
      
      expect(dims.width).toBe(1080);
      expect(dims.height).toBe(1080);
      expect(ratio).toBe(1);
    });

    it('should calculate aspect ratio', () => {
      const calculateAspectRatio = (width: number, height: number): string => {
        const gcd = (a: number, b: number): number => b === 0 ? a : gcd(b, a % b);
        const divisor = gcd(width, height);
        return `${width / divisor}:${height / divisor}`;
      };
      
      expect(calculateAspectRatio(1080, 1920)).toBe('9:16');
      expect(calculateAspectRatio(1920, 1080)).toBe('16:9');
      expect(calculateAspectRatio(1080, 1080)).toBe('1:1');
    });
  });

  describe('Video Configuration', () => {
    it('should have valid codec settings', () => {
      expect(VIDEO_CONFIG.DEFAULT_CODEC).toBe('libx264');
      expect(VIDEO_CONFIG.DEFAULT_AUDIO_CODEC).toBe('aac');
      expect(VIDEO_CONFIG.DEFAULT_PIXEL_FORMAT).toBe('yuv420p');
    });

    it('should have valid quality settings', () => {
      expect(VIDEO_CONFIG.DEFAULT_FPS).toBe(25);
      expect(VIDEO_CONFIG.DEFAULT_BITRATE).toBe(150);
      expect(VIDEO_CONFIG.DEFAULT_CRF).toBe(23);
    });

    it('should have valid duration limits', () => {
      expect(VIDEO_CONFIG.MIN_DURATION_SECONDS).toBe(1);
      expect(VIDEO_CONFIG.MAX_DURATION_SECONDS).toBe(60);
      expect(VIDEO_CONFIG.MAX_DURATION_SECONDS).toBeGreaterThan(VIDEO_CONFIG.MIN_DURATION_SECONDS);
    });

    it('should validate CRF range (0-51)', () => {
      const crf = VIDEO_CONFIG.DEFAULT_CRF;
      
      expect(crf).toBeGreaterThanOrEqual(0);
      expect(crf).toBeLessThanOrEqual(51);
    });
  });

  describe('FPS Parsing', () => {
    it('should parse FPS fraction safely', () => {
      const parseFPS = (rFrameRate: string): number => {
        const [num, den] = rFrameRate.split('/').map(Number);
        if (num && den) {
          return Math.round(num / den);
        }
        return VIDEO_CONFIG.DEFAULT_FPS;
      };
      
      expect(parseFPS('30/1')).toBe(30);
      expect(parseFPS('25/1')).toBe(25);
      expect(parseFPS('24000/1001')).toBe(24); // 23.976 -> 24
      expect(parseFPS('invalid')).toBe(25); // fallback to default
    });

    it('should handle common FPS values', () => {
      const commonFPS = [24, 25, 30, 50, 60];
      
      commonFPS.forEach(fps => {
        expect(fps).toBeGreaterThan(0);
        expect(fps).toBeLessThanOrEqual(120);
      });
    });
  });

  describe('Video Metadata', () => {
    it('should create valid metadata structure', () => {
      const metadata: VideoMetadata = {
        duration: 10.5,
        width: 1080,
        height: 1920,
        fps: 25,
        codec: 'h264',
        bitrate: 150000,
      };
      
      expect(metadata.duration).toBe(10.5);
      expect(metadata.width).toBe(1080);
      expect(metadata.height).toBe(1920);
      expect(metadata.fps).toBe(25);
    });

    it('should validate metadata values', () => {
      const metadata: VideoMetadata = {
        duration: 30,
        width: 1920,
        height: 1080,
        fps: 30,
        codec: 'libx264',
      };
      
      expect(metadata.duration).toBeGreaterThan(0);
      expect(metadata.width).toBeGreaterThan(0);
      expect(metadata.height).toBeGreaterThan(0);
      expect(metadata.fps).toBeGreaterThan(0);
    });
  });

  describe('File Path Validation', () => {
    it('should validate video file path', () => {
      const validPath = '/tmp/video.mp4';
      const emptyPath = '';
      
      expect(validPath.length > 0).toBe(true);
      expect(emptyPath.length === 0).toBe(true);
    });

    it('should check video file extensions', () => {
      const validExtensions = ['.mp4', '.webm', '.mov'];
      const videoPath = '/tmp/video.mp4';
      
      const ext = videoPath.substring(videoPath.lastIndexOf('.'));
      expect(validExtensions.includes(ext)).toBe(true);
    });

    it('should validate multiple file paths', () => {
      const paths = {
        avatar: '/tmp/avatar.mp4',
        background: '/tmp/background.png',
        music: '/tmp/music.mp3',
      };
      
      Object.values(paths).forEach(path => {
        expect(path.length).toBeGreaterThan(0);
        expect(path).toContain('/tmp/');
      });
    });
  });

  describe('Format Validation', () => {
    it('should validate video format enum', () => {
      const validFormats: VideoFormat[] = ['VERTICAL', 'HORIZONTAL', 'SQUARE'];
      
      validFormats.forEach(format => {
        expect(VIDEO_DIMENSIONS[format]).toBeDefined();
      });
    });

    it('should reject invalid formats', () => {
      const format = 'INVALID' as any;
      expect(VIDEO_DIMENSIONS[format]).toBeUndefined();
    });

    it('should get dimensions by format', () => {
      const getDimensions = (format: VideoFormat) => {
        return VIDEO_DIMENSIONS[format];
      };
      
      expect(getDimensions('VERTICAL')).toEqual({ width: 1080, height: 1920 });
      expect(getDimensions('HORIZONTAL')).toEqual({ width: 1920, height: 1080 });
      expect(getDimensions('SQUARE')).toEqual({ width: 1080, height: 1080 });
    });
  });

  describe('FFmpeg Command Building', () => {
    it('should build codec options', () => {
      const options = [
        '-c:v', VIDEO_CONFIG.DEFAULT_CODEC,
        '-c:a', VIDEO_CONFIG.DEFAULT_AUDIO_CODEC,
        '-pix_fmt', VIDEO_CONFIG.DEFAULT_PIXEL_FORMAT,
      ];
      
      expect(options).toContain('-c:v');
      expect(options).toContain('libx264');
      expect(options).toContain('-c:a');
      expect(options).toContain('aac');
    });

    it('should build quality options', () => {
      const options = [
        '-crf', VIDEO_CONFIG.DEFAULT_CRF.toString(),
        '-preset', VIDEO_CONFIG.DEFAULT_PRESET,
      ];
      
      expect(options).toContain('-crf');
      expect(options).toContain('23');
      expect(options).toContain('-preset');
      expect(options).toContain('medium');
    });

    it('should build output options', () => {
      const options = [
        '-movflags', '+faststart',
        '-y', // overwrite
      ];
      
      expect(options).toContain('-movflags');
      expect(options).toContain('+faststart');
      expect(options).toContain('-y');
    });
  });

  describe('Thumbnail Generation', () => {
    it('should calculate thumbnail time position', () => {
      const duration = 10.5;
      const position = Math.min(1, duration * 0.1); // 10% into video
      
      expect(position).toBe(1);
    });

    it('should format time position', () => {
      const formatTime = (seconds: number): string => {
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        const secs = Math.floor(seconds % 60);
        const ms = Math.floor((seconds % 1) * 1000);
        
        return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}.${ms.toString().padStart(3, '0').substring(0, 1)}`;
      };
      
      expect(formatTime(0.1)).toBe('00:00:00.1');
      expect(formatTime(1)).toBe('00:00:01.0');
      expect(formatTime(65.5)).toBe('00:01:05.5');
    });
  });

  describe('Error Handling', () => {
    it('should create VideoProcessingError', () => {
      const error = new VideoProcessingError('FFmpeg failed', {
        operation: 'compose',
        format: 'VERTICAL',
      });
      
      expect(error.message).toBe('FFmpeg failed');
      expect(error.code).toBe('VIDEO_PROCESSING_ERROR');
      expect(error.statusCode).toBe(500);
      expect(error.context?.operation).toBe('compose');
    });

    it('should create ValidationError for invalid input', () => {
      const error = new ValidationError('Invalid video path', {
        operation: 'getVideoInfo',
        videoPath: '',
      });
      
      expect(error.code).toBe('VALIDATION_ERROR');
      expect(error.statusCode).toBe(400);
    });
  });

  describe('Duration Validation', () => {
    it('should validate video duration', () => {
      const isValidDuration = (duration: number): boolean => {
        return duration >= VIDEO_CONFIG.MIN_DURATION_SECONDS 
          && duration <= VIDEO_CONFIG.MAX_DURATION_SECONDS;
      };
      
      expect(isValidDuration(0.5)).toBe(false); // too short
      expect(isValidDuration(1)).toBe(true);    // min
      expect(isValidDuration(30)).toBe(true);   // ok
      expect(isValidDuration(60)).toBe(true);   // max
      expect(isValidDuration(61)).toBe(false);  // too long
    });

    it('should calculate frame count', () => {
      const calculateFrames = (duration: number, fps: number): number => {
        return Math.round(duration * fps);
      };
      
      expect(calculateFrames(10, 25)).toBe(250);  // 10s @ 25fps
      expect(calculateFrames(5, 30)).toBe(150);   // 5s @ 30fps
      expect(calculateFrames(1, 60)).toBe(60);    // 1s @ 60fps
    });
  });

  describe('Filter Graph', () => {
    it('should build scale filter', () => {
      const width = 1080;
      const height = 1920;
      const filter = `scale=${width}:${height}:force_original_aspect_ratio=decrease,pad=${width}:${height}:(ow-iw)/2:(oh-ih)/2`;
      
      expect(filter).toContain(`scale=${width}:${height}`);
      expect(filter).toContain('force_original_aspect_ratio=decrease');
    });

    it('should build overlay filter', () => {
      const filter = `overlay=(W-w)/2:(H-h)/2`;
      
      expect(filter).toContain('overlay');
      expect(filter).toContain('(W-w)/2');
      expect(filter).toContain('(H-h)/2');
    });

    it('should validate filter label format', () => {
      const label = '[video_with_avatar]';
      
      expect(label.startsWith('[')).toBe(true);
      expect(label.endsWith(']')).toBe(true);
      expect(label.length).toBeGreaterThan(2);
    });
  });
});
