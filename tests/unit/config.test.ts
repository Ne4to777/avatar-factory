/**
 * Unit Tests: lib/config.ts
 * Testing configuration and validation helpers
 */

import { describe, it, expect } from 'vitest';
import {
  VIDEO_DIMENSIONS,
  VIDEO_CONFIG,
  VOICE_CONFIG,
  QUEUE_CONFIG,
  BACKGROUND_STYLE_MAP,
  BACKGROUND_PROMPTS,
  validateVideoFormat,
  validateTextLength,
  validateUrl,
} from '@/lib/config';
import { ValidationError } from '@/lib/types';

describe('Configuration', () => {
  describe('VIDEO_DIMENSIONS', () => {
    it('should have correct dimensions for VERTICAL', () => {
      expect(VIDEO_DIMENSIONS.VERTICAL).toEqual({
        width: 1080,
        height: 1920,
      });
    });

    it('should have correct dimensions for HORIZONTAL', () => {
      expect(VIDEO_DIMENSIONS.HORIZONTAL).toEqual({
        width: 1920,
        height: 1080,
      });
    });

    it('should have correct dimensions for SQUARE', () => {
      expect(VIDEO_DIMENSIONS.SQUARE).toEqual({
        width: 1080,
        height: 1080,
      });
    });
  });

  describe('VIDEO_CONFIG', () => {
    it('should have correct default values', () => {
      expect(VIDEO_CONFIG.DEFAULT_FPS).toBe(25);
      expect(VIDEO_CONFIG.DEFAULT_CODEC).toBe('libx264');
      expect(VIDEO_CONFIG.DEFAULT_AUDIO_CODEC).toBe('aac');
      expect(VIDEO_CONFIG.DEFAULT_CRF).toBe(23);
      expect(VIDEO_CONFIG.MAX_DURATION_SECONDS).toBe(60);
    });
  });

  describe('VOICE_CONFIG', () => {
    it('should have correct default voice settings', () => {
      expect(VOICE_CONFIG.DEFAULT_LANGUAGE).toBe('ru');
      expect(VOICE_CONFIG.DEFAULT_SPEAKER).toBe('xenia');
    });

    it('should map speaker IDs correctly', () => {
      expect(VOICE_CONFIG.SPEAKER_MAP['ru_speaker_female']).toBe('xenia');
      expect(VOICE_CONFIG.SPEAKER_MAP['ru_speaker_male']).toBe('eugene');
    });
  });

  describe('QUEUE_CONFIG', () => {
    it('should have correct queue settings', () => {
      expect(QUEUE_CONFIG.VIDEO_GENERATION.name).toBe('video-generation');
      expect(QUEUE_CONFIG.VIDEO_GENERATION.concurrency).toBe(2);
      expect(QUEUE_CONFIG.VIDEO_GENERATION.maxRetries).toBe(3);
      expect(QUEUE_CONFIG.DEFAULT_PRIORITY).toBe(10);
    });
  });

  describe('Background Style Configuration', () => {
    it('should map API styles to internal styles', () => {
      expect(BACKGROUND_STYLE_MAP.simple).toBe('modern-office');
      expect(BACKGROUND_STYLE_MAP.professional).toBe('corporate-meeting');
      expect(BACKGROUND_STYLE_MAP.creative).toBe('artistic-studio');
      expect(BACKGROUND_STYLE_MAP.minimalist).toBe('clean-workspace');
    });

    it('should have prompts for all internal styles', () => {
      Object.values(BACKGROUND_STYLE_MAP).forEach((internalStyle) => {
        expect(BACKGROUND_PROMPTS[internalStyle]).toBeDefined();
        expect(BACKGROUND_PROMPTS[internalStyle]).toContain('4k');
      });
    });
  });
});

describe('Validation Helpers', () => {
  describe('validateVideoFormat', () => {
    it('should return true for valid formats', () => {
      expect(validateVideoFormat('VERTICAL')).toBe(true);
      expect(validateVideoFormat('HORIZONTAL')).toBe(true);
      expect(validateVideoFormat('SQUARE')).toBe(true);
    });

    it('should return false for invalid formats', () => {
      expect(validateVideoFormat('INVALID')).toBe(false);
      expect(validateVideoFormat('vertical')).toBe(false);
      expect(validateVideoFormat('')).toBe(false);
    });
  });

  describe('validateTextLength', () => {
    it('should not throw for valid text', () => {
      expect(() => validateTextLength('Hello')).not.toThrow();
      expect(() => validateTextLength('A'.repeat(100))).not.toThrow();
    });

    it('should throw ValidationError for empty text', () => {
      expect(() => validateTextLength('')).toThrow();
      
      try {
        validateTextLength('');
        expect.fail('Should have thrown');
      } catch (error) {
        expect(error).toBeInstanceOf(Error);
        expect((error as any).code).toBe('VALIDATION_ERROR');
        expect((error as Error).message).toContain('between 1 and 5000');
      }
    });

    it('should throw ValidationError for text too long', () => {
      expect(() => validateTextLength('A'.repeat(5001))).toThrow();
      
      try {
        validateTextLength('A'.repeat(5001));
        expect.fail('Should have thrown');
      } catch (error) {
        expect(error).toBeInstanceOf(Error);
        expect((error as any).code).toBe('VALIDATION_ERROR');
        expect((error as Error).message).toContain('between 1 and 5000');
      }
    });

    it('should respect custom min/max lengths', () => {
      expect(() => validateTextLength('Hi', 5, 10)).toThrow();
      expect(() => validateTextLength('Hello world too long', 1, 10)).toThrow();
      expect(() => validateTextLength('Valid', 1, 10)).not.toThrow();
    });
  });

  describe('validateUrl', () => {
    it('should not throw for valid URLs', () => {
      expect(() => validateUrl('http://example.com')).not.toThrow();
      expect(() => validateUrl('https://example.com/path')).not.toThrow();
      expect(() => validateUrl('https://example.com:8080/path?query=1')).not.toThrow();
    });

    it('should throw ValidationError for invalid URLs', () => {
      expect(() => validateUrl('not-a-url')).toThrow();
      expect(() => validateUrl('')).toThrow();
      expect(() => validateUrl('just-text')).toThrow();

      try {
        validateUrl('invalid');
        expect.fail('Should have thrown');
      } catch (error) {
        expect(error).toBeInstanceOf(Error);
        expect((error as any).code).toBe('VALIDATION_ERROR');
        expect((error as Error).message).toContain('Invalid URL');
      }
    });

    it('should handle edge cases', () => {
      expect(() => validateUrl('ftp://example.com')).not.toThrow();
      expect(() => validateUrl('file:///path/to/file')).not.toThrow();
    });
  });
});
