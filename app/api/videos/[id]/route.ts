/**
 * API Route: Get Video Status / Delete Video
 * GET /api/videos/:id
 * DELETE /api/videos/:id
 */

import { NextRequest, NextResponse } from 'next/server';
import { VideoService } from '@/lib/services/video.service';

export async function GET(
  _req: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const videoService = new VideoService();
    const status = await videoService.getVideoStatus(params.id);

    return NextResponse.json({
      success: true,
      data: status,
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    if (message.includes('not found')) {
      return NextResponse.json({ error: 'Video not found' }, { status: 404 });
    }
    return NextResponse.json(
      { error: 'Internal server error', message },
      { status: 500 }
    );
  }
}

export async function DELETE(
  _req: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const videoService = new VideoService();
    await videoService.deleteVideo(params.id);

    return NextResponse.json({
      success: true,
      data: { message: 'Video deleted successfully' },
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    if (message.includes('not found')) {
      return NextResponse.json({ error: 'Video not found' }, { status: 404 });
    }
    return NextResponse.json(
      { error: 'Internal server error', message },
      { status: 500 }
    );
  }
}
