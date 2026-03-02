/**
 * Video Generation Worker
 * Обрабатывает задачи генерации видео из очереди BullMQ
 */

import { Worker, Job } from 'bullmq';
import { promises as fs } from 'fs';
import path from 'path';
import axios from 'axios';
import Redis from 'ioredis';
import { prisma } from '../lib/prisma';
import { gpuClient } from '../lib/gpu-client';
import {
  BACKGROUND_STYLE_MAP,
  BACKGROUND_PROMPTS,
  getSpeakerFromVoiceId,
  getBackgroundDimensions,
} from '../lib/config';
import { composeVideo, generateThumbnail, getVideoInfo, ensureTempDir } from '../lib/video';
import { uploadVideo, uploadThumbnail, deleteFile } from '../lib/storage';
import type { VideoJobData, VideoJobResult } from '../lib/queue';

const connection = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379'),
  maxRetriesPerRequest: null,
});

const TEMP_DIR = process.env.TEMP_DIR || '/tmp/avatar-factory';

/**
 * Главный Worker для обработки видео
 */
const worker = new Worker<VideoJobData, VideoJobResult>(
  'video-generation',
  async (job: Job<VideoJobData>) => {
    const { videoId, userId, text, photoUrl, avatarId, backgroundStyle, backgroundUrl, voiceId, format } = job.data;
    
    console.log(`\n🎬 Starting video generation: ${videoId}`);
    console.log(`   User: ${userId}`);
    console.log(`   Text: ${text.substring(0, 50)}...`);
    
    try {
      // Обновляем статус в БД
      await updateVideoStatus(videoId, 'PROCESSING', 0);
      
      // 1️⃣ ГЕНЕРАЦИЯ АУДИО (TTS)
      console.log('\n1️⃣ Generating audio...');
      await job.updateProgress({ progress: 10 });
      
      const audioBuffer = await gpuClient.textToSpeech(text, getSpeakerFromVoiceId(voiceId));
      const audioPath = path.join(TEMP_DIR, `audio_${videoId}.wav`);
      await fs.writeFile(audioPath, audioBuffer);
      
      console.log(`✅ Audio generated: ${audioPath}`);
      await updateVideoStatus(videoId, 'PROCESSING', 20);
      
      // 2️⃣ ПОЛУЧЕНИЕ ФОТО АВАТАРА
      console.log('\n2️⃣ Getting avatar photo...');
      await job.updateProgress({ progress: 30 });
      
      let avatarPhotoPath: string;
      
      if (avatarId) {
        // Используем существующий аватар
        const avatar = await prisma.avatar.findUnique({
          where: { id: avatarId },
        });
        
        if (!avatar) {
          throw new Error(`Avatar ${avatarId} not found`);
        }
        
        avatarPhotoPath = await downloadFile(avatar.photoUrl);
      } else if (photoUrl) {
        // Используем загруженное фото
        avatarPhotoPath = await downloadFile(photoUrl);
      } else {
        throw new Error('No avatar or photo provided');
      }
      
      console.log(`✅ Avatar photo ready: ${avatarPhotoPath}`);
      await updateVideoStatus(videoId, 'PROCESSING', 35);
      
      // 3️⃣ СОЗДАНИЕ ГОВОРЯЩЕГО АВАТАРА (LIP-SYNC)
      console.log('\n3️⃣ Creating talking avatar (lip-sync)...');
      await job.updateProgress({ progress: 40 });
      
      const lipSyncBuffer = await gpuClient.createLipSync(avatarPhotoPath, audioPath);
      const lipSyncVideoPath = path.join(TEMP_DIR, `lipsync_${videoId}.mp4`);
      await fs.writeFile(lipSyncVideoPath, lipSyncBuffer);
      
      console.log(`✅ Lip-sync video created: ${lipSyncVideoPath}`);
      await updateVideoStatus(videoId, 'PROCESSING', 60);
      
      // 4️⃣ ПОЛУЧЕНИЕ ИЛИ ГЕНЕРАЦИЯ ФОНА
      console.log('\n4️⃣ Getting background...');
      await job.updateProgress({ progress: 65 });
      
      let backgroundPath: string;
      
      if (backgroundUrl) {
        // Используем существующий фон
        backgroundPath = await downloadFile(backgroundUrl);
      } else {
        // Генерируем новый фон через Stable Diffusion
        const dimensions = getBackgroundDimensions(format);
        const prompt = getBackgroundPrompt(backgroundStyle);
        
        console.log(`   Generating background: ${prompt}`);
        const backgroundBuffer = await gpuClient.generateBackground(
          prompt,
          backgroundStyle,
          dimensions.width,
          dimensions.height
        );
        
        backgroundPath = path.join(TEMP_DIR, `bg_${videoId}.png`);
        await fs.writeFile(backgroundPath, backgroundBuffer);
      }
      
      console.log(`✅ Background ready: ${backgroundPath}`);
      await updateVideoStatus(videoId, 'PROCESSING', 70);
      
      // 5️⃣ КОМПОЗИТИНГ ФИНАЛЬНОГО ВИДЕО
      console.log('\n5️⃣ Composing final video...');
      await job.updateProgress({ progress: 75 });
      
      const finalVideoPath = await composeVideo({
        avatarVideoPath: lipSyncVideoPath,
        backgroundImagePath: backgroundPath,
        format,
        subtitlesText: text.length < 150 ? text : undefined, // Субтитры только для коротких текстов
      });
      
      console.log(`✅ Final video composed: ${finalVideoPath}`);
      await updateVideoStatus(videoId, 'PROCESSING', 85);
      
      // 6️⃣ СОЗДАНИЕ THUMBNAIL
      console.log('\n6️⃣ Generating thumbnail...');
      await job.updateProgress({ progress: 90 });
      
      const thumbnailPath = await generateThumbnail(finalVideoPath);
      console.log(`✅ Thumbnail created: ${thumbnailPath}`);
      
      // 7️⃣ ЗАГРУЗКА В ХРАНИЛИЩЕ
      console.log('\n7️⃣ Uploading to storage...');
      await job.updateProgress({ progress: 93 });
      
      const [videoUpload, thumbnailUpload] = await Promise.all([
        uploadVideo(finalVideoPath),
        uploadThumbnail(thumbnailPath),
      ]);
      
      console.log(`✅ Video uploaded: ${videoUpload.publicUrl}`);
      console.log(`✅ Thumbnail uploaded: ${thumbnailUpload.publicUrl}`);
      
      // 8️⃣ ПОЛУЧЕНИЕ МЕТАДАННЫХ ВИДЕО
      const videoInfo = await getVideoInfo(finalVideoPath);
      
      // 9️⃣ ОБНОВЛЕНИЕ БД
      console.log('\n9️⃣ Updating database...');
      await job.updateProgress({ progress: 97 });
      
      await prisma.video.update({
        where: { id: videoId },
        data: {
          status: 'COMPLETED',
          progress: 100,
          videoUrl: videoUpload.publicUrl,
          thumbnailUrl: thumbnailUpload.publicUrl,
          duration: Math.round(videoInfo.duration),
          processedAt: new Date(),
        },
      });
      
      // 🧹 ОЧИСТКА ВРЕМЕННЫХ ФАЙЛОВ
      console.log('\n🧹 Cleaning up temp files...');
      await cleanupTempFiles([
        audioPath,
        avatarPhotoPath,
        lipSyncVideoPath,
        backgroundPath,
        finalVideoPath,
        thumbnailPath,
      ]);
      
      console.log(`\n✅ Video generation completed: ${videoId}`);
      console.log(`   URL: ${videoUpload.publicUrl}\n`);
      
      return {
        videoId,
        videoUrl: videoUpload.publicUrl,
        thumbnailUrl: thumbnailUpload.publicUrl,
        duration: Math.round(videoInfo.duration),
        format,
        quality: 'MEDIUM',
      };
      
    } catch (error: any) {
      console.error(`\n❌ Video generation failed: ${videoId}`);
      console.error(error);
      
      // Обновляем статус ошибки в БД
      await prisma.video.update({
        where: { id: videoId },
        data: {
          status: 'FAILED',
          errorMessage: error.message || 'Unknown error',
        },
      });
      
      throw error;
    }
  },
  {
    connection,
    concurrency: 2, // Обрабатываем 2 видео параллельно
    limiter: {
      max: 10, // Максимум 10 задач
      duration: 60000, // за минуту
    },
  }
);

// Event handlers
worker.on('completed', (job) => {
  console.log(`✅ Job ${job.id} completed successfully`);
});

worker.on('failed', (job, err) => {
  console.error(`❌ Job ${job?.id} failed:`, err.message);
});

worker.on('error', (err) => {
  console.error('Worker error:', err);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, closing worker...');
  await worker.close();
  await connection.quit();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('SIGINT received, closing worker...');
  await worker.close();
  await connection.quit();
  process.exit(0);
});

// Helper functions

async function updateVideoStatus(
  videoId: string,
  status: 'PENDING' | 'PROCESSING' | 'COMPLETED' | 'FAILED',
  progress: number
) {
  await prisma.video.update({
    where: { id: videoId },
    data: { status, progress },
  });
}

async function downloadFile(url: string): Promise<string> {
  const response = await axios.get(url, {
    responseType: 'arraybuffer',
  });
  
  const ext = path.extname(url) || '.jpg';
  const tempPath = path.join(TEMP_DIR, `download_${Date.now()}${ext}`);
  await fs.writeFile(tempPath, Buffer.from(response.data));
  
  return tempPath;
}

function getBackgroundPrompt(styleAPI: string): string {
  const internalStyle = BACKGROUND_STYLE_MAP[styleAPI as keyof typeof BACKGROUND_STYLE_MAP];
  return BACKGROUND_PROMPTS[internalStyle] || BACKGROUND_PROMPTS['modern-office'];
}

async function cleanupTempFiles(filePaths: string[]) {
  for (const filePath of filePaths) {
    try {
      await fs.unlink(filePath);
      console.log(`   🗑️  Deleted: ${path.basename(filePath)}`);
    } catch (error) {
      // Игнорируем ошибки при удалении
    }
  }
}

// Инициализация
(async () => {
  await ensureTempDir();
  console.log('🚀 Video Worker started');
  console.log(`   Concurrency: 2`);
  console.log(`   Temp dir: ${TEMP_DIR}`);
  console.log(`   Waiting for jobs...\n`);
})();
