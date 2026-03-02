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
import { uploadVideo, uploadThumbnail } from '../lib/storage';
import { logger } from '../lib/logger';
import type { VideoJobData, VideoJobResult } from '../lib/queue';
import type { VideoFormat } from '../lib/types';

const connection = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379'),
  maxRetriesPerRequest: null,
});

const TEMP_DIR = process.env.TEMP_DIR || '/tmp/avatar-factory';

async function generateAudio(
  text: string,
  voiceId: string,
  videoId: string
): Promise<{ audioPath: string }> {
  const audioBuffer = await gpuClient.textToSpeech(text, getSpeakerFromVoiceId(voiceId));
  const audioPath = path.join(TEMP_DIR, `audio_${videoId}.wav`);
  await fs.writeFile(audioPath, audioBuffer);
  return { audioPath };
}

async function getAvatarImagePath(
  avatarId?: string,
  photoUrl?: string
): Promise<string> {
  if (!avatarId && !photoUrl) {
    throw new Error('Either avatarId or photoUrl must be provided');
  }

  if (avatarId) {
    const avatar = await prisma.avatar.findUnique({
      where: { id: avatarId },
    });
    if (!avatar) throw new Error(`Avatar ${avatarId} not found`);
    return downloadFile(avatar.photoUrl);
  }

  return downloadFile(photoUrl!);
}

async function getBackgroundPath(
  backgroundUrl: string | undefined,
  style: string,
  format: VideoFormat,
  videoId: string
): Promise<string> {
  if (backgroundUrl) {
    return downloadFile(backgroundUrl);
  }

  const prompt = getBackgroundPrompt(style);
  const dimensions = getBackgroundDimensions(format);
  const backgroundBuffer = await gpuClient.generateBackground(
    prompt,
    style,
    dimensions.width,
    dimensions.height
  );
  const backgroundPath = path.join(TEMP_DIR, `bg_${videoId}.png`);
  await fs.writeFile(backgroundPath, backgroundBuffer);
  return backgroundPath;
}

async function generateLipSyncVideo(
  avatarImagePath: string,
  audioPath: string,
  videoId: string,
  job: Job<VideoJobData>
): Promise<string> {
  await job.updateProgress({ progress: 40, stage: 'lip-sync' });

  const lipSyncBuffer = await gpuClient.createLipSync(avatarImagePath, audioPath);
  const lipSyncVideoPath = path.join(TEMP_DIR, `lipsync_${videoId}.mp4`);
  await fs.writeFile(lipSyncVideoPath, lipSyncBuffer);

  await fs.unlink(avatarImagePath).catch(() => {});
  await fs.unlink(audioPath).catch(() => {});

  await job.updateProgress({ progress: 60, stage: 'lip-sync' });
  return lipSyncVideoPath;
}

async function composeAndUploadVideo(
  lipSyncVideoPath: string,
  backgroundPath: string,
  format: VideoFormat,
  text: string,
  videoId: string,
  job: Job<VideoJobData>
): Promise<{ finalVideoUrl: string; thumbnailUrl: string; duration: number }> {
  await job.updateProgress({ progress: 75, stage: 'compositing' });

  const finalVideoPath = await composeVideo({
    avatarVideoPath: lipSyncVideoPath,
    backgroundImagePath: backgroundPath,
    format,
    subtitlesText: text.length < 150 ? text : undefined,
  });

  await job.updateProgress({ progress: 90, stage: 'thumbnail' });

  const thumbnailPath = await generateThumbnail(finalVideoPath);

  await job.updateProgress({ progress: 93, stage: 'upload' });

  const [videoUpload, thumbnailUpload] = await Promise.all([
    uploadVideo(finalVideoPath),
    uploadThumbnail(thumbnailPath),
  ]);

  const videoInfo = await getVideoInfo(finalVideoPath);

  await cleanupTempFiles([
    lipSyncVideoPath,
    backgroundPath,
    finalVideoPath,
    thumbnailPath,
  ]);

  return {
    finalVideoUrl: videoUpload.publicUrl,
    thumbnailUrl: thumbnailUpload.publicUrl,
    duration: Math.round(videoInfo.duration),
  };
}

/**
 * Главный Worker для обработки видео
 */
const worker = new Worker<VideoJobData, VideoJobResult>(
  'video-generation',
  async (job: Job<VideoJobData>) => {
    const { videoId, userId, text, photoUrl, avatarId, backgroundStyle, backgroundUrl, voiceId, format } = job.data;

    logger.videoProcessing(videoId, 'Started processing video', { userId });

    try {
      await updateVideoStatus(videoId, 'PROCESSING', 0);

      // Step 1: Generate audio (0–20%)
      await job.updateProgress({ progress: 10, stage: 'tts' });
      const { audioPath } = await generateAudio(text, voiceId, videoId);
      await updateVideoStatus(videoId, 'PROCESSING', 20);

      // Step 2: Get avatar image (20–35%)
      await job.updateProgress({ progress: 30, stage: 'avatar' });
      const avatarImagePath = await getAvatarImagePath(avatarId, photoUrl);
      await updateVideoStatus(videoId, 'PROCESSING', 35);

      // Step 3: Get or generate background (35–60%)
      await job.updateProgress({ progress: 65, stage: 'background' });
      const backgroundPath = await getBackgroundPath(
        backgroundUrl,
        backgroundStyle,
        format,
        videoId
      );
      await updateVideoStatus(videoId, 'PROCESSING', 70);

      // Step 4: Create lip-sync video (40–60%)
      const lipSyncVideoPath = await generateLipSyncVideo(
        avatarImagePath,
        audioPath,
        videoId,
        job
      );

      // Step 5: Compose and upload (60–100%)
      const { finalVideoUrl, thumbnailUrl, duration } = await composeAndUploadVideo(
        lipSyncVideoPath,
        backgroundPath,
        format,
        text,
        videoId,
        job
      );

      await job.updateProgress({ progress: 97, stage: 'complete' });

      await prisma.video.update({
        where: { id: videoId },
        data: {
          status: 'COMPLETED',
          progress: 100,
          videoUrl: finalVideoUrl,
          thumbnailUrl,
          duration,
          processedAt: new Date(),
        },
      });

      logger.videoProcessing(videoId, 'Video processed successfully');

      return {
        videoId,
        videoUrl: finalVideoUrl,
        thumbnailUrl,
        duration,
        format,
        quality: 'MEDIUM',
      };
    } catch (error: unknown) {
      logger.videoError(videoId, error);

      await prisma.video.update({
        where: { id: videoId },
        data: {
          status: 'FAILED',
          errorMessage: error instanceof Error ? error.message : 'Unknown error',
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
