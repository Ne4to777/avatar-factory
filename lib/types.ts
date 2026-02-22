/**
 * Shared Types for Avatar Factory
 * Централизованные типы для всего приложения
 */

// ==========================================
// Video Types
// ==========================================

export type VideoFormat = 'VERTICAL' | 'HORIZONTAL' | 'SQUARE';
export type VideoStatus = 'PENDING' | 'PROCESSING' | 'COMPLETED' | 'FAILED';
export type VideoQuality = 'LOW' | 'MEDIUM' | 'HIGH';
export type BackgroundStyle = 'simple' | 'professional' | 'creative' | 'minimalist';

export interface VideoDimensions {
  width: number;
  height: number;
}

export interface VideoMetadata {
  duration: number;
  width: number;
  height: number;
  fps: number;
  codec: string;
  bitrate?: number;
}

// ==========================================
// Job Queue Types
// ==========================================

export interface VideoJobData {
  videoId: string;
  userId: string;
  text: string;
  photoUrl?: string;
  avatarId?: string;
  backgroundStyle: BackgroundStyle;
  backgroundUrl?: string;
  voiceId: string;
  format: VideoFormat;
  quality?: VideoQuality;
}

export interface VideoJobResult {
  videoId: string;
  videoUrl: string;
  thumbnailUrl: string;
  duration: number;
  format: VideoFormat;
  quality: VideoQuality;
}

// ==========================================
// GPU Server Types
// ==========================================

export interface GPUHealthCheck {
  status: 'healthy' | 'degraded' | 'unhealthy';
  gpu?: {
    name: string;
    vram_total_gb: number;
    vram_used_gb: number;
    vram_free_gb: number;
    utilization_percent: number;
  };
  models: {
    musetalk: boolean;
    stable_diffusion: boolean;
    silero_tts: boolean;
  };
  mode?: 'GPU' | 'CPU';
  device?: string;
}

export interface TTSRequest {
  text: string;
  language: string;
  speaker: string;
}

export interface LipSyncRequest {
  imageBuffer: Buffer;
  audioBuffer: Buffer;
}

export interface BackgroundGenerationRequest {
  prompt: string;
  style: BackgroundStyle;
}

// ==========================================
// Storage Types
// ==========================================

export interface StorageUploadResult {
  url: string;
  key: string;
  bucket: string;
}

export interface StorageConfig {
  endpoint: string;
  accessKeyId: string;
  secretAccessKey: string;
  bucketName: string;
  region?: string;
}

// ==========================================
// API Response Types
// ==========================================

export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}

export interface VideoCreateResponse {
  videoId: string;
  status: VideoStatus;
  message: string;
}

export interface VideoStatusResponse {
  video: {
    id: string;
    status: VideoStatus;
    progress: number | null;
    text: string;
    videoUrl: string | null;
    thumbnailUrl: string | null;
    duration: number | null;
    format: VideoFormat;
    errorMessage: string | null;
    createdAt: Date;
    processedAt: Date | null;
  };
  job: any | null;
}

// ==========================================
// Error Types
// ==========================================

export interface ErrorContext {
  videoId?: string;
  userId?: string;
  operation?: string;
  [key: string]: any; // Allow any additional properties
}

export class AvatarFactoryError extends Error {
  constructor(
    message: string,
    public code: string,
    public statusCode: number = 500,
    public context?: ErrorContext
  ) {
    super(message);
    this.name = 'AvatarFactoryError';
    Object.setPrototypeOf(this, AvatarFactoryError.prototype);
  }
}

export class GPUServerError extends AvatarFactoryError {
  constructor(message: string, context?: ErrorContext) {
    super(message, 'GPU_SERVER_ERROR', 503, context);
    this.name = 'GPUServerError';
  }
}

export class StorageError extends AvatarFactoryError {
  constructor(message: string, context?: ErrorContext) {
    super(message, 'STORAGE_ERROR', 500, context);
    this.name = 'StorageError';
  }
}

export class ValidationError extends AvatarFactoryError {
  constructor(message: string, context?: ErrorContext) {
    super(message, 'VALIDATION_ERROR', 400, context);
    this.name = 'ValidationError';
  }
}

export class VideoProcessingError extends AvatarFactoryError {
  constructor(message: string, context?: ErrorContext) {
    super(message, 'VIDEO_PROCESSING_ERROR', 500, context);
    this.name = 'VideoProcessingError';
  }
}
