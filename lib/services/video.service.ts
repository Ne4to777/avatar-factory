import { prisma } from '../prisma';
import { addVideoJob, getJobStatus } from '../queue';
import { deleteByUrl } from '../storage';
import { logger } from '../logger';
import type { Video, VideoStatus } from '@prisma/client';

export interface CreateVideoInput {
  userId: string;
  text: string;
  voiceId: string;
  backgroundStyle: 'simple' | 'professional' | 'creative' | 'minimalist';
  avatarId?: string;
  photoUrl?: string;
  backgroundUrl?: string;
  format: 'VERTICAL' | 'HORIZONTAL' | 'SQUARE';
}

export interface VideoStatusResult {
  id: string;
  status: VideoStatus;
  progress: number;
  videoUrl: string | null;
  thumbnailUrl: string | null;
  error: string | null;
}

export class VideoService {
  async createVideo(input: CreateVideoInput): Promise<Video> {
    logger.info('Creating video', { userId: input.userId });

    const video = await prisma.video.create({
      data: {
        userId: input.userId,
        text: input.text,
        voiceId: input.voiceId,
        backgroundStyle: input.backgroundStyle,
        avatarId: input.avatarId,
        photoUrl: input.photoUrl,
        backgroundUrl: input.backgroundUrl,
        format: input.format,
        status: 'PENDING',
        progress: 0,
      },
    });

    await addVideoJob({
      videoId: video.id,
      userId: input.userId,
      text: input.text,
      voiceId: input.voiceId,
      backgroundStyle: input.backgroundStyle,
      avatarId: input.avatarId,
      photoUrl: input.photoUrl,
      backgroundUrl: input.backgroundUrl,
      format: input.format,
    });

    logger.info('Video created and queued', { videoId: video.id });
    return video;
  }

  async getVideoStatus(videoId: string): Promise<VideoStatusResult> {
    const video = await prisma.video.findUnique({
      where: { id: videoId },
    });

    if (!video) {
      throw new Error(`Video ${videoId} not found`);
    }

    let progress = video.progress;
    if (video.status === 'PROCESSING') {
      const jobStatus = await getJobStatus(videoId);
      if (jobStatus) {
        progress = jobStatus.progress ?? progress;
      }
    }

    return {
      id: video.id,
      status: video.status,
      progress,
      videoUrl: video.videoUrl,
      thumbnailUrl: video.thumbnailUrl,
      error: video.errorMessage,
    };
  }

  async deleteVideo(videoId: string): Promise<void> {
    const video = await prisma.video.findUnique({
      where: { id: videoId },
    });

    if (!video) {
      throw new Error(`Video ${videoId} not found`);
    }

    if (video.videoUrl) {
      await deleteByUrl(video.videoUrl);
    }
    if (video.thumbnailUrl) {
      await deleteByUrl(video.thumbnailUrl);
    }

    await prisma.video.delete({
      where: { id: videoId },
    });

    logger.info('Video deleted', { videoId });
  }
}
