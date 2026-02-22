/**
 * BullMQ Queue Configuration
 * Управление очередью задач для генерации видео
 */

import { Queue, QueueEvents, Job } from 'bullmq';
import Redis from 'ioredis';
import { ENV, QUEUE_CONFIG } from './config';
import { logger } from './logger';
import type { VideoJobData, VideoJobResult } from './types';

const connection = new Redis({
  host: ENV.REDIS_HOST,
  port: ENV.REDIS_PORT,
  maxRetriesPerRequest: null,
});

// Экспортируем типы из types.ts
export type { VideoJobData, VideoJobResult } from './types';

// Очередь для генерации видео
export const videoQueue = new Queue<VideoJobData, VideoJobResult>(
  QUEUE_CONFIG.VIDEO_GENERATION.name,
  {
    connection,
    defaultJobOptions: {
      attempts: QUEUE_CONFIG.VIDEO_GENERATION.maxRetries,
      backoff: QUEUE_CONFIG.VIDEO_GENERATION.backoff,
      removeOnComplete: {
        age: 24 * 3600, // 24 часа
        count: 100,
      },
      removeOnFail: {
        age: 7 * 24 * 3600, // 7 дней
      },
    },
  }
);

// События очереди
export const videoQueueEvents = new QueueEvents(
  QUEUE_CONFIG.VIDEO_GENERATION.name,
  { connection }
);

// Отслеживание прогресса с typed data
videoQueueEvents.on('progress', ({ jobId, data }) => {
  const progress = typeof data === 'object' && 'progress' in data ? data.progress : data;
  logger.info('Job progress updated', { jobId, progress });
});

videoQueueEvents.on('completed', ({ jobId }) => {
  logger.info('Job completed', { jobId });
});

videoQueueEvents.on('failed', ({ jobId, failedReason }) => {
  logger.error('Job failed', new Error(failedReason || 'Unknown error'), { jobId });
});

// ==========================================
// Queue Operations
// ==========================================

/**
 * Добавление задачи генерации видео в очередь
 */
export async function addVideoJob(
  data: VideoJobData,
  priority: number = QUEUE_CONFIG.DEFAULT_PRIORITY
): Promise<Job<VideoJobData, VideoJobResult>> {
  try {
    logger.info('Adding video job to queue', { 
      videoId: data.videoId,
      userId: data.userId,
      textLength: data.text.length,
      format: data.format,
      priority
    });

    const job = await videoQueue.add('generate-video', data, {
      jobId: data.videoId,
      priority,
    });
    
    return job;
  } catch (error: any) {
    logger.error('Failed to add video job', error, { videoId: data.videoId });
    throw error;
  }
}

/**
 * Получение статуса задачи
 */
export async function getJobStatus(jobId: string) {
  try {
    const job = await videoQueue.getJob(jobId);
    
    if (!job) {
      return null;
    }
    
    const state = await job.getState();
    const progress = typeof job.progress === 'object' 
      ? (job.progress as any).progress 
      : job.progress;
    
    return {
      id: job.id,
      state,
      progress,
      data: job.data,
      returnvalue: job.returnvalue,
      failedReason: job.failedReason,
      timestamp: job.timestamp,
      processedOn: job.processedOn,
      finishedOn: job.finishedOn,
    };
  } catch (error: any) {
    logger.error('Failed to get job status', error, { jobId });
    return null;
  }
}

/**
 * Получение метрик очереди
 */
export async function getQueueMetrics() {
  try {
    const [waiting, active, completed, failed, delayed] = await Promise.all([
      videoQueue.getWaitingCount(),
      videoQueue.getActiveCount(),
      videoQueue.getCompletedCount(),
      videoQueue.getFailedCount(),
      videoQueue.getDelayedCount(),
    ]);
    
    const metrics = {
      waiting,
      active,
      completed,
      failed,
      delayed,
      total: waiting + active + completed + failed + delayed,
    };

    logger.debug('Queue metrics', metrics);
    
    return metrics;
  } catch (error: any) {
    logger.error('Failed to get queue metrics', error);
    throw error;
  }
}

/**
 * Очистка завершенных задач
 */
export async function cleanCompletedJobs(olderThanMs: number = 24 * 3600 * 1000) {
  try {
    const jobs = await videoQueue.clean(olderThanMs, 100, 'completed');
    logger.info('Cleaned completed jobs', { count: jobs.length });
    return jobs;
  } catch (error: any) {
    logger.error('Failed to clean completed jobs', error);
    throw error;
  }
}

/**
 * Очистка failed задач
 */
export async function cleanFailedJobs(olderThanMs: number = 7 * 24 * 3600 * 1000) {
  try {
    const jobs = await videoQueue.clean(olderThanMs, 100, 'failed');
    logger.info('Cleaned failed jobs', { count: jobs.length });
    return jobs;
  } catch (error: any) {
    logger.error('Failed to clean failed jobs', error);
    throw error;
  }
}
