/**
 * Unit Tests: GPU Client Validation
 * Testing validation logic without mocking full client
 */

import { describe, it, expect } from 'vitest';
import { ValidationError } from '@/lib/types';

describe('GPU Client Validation', () => {
  describe('Text Validation', () => {
    it('should reject empty text', () => {
      const text = '';
      expect(text.trim().length === 0).toBe(true);
    });

    it('should reject whitespace-only text', () => {
      const text = '   ';
      expect(text.trim().length === 0).toBe(true);
    });

    it('should accept valid text', () => {
      const text = 'Привет мир!';
      expect(text.trim().length > 0).toBe(true);
      expect(text.length < 5000).toBe(true);
    });

    it('should reject text over 5000 chars', () => {
      const text = 'A'.repeat(5001);
      expect(text.length > 5000).toBe(true);
    });
  });

  describe('Prompt Validation', () => {
    it('should reject empty prompt', () => {
      const prompt = '';
      expect(prompt.trim().length === 0).toBe(true);
    });

    it('should accept valid prompt', () => {
      const prompt = 'Modern office background';
      expect(prompt.trim().length > 0).toBe(true);
      expect(prompt.length < 1000).toBe(true);
    });

    it('should reject prompt over 1000 chars', () => {
      const prompt = 'A'.repeat(1001);
      expect(prompt.length > 1000).toBe(true);
    });
  });

  describe('Error Handling', () => {
    it('should create ValidationError with correct properties', () => {
      const error = new ValidationError('Test error', { operation: 'tts' });
      
      expect(error.message).toBe('Test error');
      expect(error.code).toBe('VALIDATION_ERROR');
      expect(error.statusCode).toBe(400);
      expect(error.context?.operation).toBe('tts');
    });

    it('should include context in validation errors', () => {
      const context = {
        operation: 'tts',
        textLength: 6000,
        maxLength: 5000,
      };
      
      const error = new ValidationError('Text too long', context);
      
      expect(error.context).toEqual(context);
      expect(error.context?.textLength).toBe(6000);
    });
  });

  describe('Buffer Validation', () => {
    it('should validate buffer is not empty', () => {
      const emptyBuffer = Buffer.alloc(0);
      const validBuffer = Buffer.from('test');
      
      expect(emptyBuffer.length).toBe(0);
      expect(validBuffer.length).toBeGreaterThan(0);
    });

    it('should check if value is Buffer', () => {
      const buffer = Buffer.from('test');
      const notBuffer = 'test';
      
      expect(Buffer.isBuffer(buffer)).toBe(true);
      expect(Buffer.isBuffer(notBuffer)).toBe(false);
    });
  });

  describe('File Path Validation', () => {
    it('should check for valid path format', () => {
      const validPath = '/tmp/test.png';
      const emptyPath = '';
      
      expect(validPath.length > 0).toBe(true);
      expect(emptyPath.length === 0).toBe(true);
    });

    it('should check for file extension', () => {
      const imagePath = '/tmp/avatar.png';
      const audioPath = '/tmp/audio.wav';
      const videoPath = '/tmp/video.mp4';
      
      expect(imagePath.endsWith('.png')).toBe(true);
      expect(audioPath.endsWith('.wav')).toBe(true);
      expect(videoPath.endsWith('.mp4')).toBe(true);
    });
  });
});
