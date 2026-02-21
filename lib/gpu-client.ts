/**
 * GPU Server Client
 * Клиент для взаимодействия с GPU сервером на стационарном ПК
 */

import axios, { AxiosInstance } from 'axios';
import FormData from 'form-data';
import fs from 'fs';
import { Readable } from 'stream';

const GPU_SERVER_URL = process.env.GPU_SERVER_URL || 'http://localhost:8001';
const GPU_API_KEY = process.env.GPU_API_KEY || 'your-secret-gpu-key-change-this';

class GPUServerClient {
  private client: AxiosInstance;
  
  constructor() {
    this.client = axios.create({
      baseURL: GPU_SERVER_URL,
      timeout: 300000, // 5 минут для генерации
      headers: {
        'X-API-Key': GPU_API_KEY,
      },
    });
  }
  
  /**
   * Проверка здоровья GPU сервера
   */
  async checkHealth(): Promise<{
    status: string;
    gpu: {
      name: string;
      vram_total_gb: number;
      vram_used_gb: number;
      vram_free_gb: number;
      utilization_percent: number;
    };
    models: {
      sadtalker: boolean;
      stable_diffusion: boolean;
      silero_tts: boolean;
    };
  }> {
    try {
      const response = await this.client.get('/health');
      return response.data;
    } catch (error) {
      throw new Error(`GPU Server unavailable: ${error}`);
    }
  }
  
  /**
   * Генерация аудио из текста (Silero TTS)
   */
  async textToSpeech(
    text: string,
    speaker: string = 'xenia'
  ): Promise<Buffer> {
    try {
      const formData = new FormData();
      formData.append('text', text);
      formData.append('language', 'ru');
      formData.append('speaker', speaker);
      
      const response = await this.client.post(
        '/api/tts',
        formData,
        {
          headers: formData.getHeaders(),
          responseType: 'arraybuffer',
        }
      );
      
      return Buffer.from(response.data);
    } catch (error: any) {
      throw new Error(`TTS generation failed: ${error.response?.data || error.message}`);
    }
  }
  
  /**
   * Создание говорящего аватара (SadTalker lip-sync)
   */
  async createLipSync(
    imagePath: string,
    audioPath: string
  ): Promise<Buffer> {
    try {
      const formData = new FormData();
      formData.append('image', fs.createReadStream(imagePath));
      formData.append('audio', fs.createReadStream(audioPath));
      
      const response = await this.client.post(
        '/api/lipsync',
        formData,
        {
          headers: formData.getHeaders(),
          responseType: 'arraybuffer',
        }
      );
      
      return Buffer.from(response.data);
    } catch (error: any) {
      throw new Error(`Lip-sync generation failed: ${error.response?.data || error.message}`);
    }
  }
  
  /**
   * Генерация фона (Stable Diffusion XL)
   */
  async generateBackground(
    prompt: string,
    width: number = 1080,
    height: number = 1920,
    negativePrompt?: string
  ): Promise<Buffer> {
    try {
      const formData = new FormData();
      formData.append('prompt', prompt);
      formData.append('style', 'photorealistic');
      
      const response = await this.client.post(
        '/api/generate-background',
        formData,
        {
          headers: formData.getHeaders(),
          responseType: 'arraybuffer',
        }
      );
      
      return Buffer.from(response.data);
    } catch (error: any) {
      throw new Error(`Background generation failed: ${error.response?.data || error.message}`);
    }
  }
  
  /**
   * Очистка временных файлов на GPU сервере
   */
  async cleanup(): Promise<void> {
    try {
      await this.client.post('/api/cleanup');
    } catch (error: any) {
      console.warn(`Cleanup failed: ${error.message}`);
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
