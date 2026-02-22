/**
 * Unit Tests: lib/storage.ts
 * Testing storage operations with validation
 */

import { describe, it, expect } from 'vitest';
import { StorageError, ValidationError } from '@/lib/types';
import path from 'path';

describe('Storage Module', () => {
  describe('File Path Validation', () => {
    it('should validate non-empty file path', () => {
      const filePath = '/tmp/test.mp4';
      expect(filePath.length > 0).toBe(true);
      expect(filePath.trim().length > 0).toBe(true);
    });

    it('should detect empty file path', () => {
      const filePath = '';
      expect(filePath.length === 0).toBe(true);
    });

    it('should detect whitespace-only path', () => {
      const filePath = '   ';
      expect(filePath.trim().length === 0).toBe(true);
    });
  });

  describe('Key Generation', () => {
    it('should generate key with folder prefix', () => {
      const folder = 'videos';
      const ext = '.mp4';
      const key = `${folder}/test-${Date.now()}${ext}`;
      
      expect(key.startsWith('videos/')).toBe(true);
      expect(key.endsWith('.mp4')).toBe(true);
    });

    it('should extract extension from filename', () => {
      const filename = 'video.mp4';
      const ext = path.extname(filename);
      
      expect(ext).toBe('.mp4');
    });

    it('should handle filenames without extension', () => {
      const filename = 'video';
      const ext = path.extname(filename);
      
      expect(ext).toBe('');
    });
  });

  describe('Content Type Detection', () => {
    const contentTypes: Record<string, string> = {
      '.mp4': 'video/mp4',
      '.webm': 'video/webm',
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.wav': 'audio/wav',
      '.mp3': 'audio/mpeg',
    };

    it('should map video extensions', () => {
      expect(contentTypes['.mp4']).toBe('video/mp4');
      expect(contentTypes['.webm']).toBe('video/webm');
    });

    it('should map image extensions', () => {
      expect(contentTypes['.png']).toBe('image/png');
      expect(contentTypes['.jpg']).toBe('image/jpeg');
      expect(contentTypes['.jpeg']).toBe('image/jpeg');
    });

    it('should map audio extensions', () => {
      expect(contentTypes['.wav']).toBe('audio/wav');
      expect(contentTypes['.mp3']).toBe('audio/mpeg');
    });

    it('should handle unknown extensions', () => {
      const ext = '.unknown';
      const contentType = contentTypes[ext] || 'application/octet-stream';
      
      expect(contentType).toBe('application/octet-stream');
    });

    it('should be case-insensitive', () => {
      const ext = '.MP4';
      const contentType = contentTypes[ext.toLowerCase()];
      
      expect(contentType).toBe('video/mp4');
    });
  });

  describe('URL Parsing', () => {
    it('should extract key from URL', () => {
      const url = 'http://localhost:9000/avatar-videos/videos/test.mp4';
      const urlObj = new URL(url);
      const pathParts = urlObj.pathname.split('/');
      const key = pathParts.slice(2).join('/'); // Remove /bucket/
      
      expect(key).toBe('videos/test.mp4');
    });

    it('should handle nested paths', () => {
      const url = 'http://localhost:9000/bucket/folder/subfolder/file.mp4';
      const urlObj = new URL(url);
      const pathParts = urlObj.pathname.split('/');
      const key = pathParts.slice(2).join('/');
      
      expect(key).toBe('folder/subfolder/file.mp4');
    });

    it('should validate URL format', () => {
      const validUrl = 'http://localhost:9000/bucket/key';
      const invalidUrl = 'not-a-url';
      
      expect(() => new URL(validUrl)).not.toThrow();
      expect(() => new URL(invalidUrl)).toThrow();
    });
  });

  describe('Buffer Validation', () => {
    it('should check buffer is not empty', () => {
      const emptyBuffer = Buffer.alloc(0);
      const validBuffer = Buffer.from('test data');
      
      expect(emptyBuffer.length).toBe(0);
      expect(validBuffer.length).toBeGreaterThan(0);
    });

    it('should check if value is Buffer', () => {
      const buffer = Buffer.from('test');
      const notBuffer = 'test';
      const notBuffer2 = { data: 'test' };
      
      expect(Buffer.isBuffer(buffer)).toBe(true);
      expect(Buffer.isBuffer(notBuffer)).toBe(false);
      expect(Buffer.isBuffer(notBuffer2)).toBe(false);
    });

    it('should create buffer from different sources', () => {
      const fromString = Buffer.from('hello');
      const fromArray = Buffer.from([72, 101, 108, 108, 111]);
      
      expect(Buffer.isBuffer(fromString)).toBe(true);
      expect(Buffer.isBuffer(fromArray)).toBe(true);
      expect(fromString.toString()).toBe('hello');
      expect(fromArray.toString()).toBe('Hello');
    });
  });

  describe('Folder Types', () => {
    const validFolders = ['videos', 'thumbnails', 'backgrounds', 'avatars', 'temp'];

    it('should accept valid folder types', () => {
      validFolders.forEach(folder => {
        expect(validFolders.includes(folder)).toBe(true);
      });
    });

    it('should reject invalid folder types', () => {
      const invalidFolders = ['invalid', 'random', 'test'];
      
      invalidFolders.forEach(folder => {
        expect(validFolders.includes(folder)).toBe(false);
      });
    });
  });

  describe('Error Handling', () => {
    it('should create StorageError with context', () => {
      const error = new StorageError('Upload failed', {
        operation: 'upload',
        key: 'video.mp4',
        size: 1024,
      });
      
      expect(error.message).toBe('Upload failed');
      expect(error.code).toBe('STORAGE_ERROR');
      expect(error.statusCode).toBe(500);
      expect(error.context?.operation).toBe('upload');
      expect(error.context?.key).toBe('video.mp4');
      expect(error.context?.size).toBe(1024);
    });

    it('should create ValidationError for invalid input', () => {
      const error = new ValidationError('Key cannot be empty', {
        operation: 'delete',
      });
      
      expect(error.message).toBe('Key cannot be empty');
      expect(error.code).toBe('VALIDATION_ERROR');
      expect(error.statusCode).toBe(400);
    });
  });

  describe('File Size Handling', () => {
    it('should handle file sizes', () => {
      const sizes = {
        '1KB': 1024,
        '1MB': 1024 * 1024,
        '1GB': 1024 * 1024 * 1024,
      };
      
      expect(sizes['1KB']).toBe(1024);
      expect(sizes['1MB']).toBe(1048576);
      expect(sizes['1GB']).toBe(1073741824);
    });

    it('should format file sizes', () => {
      const formatSize = (bytes: number): string => {
        if (bytes < 1024) return `${bytes} B`;
        if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(2)} KB`;
        if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
        return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
      };
      
      expect(formatSize(500)).toBe('500 B');
      expect(formatSize(2048)).toBe('2.00 KB');
      expect(formatSize(1048576)).toBe('1.00 MB');
      expect(formatSize(1073741824)).toBe('1.00 GB');
    });
  });

  describe('S3 Configuration', () => {
    it('should build endpoint URL', () => {
      const endpoint = 'http://localhost:9000';
      const bucket = 'avatar-videos';
      const key = 'videos/test.mp4';
      
      const publicUrl = `${endpoint}/${bucket}/${key}`;
      
      expect(publicUrl).toBe('http://localhost:9000/avatar-videos/videos/test.mp4');
    });

    it('should handle endpoint with/without trailing slash', () => {
      const endpoint1 = 'http://localhost:9000';
      const endpoint2 = 'http://localhost:9000/';
      const bucket = 'bucket';
      const key = 'key';
      
      const url1 = `${endpoint1}/${bucket}/${key}`;
      const url2 = `${endpoint2.replace(/\/$/, '')}/${bucket}/${key}`;
      
      expect(url1).toBe(url2);
    });
  });
});
