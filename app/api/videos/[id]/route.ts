/**
 * API Route: Get Video Status
 * GET /api/videos/:id
 */

import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getJobStatus } from '@/lib/queue';
import { deleteByUrl } from '@/lib/storage';

export async function GET(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const videoId = params.id;
    
    // Получаем видео из БД
    const video = await prisma.video.findUnique({
      where: { id: videoId },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            email: true,
          },
        },
        avatar: {
          select: {
            id: true,
            name: true,
            photoUrl: true,
          },
        },
      },
    });
    
    if (!video) {
      return NextResponse.json(
        { error: 'Video not found' },
        { status: 404 }
      );
    }
    
    // Если видео все еще обрабатывается, получаем статус из очереди
    let jobStatus = null;
    if (video.status === 'PENDING' || video.status === 'PROCESSING') {
      jobStatus = await getJobStatus(videoId);
    }
    
    return NextResponse.json({
      video: {
        id: video.id,
        status: video.status,
        progress: video.progress,
        text: video.text,
        videoUrl: video.videoUrl,
        thumbnailUrl: video.thumbnailUrl,
        duration: video.duration,
        format: video.format,
        errorMessage: video.errorMessage,
        createdAt: video.createdAt,
        processedAt: video.processedAt,
        user: video.user,
        avatar: video.avatar,
      },
      job: jobStatus,
    });
    
  } catch (error: any) {
    console.error('Get video error:', error);
    return NextResponse.json(
      { error: 'Internal server error', message: error.message },
      { status: 500 }
    );
  }
}

export async function DELETE(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const videoId = params.id;
    
    // Получаем видео
    const video = await prisma.video.findUnique({
      where: { id: videoId },
    });
    
    if (!video) {
      return NextResponse.json(
        { error: 'Video not found' },
        { status: 404 }
      );
    }
    
    // TODO: Проверка прав доступа (userId === video.userId)
    
    // Удаляем файлы из хранилища
    if (video.videoUrl) {
      await deleteByUrl(video.videoUrl);
    }
    
    if (video.thumbnailUrl) {
      await deleteByUrl(video.thumbnailUrl);
    }
    
    // Удаляем из БД
    await prisma.video.delete({
      where: { id: videoId },
    });
    
    return NextResponse.json({
      success: true,
      message: 'Video deleted',
    });
    
  } catch (error: any) {
    console.error('Delete video error:', error);
    return NextResponse.json(
      { error: 'Internal server error', message: error.message },
      { status: 500 }
    );
  }
}
