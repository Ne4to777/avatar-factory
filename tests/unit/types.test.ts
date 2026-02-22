/**
 * Unit Tests: lib/types.ts
 * Testing custom error classes
 */

import { describe, it, expect } from 'vitest';
import {
  AvatarFactoryError,
  GPUServerError,
  StorageError,
  ValidationError,
  VideoProcessingError,
} from '@/lib/types';

describe('Custom Error Classes', () => {
  describe('AvatarFactoryError', () => {
    it('should create error with message and code', () => {
      const error = new AvatarFactoryError('Test error', 'TEST_ERROR', 500);
      
      expect(error).toBeInstanceOf(Error);
      expect(error).toBeInstanceOf(AvatarFactoryError);
      expect(error.message).toBe('Test error');
      expect(error.code).toBe('TEST_ERROR');
      expect(error.statusCode).toBe(500);
      expect(error.name).toBe('AvatarFactoryError');
    });

    it('should include context', () => {
      const context = { videoId: '123', userId: 'user-1' };
      const error = new AvatarFactoryError('Test error', 'TEST_ERROR', 500, context);
      
      expect(error.context).toEqual(context);
      expect(error.context?.videoId).toBe('123');
      expect(error.context?.userId).toBe('user-1');
    });

    it('should default to status code 500', () => {
      const error = new AvatarFactoryError('Test error', 'TEST_ERROR');
      
      expect(error.statusCode).toBe(500);
    });
  });

  describe('GPUServerError', () => {
    it('should create GPU server error', () => {
      const error = new GPUServerError('GPU unavailable');
      
      expect(error).toBeInstanceOf(Error);
      expect(error).toBeInstanceOf(AvatarFactoryError);
      expect(error.name).toBe('GPUServerError');
      expect(error.message).toBe('GPU unavailable');
      expect(error.code).toBe('GPU_SERVER_ERROR');
      expect(error.statusCode).toBe(503);
    });

    it('should include context', () => {
      const context = { operation: 'tts', serverUrl: 'http://localhost:8001' };
      const error = new GPUServerError('TTS failed', context);
      
      expect(error.context).toEqual(context);
    });
  });

  describe('StorageError', () => {
    it('should create storage error', () => {
      const error = new StorageError('Upload failed');
      
      expect(error).toBeInstanceOf(Error);
      expect(error).toBeInstanceOf(AvatarFactoryError);
      expect(error.name).toBe('StorageError');
      expect(error.message).toBe('Upload failed');
      expect(error.code).toBe('STORAGE_ERROR');
      expect(error.statusCode).toBe(500);
    });

    it('should include context', () => {
      const context = { operation: 'upload', key: 'video.mp4' };
      const error = new StorageError('Upload failed', context);
      
      expect(error.context).toEqual(context);
    });
  });

  describe('ValidationError', () => {
    it('should create validation error', () => {
      const error = new ValidationError('Invalid input');
      
      expect(error).toBeInstanceOf(Error);
      expect(error).toBeInstanceOf(AvatarFactoryError);
      expect(error.name).toBe('ValidationError');
      expect(error.message).toBe('Invalid input');
      expect(error.code).toBe('VALIDATION_ERROR');
      expect(error.statusCode).toBe(400);
    });

    it('should include context', () => {
      const context = { operation: 'tts', textLength: 6000 };
      const error = new ValidationError('Text too long', context);
      
      expect(error.context).toEqual(context);
    });
  });

  describe('VideoProcessingError', () => {
    it('should create video processing error', () => {
      const error = new VideoProcessingError('FFmpeg failed');
      
      expect(error).toBeInstanceOf(Error);
      expect(error).toBeInstanceOf(AvatarFactoryError);
      expect(error.name).toBe('VideoProcessingError');
      expect(error.message).toBe('FFmpeg failed');
      expect(error.code).toBe('VIDEO_PROCESSING_ERROR');
      expect(error.statusCode).toBe(500);
    });

    it('should include context', () => {
      const context = { operation: 'compose', format: 'VERTICAL' };
      const error = new VideoProcessingError('Composition failed', context);
      
      expect(error.context).toEqual(context);
    });
  });

  describe('Error type identification', () => {
    it('should correctly identify error types by name and code', () => {
      const baseError = new AvatarFactoryError('Base', 'BASE');
      const gpuError = new GPUServerError('GPU');
      const storageError = new StorageError('Storage');
      const validationError = new ValidationError('Validation');
      const videoError = new VideoProcessingError('Video');

      // Base error
      expect(baseError.name).toBe('AvatarFactoryError');
      expect(baseError.code).toBe('BASE');

      // GPU error
      expect(gpuError.name).toBe('GPUServerError');
      expect(gpuError.code).toBe('GPU_SERVER_ERROR');
      expect(gpuError instanceof AvatarFactoryError).toBe(true);

      // Storage error
      expect(storageError.name).toBe('StorageError');
      expect(storageError.code).toBe('STORAGE_ERROR');
      expect(storageError instanceof AvatarFactoryError).toBe(true);

      // Validation error
      expect(validationError.name).toBe('ValidationError');
      expect(validationError.code).toBe('VALIDATION_ERROR');
      expect(validationError instanceof AvatarFactoryError).toBe(true);

      // Video error
      expect(videoError.name).toBe('VideoProcessingError');
      expect(videoError.code).toBe('VIDEO_PROCESSING_ERROR');
      expect(videoError instanceof AvatarFactoryError).toBe(true);
    });

    it('should differentiate errors by code', () => {
      const errors = [
        new GPUServerError('GPU'),
        new StorageError('Storage'),
        new ValidationError('Validation'),
        new VideoProcessingError('Video'),
      ];

      const codes = errors.map(e => e.code);
      expect(codes).toEqual([
        'GPU_SERVER_ERROR',
        'STORAGE_ERROR',
        'VALIDATION_ERROR',
        'VIDEO_PROCESSING_ERROR',
      ]);
    });
  });

  describe('Error serialization', () => {
    it('should preserve properties when serialized', () => {
      const error = new GPUServerError('Test', { operation: 'tts' });
      
      const serialized = JSON.parse(JSON.stringify({
        message: error.message,
        code: error.code,
        statusCode: error.statusCode,
        context: error.context,
      }));

      expect(serialized.message).toBe('Test');
      expect(serialized.code).toBe('GPU_SERVER_ERROR');
      expect(serialized.statusCode).toBe(503);
      expect(serialized.context).toEqual({ operation: 'tts' });
    });
  });
});
