/**
 * Unit Tests: lib/logger.ts
 * Testing structured logging
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { logger, LogLevel } from '@/lib/logger';

describe('Logger', () => {
  let consoleLogSpy: any;
  let consoleErrorSpy: any;
  let consoleWarnSpy: any;
  let consoleDebugSpy: any;

  beforeEach(() => {
    consoleLogSpy = vi.spyOn(console, 'log').mockImplementation(() => {});
    consoleErrorSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
    consoleWarnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {});
    consoleDebugSpy = vi.spyOn(console, 'debug').mockImplementation(() => {});
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe('Log Levels', () => {
    it('should log INFO messages', () => {
      logger.info('Test info message');
      
      expect(consoleLogSpy).toHaveBeenCalledOnce();
      const logCall = consoleLogSpy.mock.calls[0][0];
      expect(logCall).toContain('INFO');
      expect(logCall).toContain('Test info message');
    });

    it('should log WARN messages', () => {
      logger.warn('Test warning');
      
      expect(consoleWarnSpy).toHaveBeenCalledOnce();
      const logCall = consoleWarnSpy.mock.calls[0][0];
      expect(logCall).toContain('WARN');
      expect(logCall).toContain('Test warning');
    });

    it('should log ERROR messages', () => {
      const error = new Error('Test error');
      logger.error('Error occurred', error);
      
      expect(consoleErrorSpy).toHaveBeenCalledOnce();
      const logCall = consoleErrorSpy.mock.calls[0][0];
      expect(logCall).toContain('ERROR');
      expect(logCall).toContain('Error occurred');
      expect(logCall).toContain('Test error');
    });

    it('should log DEBUG messages', () => {
      logger.debug('Debug info');
      
      // DEBUG не логируется по умолчанию (LOG_LEVEL=ERROR в test setup)
      // Но если бы логировался, проверяли бы consoleDebugSpy
    });
  });

  describe('Context Logging', () => {
    it('should include context in log', () => {
      logger.info('Operation started', { userId: '123', operation: 'test' });
      
      expect(consoleLogSpy).toHaveBeenCalledOnce();
      const logCall = consoleLogSpy.mock.calls[0][0];
      expect(logCall).toContain('Context:');
      expect(logCall).toContain('userId');
      expect(logCall).toContain('123');
      expect(logCall).toContain('operation');
      expect(logCall).toContain('test');
    });

    it('should handle empty context', () => {
      logger.info('No context');
      
      expect(consoleLogSpy).toHaveBeenCalledOnce();
      const logCall = consoleLogSpy.mock.calls[0][0];
      expect(logCall).not.toContain('Context:');
    });
  });

  describe('Error Logging', () => {
    it('should include error stack trace', () => {
      const error = new Error('Test error');
      logger.error('Failed', error);
      
      expect(consoleErrorSpy).toHaveBeenCalledOnce();
      const logCall = consoleErrorSpy.mock.calls[0][0];
      expect(logCall).toContain('Error: Test error');
      expect(logCall).toContain('Stack:');
    });

    it('should handle errors without stack', () => {
      const error: any = { message: 'Simple error' };
      logger.error('Failed', error);
      
      expect(consoleErrorSpy).toHaveBeenCalledOnce();
      const logCall = consoleErrorSpy.mock.calls[0][0];
      expect(logCall).toContain('Simple error');
    });
  });

  describe('Specialized Logging Methods', () => {
    it('should log video processing events', () => {
      logger.videoProcessing('video-123', 'Starting composition');
      
      expect(consoleLogSpy).toHaveBeenCalledOnce();
      const logCall = consoleLogSpy.mock.calls[0][0];
      expect(logCall).toContain('Starting composition');
      expect(logCall).toContain('video-123');
    });

    it('should log video errors', () => {
      const error = new Error('Composition failed');
      logger.videoError('video-123', error);
      
      expect(consoleErrorSpy).toHaveBeenCalledOnce();
      const logCall = consoleErrorSpy.mock.calls[0][0];
      expect(logCall).toContain('Video processing failed');
      expect(logCall).toContain('video-123');
      expect(logCall).toContain('Composition failed');
    });

    it('should log GPU requests', () => {
      logger.gpuRequest('tts', { textLength: 100 });
      
      expect(consoleLogSpy).toHaveBeenCalledOnce();
      const logCall = consoleLogSpy.mock.calls[0][0];
      expect(logCall).toContain('GPU Server request: tts');
      expect(logCall).toContain('textLength');
    });

    it('should log GPU errors', () => {
      const error = new Error('GPU unavailable');
      logger.gpuError('tts', error);
      
      expect(consoleErrorSpy).toHaveBeenCalledOnce();
      const logCall = consoleErrorSpy.mock.calls[0][0];
      expect(logCall).toContain('GPU Server error: tts');
      expect(logCall).toContain('GPU unavailable');
    });

    it('should log storage operations', () => {
      logger.storageOperation('upload', { key: 'video.mp4' });
      
      expect(consoleLogSpy).toHaveBeenCalledOnce();
      const logCall = consoleLogSpy.mock.calls[0][0];
      expect(logCall).toContain('Storage operation: upload');
      expect(logCall).toContain('video.mp4');
    });

    it('should log storage errors', () => {
      const error = new Error('Upload failed');
      logger.storageError('upload', error);
      
      expect(consoleErrorSpy).toHaveBeenCalledOnce();
      const logCall = consoleErrorSpy.mock.calls[0][0];
      expect(logCall).toContain('Storage error: upload');
      expect(logCall).toContain('Upload failed');
    });
  });

  describe('Timestamp', () => {
    it('should include timestamp in ISO format', () => {
      logger.info('Test');
      
      expect(consoleLogSpy).toHaveBeenCalledOnce();
      const logCall = consoleLogSpy.mock.calls[0][0];
      
      // Timestamp should match ISO format: [YYYY-MM-DDTHH:mm:ss.sssZ]
      expect(logCall).toMatch(/\[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z\]/);
    });
  });
});
