/**
 * GPU Server Client
 * Клиент для взаимодействия с GPU сервером на стационарном ПК
 */

import axios, { AxiosInstance, AxiosError } from 'axios';
import FormData from 'form-data';
import * as fs from 'fs';
import { Readable } from 'stream';
import { ENV } from './config';
import { logger } from './logger';
import { 
  GPUServerError, 
  ValidationError,
  type GPUHealthCheck,
  type TTSRequest,
  type LipSyncRequest,
  type BackgroundGenerationRequest 
} from './types';

class GPUServerClient {
  private client: AxiosInstance;
  private readonly baseURL: string;
  
  constructor(baseURL?: string) {
    this.baseURL = baseURL || ENV.GPU_SERVER_URL;
    this.client = axios.create({
      baseURL: this.baseURL,
      timeout: ENV.GPU_TIMEOUT_MS,
      headers: {
        'X-API-Key': ENV.GPU_API_KEY,
      },
    });

    // Request interceptor для логирования
    this.client.interceptors.request.use(
      (config) => {
        logger.gpuRequest(config.url || 'unknown', {
          method: config.method?.toUpperCase(),
          url: config.url,
        });
        return config;
      },
      (error) => {
        logger.gpuError('Request setup failed', error);
        return Promise.reject(error);
      }
    );

    // Response interceptor для обработки ошибок
    this.client.interceptors.response.use(
      (response) => response,
      (error: AxiosError) => {
        return Promise.reject(this.handleError(error));
      }
    );
  }

  private handleError(error: AxiosError): GPUServerError {
    const operation = error.config?.url || 'unknown operation';
    
    if (error.code === 'ECONNREFUSED' || error.code === 'ETIMEDOUT') {
      const message = `GPU Server unavailable at ${this.baseURL}`;
      logger.gpuError(operation, error, { baseURL: this.baseURL });
      return new GPUServerError(message, { operation });
    }

    if (error.response) {
      const status = error.response.status;
      const data = error.response.data as any;
      const detail = data?.detail || data?.message || 'Unknown error';
      
      const message = `GPU Server error (${status}): ${detail}`;
      logger.gpuError(operation, error, { status, detail });
      return new GPUServerError(message, { operation, status, detail });
    }

    const message = `GPU Server request failed: ${error.message}`;
    logger.gpuError(operation, error);
    return new GPUServerError(message, { operation });
  }
  
  /**
   * Проверка здоровья GPU сервера
   */
  async checkHealth(): Promise<GPUHealthCheck> {
    try {
      const response = await this.client.get<GPUHealthCheck>('/health');
      logger.info('GPU Server health check', { 
        status: response.data.status,
        mode: response.data.mode,
      });
      return response.data;
    } catch (error) {
      throw error instanceof GPUServerError 
        ? error 
        : new GPUServerError('Health check failed', { operation: 'health' });
    }
  }
  
  /**
   * Генерация аудио из текста (Silero TTS)
   */
  async textToSpeech(
    text: string,
    speaker: string = 'xenia',
    language: string = 'ru'
  ): Promise<Buffer> {
    // Validation
    if (!text || text.trim().length === 0) {
      throw new ValidationError('Text cannot be empty', { operation: 'tts' });
    }

    if (text.length > 5000) {
      throw new ValidationError('Text too long (max 5000 chars)', { 
        operation: 'tts',
        length: text.length 
      });
    }

    try {
      logger.info('TTS generation started', { 
        textLength: text.length,
        speaker,
        language 
      });

      // GPU server expects query parameters, not FormData
      const response = await this.client.post(
        '/api/tts',
        null,
        {
          params: {
            text: text.trim(),
            speaker: speaker,
          },
          responseType: 'arraybuffer',
        }
      );
      
      const buffer = Buffer.from(response.data);
      logger.info('TTS generation completed', { 
        audioSize: buffer.length,
        speaker 
      });

      return buffer;
    } catch (error) {
      // Error уже обработан в interceptor
      throw error;
    }
  }
  
  /**
   * Создание говорящего аватара (MuseTalk lip-sync)
   */
  async createLipSync(
    imagePath: string,
    audioPath: string
  ): Promise<Buffer> {
    // Validation
    if (!fs.existsSync(imagePath)) {
      throw new ValidationError(`Image file not found: ${imagePath}`, { 
        operation: 'lipsync',
        imagePath 
      });
    }

    if (!fs.existsSync(audioPath)) {
      throw new ValidationError(`Audio file not found: ${audioPath}`, { 
        operation: 'lipsync',
        audioPath 
      });
    }

    try {
      const formData = new FormData();
      formData.append('image', fs.createReadStream(imagePath));
      formData.append('audio', fs.createReadStream(audioPath));
      
      logger.info('Lip-sync generation started', { 
        imagePath: imagePath.split('/').pop(),
        audioPath: audioPath.split('/').pop() 
      });

      const response = await this.client.post(
        '/api/lipsync',
        formData,
        {
          headers: formData.getHeaders(),
          responseType: 'arraybuffer',
          maxContentLength: Infinity,
          maxBodyLength: Infinity,
        }
      );
      
      const buffer = Buffer.from(response.data);
      logger.info('Lip-sync generation completed', { 
        videoSize: buffer.length 
      });

      return buffer;
    } catch (error) {
      throw error;
    }
  }
  
  /**
   * Генерация фона (Stable Diffusion XL)
   */
  async generateBackground(
    prompt: string,
    style: string = 'professional',
    width: number = 1080,
    height: number = 1920
  ): Promise<Buffer> {
    // Validation
    if (!prompt || prompt.trim().length === 0) {
      throw new ValidationError('Prompt cannot be empty', { operation: 'background' });
    }

    if (prompt.length > 1000) {
      throw new ValidationError('Prompt too long (max 1000 chars)', { 
        operation: 'background',
        length: prompt.length 
      });
    }

    try {
      logger.info('Background generation started', { 
        promptLength: prompt.length,
        style,
        dimensions: `${width}x${height}` 
      });

      // GPU server expects query parameters for simple values
      const response = await this.client.post(
        '/api/generate-background',
        null,
        {
          params: {
            prompt: prompt.trim(),
            negative_prompt: "blurry, low quality, distorted",
            width,
            height,
          },
          responseType: 'arraybuffer',
        }
      );
      
      const buffer = Buffer.from(response.data);
      logger.info('Background generation completed', { 
        imageSize: buffer.length 
      });

      return buffer;
    } catch (error) {
      throw error;
    }
  }
  
  /**
   * Очистка временных файлов на GPU сервере
   */
  async cleanup(): Promise<void> {
    try {
      await this.client.post('/api/cleanup');
      logger.info('GPU server cleanup completed');
    } catch (error) {
      logger.warn('GPU server cleanup failed', { error: (error as Error).message });
      // Не бросаем ошибку - cleanup не критичен
    }
  }
}

// Singleton instance
export const gpuClient = new GPUServerClient();

// Вспомогательные функции

/**
 * Проверка доступности GPU сервера
 */
export async function isGPUServerAvailable(): Promise<boolean> {
  try {
    const health = await gpuClient.checkHealth();
    return health.status === 'healthy';
  } catch (error) {
    return false;
  }
}

/**
 * Получение метрик GPU
 */
export async function getGPUMetrics() {
  try {
    const health = await gpuClient.checkHealth();
    return {
      available: true,
      ...health.gpu,
      models: health.models,
    };
  } catch (error) {
    return {
      available: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}

/**
 * Ожидание доступности GPU сервера с retry
 */
export async function waitForGPUServer(
  maxRetries: number = 10,
  delayMs: number = 5000
): Promise<boolean> {
  for (let i = 0; i < maxRetries; i++) {
    const available = await isGPUServerAvailable();
    
    if (available) {
      console.log(`✅ GPU Server is ready`);
      return true;
    }
    
    console.log(`⏳ Waiting for GPU Server... (${i + 1}/${maxRetries})`);
    await new Promise(resolve => setTimeout(resolve, delayMs));
  }
  
  console.error(`❌ GPU Server unavailable after ${maxRetries} retries`);
  return false;
}
