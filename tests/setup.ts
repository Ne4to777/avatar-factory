/**
 * Vitest Setup File
 * Runs before all tests
 */

import { vi, beforeEach } from 'vitest';
import { promises as fs } from 'fs';
import path from 'path';

// Mock environment variables
Object.assign(process.env, { NODE_ENV: 'test' });
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/avatar_factory_test';
process.env.REDIS_HOST = 'localhost';
process.env.REDIS_PORT = '6379';
process.env.GPU_SERVER_URL = 'http://localhost:8001';
process.env.GPU_API_KEY = 'test-key';
process.env.S3_ENDPOINT = 'http://localhost:9000';
process.env.S3_ACCESS_KEY = 'minioadmin';
process.env.S3_SECRET_KEY = 'minioadmin';
process.env.S3_BUCKET = 'test-bucket';
process.env.S3_REGION = 'us-east-1';
process.env.TEMP_DIR = '/tmp/avatar-factory-test';
process.env.LOG_LEVEL = 'DEBUG'; // Allow all logs during tests

// Create temp directory for tests
beforeEach(async () => {
  const tempDir = process.env.TEMP_DIR!;
  try {
    await fs.mkdir(tempDir, { recursive: true });
  } catch (error) {
    // Directory might already exist
  }
});

// Global test utilities
declare global {
  var testUtils: {
    createTempFile: (content: Buffer | string, ext?: string) => Promise<string>;
    cleanupTempFiles: (files: string[]) => Promise<void>;
  };
}

global.testUtils = {
  async createTempFile(content: Buffer | string, ext: string = '.txt'): Promise<string> {
    const tempDir = process.env.TEMP_DIR!;
    const filePath = path.join(tempDir, `test-${Date.now()}-${Math.random().toString(36).slice(2)}${ext}`);
    await fs.writeFile(filePath, content);
    return filePath;
  },

  async cleanupTempFiles(files: string[]): Promise<void> {
    await Promise.allSettled(
      files.map(file => fs.unlink(file).catch(() => {}))
    );
  },
};
