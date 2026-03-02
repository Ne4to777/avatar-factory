/**
 * API Route: Create Video
 * POST /api/videos/create
 */

import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { prisma } from '@/lib/prisma';
import { VideoService } from '@/lib/services/video.service';

const createVideoSchema = z.object({
  text: z.string().min(1).max(500),
  photoUrl: z.string().url().optional(),
  avatarId: z.string().optional(),
  backgroundStyle: z.enum(['simple', 'professional', 'creative', 'minimalist']).default('simple'),
  backgroundUrl: z.string().url().optional(),
  voiceId: z.string().default('ru_speaker_female'),
  format: z.enum(['VERTICAL', 'HORIZONTAL', 'SQUARE']).default('VERTICAL'),
});

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const validatedData = createVideoSchema.parse(body);

    // TODO: Get userId from auth session
    let userId = 'test-user-id';

    // Ensure test user exists
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

    if (!validatedData.photoUrl && !validatedData.avatarId) {
      return NextResponse.json(
        { error: 'Either photoUrl or avatarId must be provided' },
        { status: 400 }
      );
    }

    const videoService = new VideoService();
    const video = await videoService.createVideo({
      userId,
      ...validatedData,
    });

    return NextResponse.json({
      success: true,
      data: { videoId: video.id },
    });
  } catch (error: unknown) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { error: 'Invalid input', details: error.errors },
        { status: 400 }
      );
    }

    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json(
      { error: 'Internal server error', message },
      { status: 500 }
    );
  }
}
