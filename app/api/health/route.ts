/**
 * API Route: System Health Check
 * GET /api/health
 */

import { NextRequest, NextResponse } from 'next/server';
import { ListBucketsCommand } from '@aws-sdk/client-s3';
import { prisma } from '@/lib/prisma';
import { getGPUMetrics } from '@/lib/gpu-client';
import { getQueueMetrics } from '@/lib/queue';
import { createS3Client } from '@/lib/storage';
import { logger } from '@/lib/logger';
import Redis from 'ioredis';

const redis = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379'),
});

async function checkStorage(): Promise<boolean> {
  try {
    const s3 = createS3Client();
    const result = await s3.send(new ListBucketsCommand({}));
    return result.Buckets !== undefined;
  } catch (error) {
    logger.error('Storage health check failed', { error });
    return false;
  }
}

export async function GET(req: NextRequest) {
  try {
    const checks = {
      database: false,
      redis: false,
      gpu: false,
      storage: false,
    };
    
    const metrics: any = {
      timestamp: new Date().toISOString(),
    };
    
    // 1. Проверка базы данных
    try {
      await prisma.$queryRaw`SELECT 1`;
      checks.database = true;
    } catch (error) {
      console.error('Database check failed:', error);
    }
    
    // 2. Проверка Redis
    try {
      await redis.ping();
      checks.redis = true;
      
      // Получаем метрики очереди
      const queueMetrics = await getQueueMetrics();
      metrics.queue = queueMetrics;
    } catch (error) {
      console.error('Redis check failed:', error);
    }
    
    // 3. Проверка GPU сервера
    try {
      const gpuMetrics = await getGPUMetrics();
      checks.gpu = gpuMetrics.available;
      metrics.gpu = gpuMetrics;
    } catch (error) {
      console.error('GPU check failed:', error);
      metrics.gpu = { available: false, error: 'Unable to reach GPU server' };
    }
    
    // 4. Проверка хранилища (MinIO/S3)
    checks.storage = await checkStorage();
    
    // Подсчет общей статистики
    const stats = await prisma.video.groupBy({
      by: ['status'],
      _count: true,
    });
    
    metrics.videos = {
      total: stats.reduce((sum, s) => sum + s._count, 0),
      byStatus: stats.reduce((acc, s) => {
        acc[s.status] = s._count;
        return acc;
      }, {} as Record<string, number>),
    };
    
    // Общий статус
    const allHealthy = Object.values(checks).every(check => check);
    const status = allHealthy ? 'healthy' : 'degraded';
    
    return NextResponse.json({
      status,
      checks,
      metrics,
      version: '1.0.0',
    });
    
  } catch (error: any) {
    console.error('Health check error:', error);
    return NextResponse.json(
      {
        status: 'error',
        error: error.message,
      },
      { status: 500 }
    );
  }
}
