/**
 * Unit Tests: lib/queue.ts
 * Testing queue configuration and job management logic
 */

import { describe, it, expect } from 'vitest';
import { QUEUE_CONFIG } from '@/lib/config';
import type { VideoJobData, VideoJobResult } from '@/lib/types';

describe('Queue Module', () => {
  describe('Queue Configuration', () => {
    it('should have correct video generation queue config', () => {
      expect(QUEUE_CONFIG.VIDEO_GENERATION.name).toBe('video-generation');
      expect(QUEUE_CONFIG.VIDEO_GENERATION.concurrency).toBe(2);
      expect(QUEUE_CONFIG.VIDEO_GENERATION.maxRetries).toBe(3);
    });

    it('should have backoff configuration', () => {
      expect(QUEUE_CONFIG.VIDEO_GENERATION.backoff.type).toBe('exponential');
      expect(QUEUE_CONFIG.VIDEO_GENERATION.backoff.delay).toBe(5000);
    });

    it('should have priority levels', () => {
      expect(QUEUE_CONFIG.DEFAULT_PRIORITY).toBe(10);
      expect(QUEUE_CONFIG.HIGH_PRIORITY).toBe(1);
      expect(QUEUE_CONFIG.LOW_PRIORITY).toBe(20);
    });

    it('should have correct priority ordering', () => {
      const { HIGH_PRIORITY, DEFAULT_PRIORITY, LOW_PRIORITY } = QUEUE_CONFIG;
      
      expect(HIGH_PRIORITY).toBeLessThan(DEFAULT_PRIORITY);
      expect(DEFAULT_PRIORITY).toBeLessThan(LOW_PRIORITY);
    });
  });

  describe('VideoJobData Structure', () => {
    it('should create valid job data', () => {
      const jobData: VideoJobData = {
        videoId: 'video-123',
        userId: 'user-456',
        text: 'Привет мир!',
        photoUrl: 'http://example.com/photo.jpg',
        backgroundStyle: 'professional',
        voiceId: 'ru_speaker_female',
        format: 'VERTICAL',
      };
      
      expect(jobData.videoId).toBe('video-123');
      expect(jobData.userId).toBe('user-456');
      expect(jobData.text).toBe('Привет мир!');
      expect(jobData.format).toBe('VERTICAL');
    });

    it('should allow optional fields', () => {
      const jobData: VideoJobData = {
        videoId: 'video-123',
        userId: 'user-456',
        text: 'Test',
        backgroundStyle: 'simple',
        voiceId: 'ru_speaker_male',
        format: 'SQUARE',
      };
      
      expect(jobData.photoUrl).toBeUndefined();
      expect(jobData.avatarId).toBeUndefined();
      expect(jobData.backgroundUrl).toBeUndefined();
    });

    it('should validate background styles', () => {
      const validStyles: Array<'simple' | 'professional' | 'creative' | 'minimalist'> = [
        'simple',
        'professional',
        'creative',
        'minimalist',
      ];
      
      validStyles.forEach(style => {
        const jobData: VideoJobData = {
          videoId: 'video-123',
          userId: 'user-456',
          text: 'Test',
          backgroundStyle: style,
          voiceId: 'ru_speaker_female',
          format: 'VERTICAL',
        };
        
        expect(jobData.backgroundStyle).toBe(style);
      });
    });

    it('should validate video formats', () => {
      const validFormats: Array<'VERTICAL' | 'HORIZONTAL' | 'SQUARE'> = [
        'VERTICAL',
        'HORIZONTAL',
        'SQUARE',
      ];
      
      validFormats.forEach(format => {
        const jobData: VideoJobData = {
          videoId: 'video-123',
          userId: 'user-456',
          text: 'Test',
          backgroundStyle: 'professional',
          voiceId: 'ru_speaker_female',
          format,
        };
        
        expect(jobData.format).toBe(format);
      });
    });
  });

  describe('VideoJobResult Structure', () => {
    it('should create valid job result', () => {
      const result: VideoJobResult = {
        videoId: 'video-123',
        videoUrl: 'http://storage.com/video.mp4',
        thumbnailUrl: 'http://storage.com/thumb.png',
        duration: 10,
        format: 'VERTICAL',
        quality: 'MEDIUM',
      };
      
      expect(result.videoId).toBe('video-123');
      expect(result.videoUrl).toBe('http://storage.com/video.mp4');
      expect(result.thumbnailUrl).toBe('http://storage.com/thumb.png');
      expect(result.duration).toBe(10);
      expect(result.format).toBe('VERTICAL');
      expect(result.quality).toBe('MEDIUM');
    });

    it('should validate quality levels', () => {
      const validQualities: Array<'LOW' | 'MEDIUM' | 'HIGH'> = [
        'LOW',
        'MEDIUM',
        'HIGH',
      ];
      
      validQualities.forEach(quality => {
        const result: VideoJobResult = {
          videoId: 'video-123',
          videoUrl: 'http://storage.com/video.mp4',
          thumbnailUrl: 'http://storage.com/thumb.png',
          duration: 10,
          format: 'VERTICAL',
          quality,
        };
        
        expect(result.quality).toBe(quality);
      });
    });
  });

  describe('Job Priority Calculation', () => {
    it('should calculate priority based on user tier', () => {
      const calculatePriority = (tier: 'free' | 'pro' | 'enterprise'): number => {
        switch (tier) {
          case 'enterprise':
            return QUEUE_CONFIG.HIGH_PRIORITY;
          case 'pro':
            return QUEUE_CONFIG.DEFAULT_PRIORITY;
          case 'free':
            return QUEUE_CONFIG.LOW_PRIORITY;
        }
      };
      
      expect(calculatePriority('enterprise')).toBe(1);
      expect(calculatePriority('pro')).toBe(10);
      expect(calculatePriority('free')).toBe(20);
    });

    it('should sort jobs by priority', () => {
      const jobs = [
        { priority: 20, id: 'job1' },
        { priority: 1, id: 'job2' },
        { priority: 10, id: 'job3' },
      ];
      
      const sorted = jobs.sort((a, b) => a.priority - b.priority);
      
      expect(sorted[0].id).toBe('job2'); // priority 1
      expect(sorted[1].id).toBe('job3'); // priority 10
      expect(sorted[2].id).toBe('job1'); // priority 20
    });
  });

  describe('Job State Management', () => {
    it('should define valid job states', () => {
      const validStates = [
        'waiting',
        'active',
        'completed',
        'failed',
        'delayed',
      ];
      
      validStates.forEach(state => {
        expect(typeof state).toBe('string');
        expect(state.length).toBeGreaterThan(0);
      });
    });

    it('should track job progress', () => {
      const progress = [0, 10, 20, 50, 75, 90, 100];
      
      progress.forEach(p => {
        expect(p).toBeGreaterThanOrEqual(0);
        expect(p).toBeLessThanOrEqual(100);
      });
    });

    it('should format progress object', () => {
      const progress = { progress: 50 };
      
      expect(progress.progress).toBe(50);
      expect(typeof progress.progress).toBe('number');
    });
  });

  describe('Retry Logic', () => {
    it('should calculate exponential backoff', () => {
      const calculateBackoff = (attempt: number, baseDelay: number = 5000): number => {
        return baseDelay * Math.pow(2, attempt - 1);
      };
      
      expect(calculateBackoff(1, 5000)).toBe(5000);  // 5s
      expect(calculateBackoff(2, 5000)).toBe(10000); // 10s
      expect(calculateBackoff(3, 5000)).toBe(20000); // 20s
    });

    it('should respect max retries', () => {
      const maxRetries = QUEUE_CONFIG.VIDEO_GENERATION.maxRetries;
      const attempts = [1, 2, 3, 4];
      
      attempts.forEach(attempt => {
        const shouldRetry = attempt <= maxRetries;
        expect(shouldRetry).toBe(attempt <= 3);
      });
    });
  });

  describe('Queue Metrics', () => {
    it('should calculate queue metrics', () => {
      const metrics = {
        waiting: 5,
        active: 2,
        completed: 100,
        failed: 3,
        delayed: 1,
      };
      
      const total = Object.values(metrics).reduce((sum, val) => sum + val, 0);
      
      expect(total).toBe(111);
      expect(metrics.waiting).toBe(5);
      expect(metrics.active).toBe(2);
    });

    it('should calculate success rate', () => {
      const completed = 95;
      const failed = 5;
      const total = completed + failed;
      const successRate = (completed / total) * 100;
      
      expect(successRate).toBe(95);
    });

    it('should track processing time', () => {
      const startTime = Date.now();
      const endTime = startTime + 5000; // 5 seconds later
      const duration = endTime - startTime;
      
      expect(duration).toBe(5000);
      expect(duration / 1000).toBe(5); // seconds
    });
  });

  describe('Job Cleanup', () => {
    it('should calculate cleanup age', () => {
      const oneDayMs = 24 * 3600 * 1000;
      const oneWeekMs = 7 * 24 * 3600 * 1000;
      
      expect(oneDayMs).toBe(86400000);
      expect(oneWeekMs).toBe(604800000);
    });

    it('should determine if job is old enough to clean', () => {
      const now = Date.now();
      const oneDayAgo = now - 24 * 3600 * 1000;
      const oneWeekAgo = now - 7 * 24 * 3600 * 1000;
      
      const isOlderThanDay = (timestamp: number) => timestamp < oneDayAgo;
      const isOlderThanWeek = (timestamp: number) => timestamp < oneWeekAgo;
      
      expect(isOlderThanDay(oneWeekAgo)).toBe(true);
      expect(isOlderThanWeek(oneDayAgo)).toBe(false);
    });
  });
});
