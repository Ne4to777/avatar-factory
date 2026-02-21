/**
 * BullMQ Queue Configuration
 * Управление очередью задач для генерации видео
 */

import { Queue, QueueEvents } from 'bullmq';
import Redis from 'ioredis';

const connection = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379'),
  maxRetriesPerRequest: null,
});

// Интерфейсы для задач
export interface VideoJobData {
  videoId: string;
  userId: string;
  text: string;
  photoUrl?: string;
  avatarId?: string;
  backgroundStyle: string;
  backgroundUrl?: string;
  voiceId: string;
  format: 'VERTICAL' | 'HORIZONTAL' | 'SQUARE';
}

export interface VideoJobResult {
  videoUrl: string;
  thumbnailUrl: string;
  duration: number;
}

// Очередь для генерации видео
export const videoQueue = new Queue<VideoJobData, VideoJobResult>('video-generation', {
  connection,
  defaultJobOptions: {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 5000,
    },
    removeOnComplete: {
      age: 24 * 3600, // 24 часа
      count: 100,
    },
    removeOnFail: {
      age: 7 * 24 * 3600, // 7 дней
    },
  },
});

// События очереди
export const videoQueueEvents = new QueueEvents('video-generation', { connection });

// Отслеживание прогресса
videoQueueEvents.on('progress', ({ jobId, data }) => {
  console.log(`📊 Job ${jobId} progress: ${data.progress}%`);
});

videoQueueEvents.on('completed', ({ jobId }) => {
  console.log(`✅ Job ${jobId} completed`);
});

videoQueueEvents.on('failed', ({ jobId, failedReason }) => {
  console.error(`❌ Job ${jobId} failed: ${failedReason}`);
});

// Вспомогательные функции
export async function addVideoJob(data: VideoJobData) {
  const job = await videoQueue.add('generate-video', data, {
    jobId: data.videoId,
  });
  
  return job;
}

export async function getJobStatus(jobId: string) {
  const job = await videoQueue.getJob(jobId);
  
  if (!job) {
    return null;
  }
  
  const state = await job.getState();
  const progress = job.progress;
  
  return {
    id: job.id,
    state,
    progress,
    data: job.data,
    returnvalue: job.returnvalue,
    failedReason: job.failedReason,
  };
}

export async function getQueueMetrics() {
  const [waiting, active, completed, failed, delayed] = await Promise.all([
    videoQueue.getWaitingCount(),
    videoQueue.getActiveCount(),
    videoQueue.getCompletedCount(),
    videoQueue.getFailedCount(),
    videoQueue.getDelayedCount(),
  ]);
  
  return {
    waiting,
    active,
    completed,
    failed,
    delayed,
    total: waiting + active + completed + failed + delayed,
  };
}
