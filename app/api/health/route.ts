/**
 * API Route: System Health Check
 * GET /api/health
 */

import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getGPUMetrics } from '@/lib/gpu-client';
import { getQueueMetrics } from '@/lib/queue';
import Redis from 'ioredis';

const redis = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379'),
});

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
    
    // 4. Проверка хранилища (MinIO)
    try {
      const { S3Client, ListBucketsCommand } = await import('@aws-sdk/client-s3');
      const s3Client = new S3Client({
        endpoint: `http://${process.env.MINIO_ENDPOINT || 'localhost'}:${process.env.MINIO_PORT || '9000'}`,
        region: 'us-east-1',
        credentials: {
          accessKeyId: process.env.MINIO_ACCESS_KEY || 'minioadmin',
          secretAccessKey: process.env.MINIO_SECRET_KEY || 'minioadmin123',
        },
        forcePathStyle: true,
      });
      
      await s3Client.send(new ListBucketsCommand({}));
      checks.storage = true;
    } catch (error) {
      console.error('Storage check failed:', error);
    }
    
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
