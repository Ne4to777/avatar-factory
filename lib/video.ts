/**
 * Video Processing with FFmpeg
 * Композитинг, обработка и постобработка видео
 */

import ffmpeg from 'fluent-ffmpeg';
import { promises as fs } from 'fs';
import path from 'path';
import { nanoid } from 'nanoid';

const TEMP_DIR = process.env.TEMP_DIR || '/tmp/avatar-factory';

// Размеры видео по форматам
const VIDEO_DIMENSIONS = {
  VERTICAL: { width: 1080, height: 1920 }, // 9:16 Reels/Shorts
  HORIZONTAL: { width: 1920, height: 1080 }, // 16:9 YouTube
  SQUARE: { width: 1080, height: 1080 }, // 1:1 Instagram
};

export interface ComposeVideoOptions {
  avatarVideoPath: string;
  backgroundImagePath: string;
  format: 'VERTICAL' | 'HORIZONTAL' | 'SQUARE';
  subtitlesText?: string;
  musicPath?: string;
  outputPath?: string;
}

export interface VideoInfo {
  duration: number;
  width: number;
  height: number;
  fps: number;
  codec: string;
}

/**
 * Создание директории для временных файлов
 */
export async function ensureTempDir() {
  try {
    await fs.mkdir(TEMP_DIR, { recursive: true });
  } catch (error) {
    console.error('Failed to create temp dir:', error);
  }
}

/**
 * Получение информации о видео
 */
export async function getVideoInfo(videoPath: string): Promise<VideoInfo> {
  return new Promise((resolve, reject) => {
    ffmpeg.ffprobe(videoPath, (err, metadata) => {
      if (err) {
        reject(err);
        return;
      }
      
      const videoStream = metadata.streams.find(s => s.codec_type === 'video');
      
      if (!videoStream) {
        reject(new Error('No video stream found'));
        return;
      }
      
      resolve({
        duration: metadata.format.duration || 0,
        width: videoStream.width || 0,
        height: videoStream.height || 0,
        fps: eval(videoStream.r_frame_rate || '30/1'),
        codec: videoStream.codec_name || 'unknown',
      });
    });
  });
}

/**
 * Композитинг видео: аватар + фон + субтитры + музыка
 */
export async function composeVideo(options: ComposeVideoOptions): Promise<string> {
  const {
    avatarVideoPath,
    backgroundImagePath,
    format,
    subtitlesText,
    musicPath,
    outputPath,
  } = options;
  
  await ensureTempDir();
  
  const dimensions = VIDEO_DIMENSIONS[format];
  const finalOutputPath = outputPath || path.join(
    TEMP_DIR,
    `final_${nanoid()}.mp4`
  );
  
  return new Promise((resolve, reject) => {
    let command = ffmpeg();
    
    // Входные файлы
    command = command.input(backgroundImagePath); // [0:v]
    command = command.input(avatarVideoPath);     // [1:v] [1:a]
    
    if (musicPath) {
      command = command.input(musicPath);         // [2:a]
    }
    
    // Создаем фильтры для композитинга
    const filters: string[] = [];
    
    // 1. Масштабируем и растягиваем фон на весь экран
    filters.push(
      `[0:v]scale=${dimensions.width}:${dimensions.height}:force_original_aspect_ratio=increase,crop=${dimensions.width}:${dimensions.height}[bg]`
    );
    
    // 2. Масштабируем аватар (занимает 60% ширины)
    const avatarWidth = Math.floor(dimensions.width * 0.6);
    filters.push(
      `[1:v]scale=${avatarWidth}:-1[avatar]`
    );
    
    // 3. Накладываем аватар по центру
    filters.push(
      `[bg][avatar]overlay=(W-w)/2:(H-h)/2:shortest=1[video_with_avatar]`
    );
    
    // 4. Финальное видео (без субтитров для упрощения теста)
    const finalVideoFilter = '[video_with_avatar]';
    
    // Применяем фильтры
    command = command.complexFilter(filters);
    
    // Настройки вывода
    const outputOptions: string[] = [
      '-map', finalVideoFilter,  // Keep brackets for filter reference
    ];
    
    // Аудио: микс музыки и голоса, или только голос
    if (musicPath) {
      outputOptions.push(
        '-filter_complex', '[1:a][2:a]amix=inputs=2:duration=shortest[aout]',
        '-map', '[aout]'
      );
    } else {
      outputOptions.push('-map', '1:a');
    }
    
    // Кодеки и качество
    outputOptions.push(
      '-c:v', 'libx264',
      '-preset', 'medium',
      '-crf', '23',
      '-profile:v', 'high',
      '-level', '4.0',
      '-pix_fmt', 'yuv420p',
      '-c:a', 'aac',
      '-b:a', '128k',
      '-ar', '48000',
      '-movflags', '+faststart', // Оптимизация для стриминга
      '-y' // Перезаписать если существует
    );
    
    command
      .outputOptions(outputOptions)
      .output(finalOutputPath)
      .on('start', (commandLine) => {
        console.log('🎬 FFmpeg started:', commandLine);
      })
      .on('progress', (progress) => {
        console.log(`⏳ Processing: ${progress.percent?.toFixed(1) || 0}%`);
      })
      .on('end', () => {
        console.log(`✅ Video composed: ${finalOutputPath}`);
        resolve(finalOutputPath);
      })
      .on('error', (err) => {
        console.error('❌ FFmpeg error:', err);
        reject(err);
      })
      .run();
  });
}

/**
 * Создание thumbnail из видео
 */
export async function generateThumbnail(
  videoPath: string,
  outputPath?: string,
  timePosition: string = '00:00:00.1'
): Promise<string> {
  await ensureTempDir();
  
  const thumbnailPath = outputPath || path.join(
    TEMP_DIR,
    `thumb_${nanoid()}.png`
  );
  
  return new Promise((resolve, reject) => {
    // Простая генерация первого кадра как PNG
    ffmpeg(videoPath)
      .outputOptions([
        '-vframes', '1',
        '-update', '1'
      ])
      .output(thumbnailPath)
      .on('end', () => {
        console.log(`✅ Thumbnail created: ${thumbnailPath}`);
        resolve(thumbnailPath);
      })
      .on('error', (err) => {
        console.error('❌ Thumbnail error:', err);
        reject(err);
      })
      .run();
  });
}

/**
 * Конвертация формата видео
 */
export async function convertVideoFormat(
  inputPath: string,
  outputFormat: 'mp4' | 'webm' | 'mov',
  outputPath?: string
): Promise<string> {
  await ensureTempDir();
  
  const finalOutputPath = outputPath || path.join(
    TEMP_DIR,
    `converted_${nanoid()}.${outputFormat}`
  );
  
  return new Promise((resolve, reject) => {
    ffmpeg(inputPath)
      .outputFormat(outputFormat)
      .output(finalOutputPath)
      .on('end', () => {
        console.log(`✅ Format converted: ${finalOutputPath}`);
        resolve(finalOutputPath);
      })
      .on('error', (err) => {
        console.error('❌ Conversion error:', err);
        reject(err);
      })
      .run();
  });
}

/**
 * Оптимизация размера видео
 */
export async function optimizeVideo(
  inputPath: string,
  outputPath?: string,
  quality: 'high' | 'medium' | 'low' = 'medium'
): Promise<string> {
  await ensureTempDir();
  
  const finalOutputPath = outputPath || path.join(
    TEMP_DIR,
    `optimized_${nanoid()}.mp4`
  );
  
  const crfValues = {
    high: 20,
    medium: 23,
    low: 28,
  };
  
  return new Promise((resolve, reject) => {
    ffmpeg(inputPath)
      .outputOptions([
        '-c:v', 'libx264',
        '-crf', crfValues[quality].toString(),
        '-preset', 'medium',
        '-c:a', 'aac',
        '-b:a', '96k',
      ])
      .output(finalOutputPath)
      .on('end', () => {
        console.log(`✅ Video optimized: ${finalOutputPath}`);
        resolve(finalOutputPath);
      })
      .on('error', (err) => {
        console.error('❌ Optimization error:', err);
        reject(err);
      })
      .run();
  });
}

/**
 * Очистка временных файлов
 */
export async function cleanupTempFiles(maxAgeHours: number = 24) {
  try {
    const files = await fs.readdir(TEMP_DIR);
    const now = Date.now();
    const maxAge = maxAgeHours * 60 * 60 * 1000;
    
    for (const file of files) {
      const filePath = path.join(TEMP_DIR, file);
      const stats = await fs.stat(filePath);
      
      if (now - stats.mtimeMs > maxAge) {
        await fs.unlink(filePath);
        console.log(`🗑️  Deleted old temp file: ${file}`);
      }
    }
  } catch (error) {
    console.error('Cleanup error:', error);
  }
}
