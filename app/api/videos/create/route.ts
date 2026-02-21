/**
 * API Route: Create Video
 * POST /api/videos/create
 */

import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { prisma } from '@/lib/prisma';
import { addVideoJob } from '@/lib/queue';

const createVideoSchema = z.object({
  text: z.string().min(1).max(500),
  photoUrl: z.string().url().optional(),
  avatarId: z.string().optional(),
  backgroundStyle: z.string().default('modern-office'),
  backgroundUrl: z.string().url().optional(),
  voiceId: z.string().default('ru_speaker_female'),
  format: z.enum(['VERTICAL', 'HORIZONTAL', 'SQUARE']).default('VERTICAL'),
});

export async function POST(req: NextRequest) {
  try {
    // Парсинг и валидация входных данных
    const body = await req.json();
    const data = createVideoSchema.parse(body);
    
    // TODO: Получить userId из сессии (пока создаем тестового пользователя)
    let userId = 'test-user-id';
    
    // Создаем тестового пользователя если не существует
    const testUser = await prisma.user.upsert({
      where: { id: userId },
      update: {},
      create: {
        id: userId,
        email: 'test@avatar-factory.local',
        name: 'Test User',
      },
    });
    
    userId = testUser.id;
    
    // Проверка: должен быть либо photoUrl, либо avatarId
    if (!data.photoUrl && !data.avatarId) {
      return NextResponse.json(
        { error: 'Either photoUrl or avatarId must be provided' },
        { status: 400 }
      );
    }
    
    // Создаем запись в БД
    const video = await prisma.video.create({
      data: {
        userId,
        text: data.text,
        photoUrl: data.photoUrl,
        avatarId: data.avatarId,
        backgroundStyle: data.backgroundStyle,
        backgroundUrl: data.backgroundUrl,
        voiceId: data.voiceId,
        format: data.format,
        status: 'PENDING',
        progress: 0,
      },
    });
    
    // Добавляем задачу в очередь
    await addVideoJob({
      videoId: video.id,
      userId,
      text: data.text,
      photoUrl: data.photoUrl,
      avatarId: data.avatarId,
      backgroundStyle: data.backgroundStyle,
      backgroundUrl: data.backgroundUrl,
      voiceId: data.voiceId,
      format: data.format,
    });
    
    console.log(`✅ Video job created: ${video.id}`);
    
    return NextResponse.json({
      success: true,
      videoId: video.id,
      status: 'pending',
      message: 'Video generation started',
    });
    
  } catch (error: any) {
    console.error('Create video error:', error);
    
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { error: 'Invalid input', details: error.errors },
        { status: 400 }
      );
    }
    
    return NextResponse.json(
      { error: 'Internal server error', message: error.message },
      { status: 500 }
    );
  }
}
