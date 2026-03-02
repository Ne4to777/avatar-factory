/**
 * Application Configuration
 * Централизованная конфигурация с валидацией
 */

import { ValidationError, type VideoDimensions, type StorageConfig } from './types';

// ==========================================
// Video Configuration
// ==========================================

export const VIDEO_DIMENSIONS: Record<string, VideoDimensions> = {
  VERTICAL: { width: 1080, height: 1920 }, // 9:16 Reels/Shorts
  HORIZONTAL: { width: 1920, height: 1080 }, // 16:9 YouTube
  SQUARE: { width: 1080, height: 1080 }, // 1:1 Instagram
} as const;

export const VIDEO_CONFIG = {
  DEFAULT_FPS: 25 as number,
  DEFAULT_BITRATE: 150 as number,
  DEFAULT_AUDIO_BITRATE: 128 as number,
  DEFAULT_AUDIO_SAMPLE_RATE: 48000 as number,
  MAX_DURATION_SECONDS: 60 as number,
  MIN_DURATION_SECONDS: 1 as number,
  DEFAULT_CODEC: 'libx264' as string,
  DEFAULT_AUDIO_CODEC: 'aac' as string,
  DEFAULT_PIXEL_FORMAT: 'yuv420p' as string,
  DEFAULT_PRESET: 'medium' as string,
  DEFAULT_CRF: 23 as number,
};

// ==========================================
// Environment Configuration
// ==========================================

function getEnvVar(key: string, defaultValue?: string): string {
  const value = process.env[key];
  if (!value && !defaultValue) {
    throw new ValidationError(`Missing required environment variable: ${key}`);
  }
  return value || defaultValue!;
}

function getEnvNumber(key: string, defaultValue: number): number {
  const value = process.env[key];
  if (!value) return defaultValue;
  const parsed = parseInt(value, 10);
  if (isNaN(parsed)) {
    throw new ValidationError(`Invalid number for ${key}: ${value}`);
  }
  return parsed;
}

export const ENV = {
  NODE_ENV: getEnvVar('NODE_ENV', 'development'),
  PORT: getEnvNumber('PORT', 3000),
  
  // Database
  DATABASE_URL: getEnvVar('DATABASE_URL'),
  
  // Redis
  REDIS_HOST: getEnvVar('REDIS_HOST', 'localhost'),
  REDIS_PORT: getEnvNumber('REDIS_PORT', 6379),
  
  // GPU Server
  GPU_SERVER_URL: getEnvVar('GPU_SERVER_URL', 'http://localhost:8001'),
  GPU_API_KEY: getEnvVar('GPU_API_KEY', 'development-key'),
  GPU_TIMEOUT_MS: getEnvNumber('GPU_TIMEOUT_MS', 300000), // 5 minutes
  
  // Storage (MinIO/S3)
  S3_ENDPOINT: getEnvVar('S3_ENDPOINT', 'http://localhost:9000'),
  S3_ACCESS_KEY: getEnvVar('S3_ACCESS_KEY', 'minioadmin'),
  S3_SECRET_KEY: getEnvVar('S3_SECRET_KEY', 'minioadmin'),
  S3_BUCKET: getEnvVar('S3_BUCKET', 'avatar-videos'),
  S3_REGION: getEnvVar('S3_REGION', 'us-east-1'),
  
  // Temp files
  TEMP_DIR: getEnvVar('TEMP_DIR', '/tmp/avatar-factory'),
  
  // Logging
  LOG_LEVEL: getEnvVar('LOG_LEVEL', 'INFO'),
} as const;

// ==========================================
// Storage Configuration
// ==========================================

export const STORAGE_CONFIG: StorageConfig = {
  endpoint: ENV.S3_ENDPOINT,
  accessKeyId: ENV.S3_ACCESS_KEY,
  secretAccessKey: ENV.S3_SECRET_KEY,
  bucketName: ENV.S3_BUCKET,
  region: ENV.S3_REGION,
};

export const STORAGE_PATHS = {
  VIDEOS: 'videos',
  THUMBNAILS: 'thumbnails',
  TEMP: 'temp',
  AVATARS: 'avatars',
} as const;

// ==========================================
// Queue Configuration
// ==========================================

export const QUEUE_CONFIG = {
  VIDEO_GENERATION: {
    name: 'video-generation',
    concurrency: 2,
    maxRetries: 3,
    backoff: {
      type: 'exponential' as const,
      delay: 5000,
    },
  },
  DEFAULT_PRIORITY: 10,
  HIGH_PRIORITY: 1,
  LOW_PRIORITY: 20,
} as const;

// ==========================================
// Voice Configuration
// ==========================================

export const VOICE_CONFIG = {
  DEFAULT_LANGUAGE: 'ru',
  DEFAULT_SPEAKER: 'xenia',
  SPEAKER_MAP: {
    'ru_speaker_female': 'xenia',
    'ru_speaker_male': 'eugene',
    'en_speaker_female': 'en_female',
    'en_speaker_male': 'en_male',
  } as const,
} as const;

// ==========================================
// Background Style Configuration
// ==========================================

export const BACKGROUND_STYLE_MAP = {
  simple: 'modern-office',
  professional: 'corporate-meeting',
  creative: 'artistic-studio',
  minimalist: 'clean-workspace',
} as const;

export type BackgroundStyleAPI = keyof typeof BACKGROUND_STYLE_MAP;
export type BackgroundStyleInternal = (typeof BACKGROUND_STYLE_MAP)[BackgroundStyleAPI];

export const BACKGROUND_PROMPTS: Record<BackgroundStyleInternal, string> = {
  'modern-office': 'modern minimalist office, soft lighting, professional, 4k',
  'corporate-meeting': 'elegant corporate meeting room, glass walls, sophisticated, 4k',
  'artistic-studio': 'creative art studio, colorful, inspiring, natural light, 4k',
  'clean-workspace': 'minimalist clean workspace, zen, peaceful, soft colors, 4k',
};

// ==========================================
// Validation Helpers
// ==========================================

export function validateVideoFormat(format: string): boolean {
  return format in VIDEO_DIMENSIONS;
}

export function validateTextLength(text: string, minLength = 1, maxLength = 5000): void {
  if (text.length < minLength || text.length > maxLength) {
    throw new ValidationError(
      `Text length must be between ${minLength} and ${maxLength} characters`,
      { text: text.substring(0, 100) }
    );
  }
}

export function validateUrl(url: string): void {
  try {
    new URL(url);
  } catch {
    throw new ValidationError(`Invalid URL: ${url}`);
  }
}
