/**
 * Storage Client (MinIO / S3)
 * Загрузка и управление файлами в S3-compatible хранилище
 */

import { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { promises as fs } from 'fs';
import path from 'path';
import { nanoid } from 'nanoid';

const MINIO_ENDPOINT = process.env.MINIO_ENDPOINT || 'localhost';
const MINIO_PORT = process.env.MINIO_PORT || '9000';
const MINIO_ACCESS_KEY = process.env.MINIO_ACCESS_KEY || 'minioadmin';
const MINIO_SECRET_KEY = process.env.MINIO_SECRET_KEY || 'minioadmin123';
const MINIO_BUCKET = process.env.MINIO_BUCKET || 'avatar-videos';
const MINIO_USE_SSL = process.env.MINIO_USE_SSL === 'true';
const MINIO_PUBLIC_URL = process.env.MINIO_PUBLIC_URL || `http://${MINIO_ENDPOINT}:${MINIO_PORT}`;

// S3 Client configuration
const s3Client = new S3Client({
  endpoint: `${MINIO_USE_SSL ? 'https' : 'http'}://${MINIO_ENDPOINT}:${MINIO_PORT}`,
  region: 'us-east-1', // MinIO требует region, но значение не важно
  credentials: {
    accessKeyId: MINIO_ACCESS_KEY,
    secretAccessKey: MINIO_SECRET_KEY,
  },
  forcePathStyle: true, // Важно для MinIO
});

export interface UploadResult {
  url: string;
  key: string;
  bucket: string;
  publicUrl: string;
}

/**
 * Загрузка файла из пути
 */
export async function uploadFile(
  filePath: string,
  folder: 'videos' | 'thumbnails' | 'backgrounds' | 'avatars' | 'temp' = 'temp',
  customKey?: string
): Promise<UploadResult> {
  try {
    const fileBuffer = await fs.readFile(filePath);
    const ext = path.extname(filePath);
    const key = customKey || `${folder}/${nanoid()}${ext}`;
    
    const contentType = getContentType(ext);
    
    const command = new PutObjectCommand({
      Bucket: MINIO_BUCKET,
      Key: key,
      Body: fileBuffer,
      ContentType: contentType,
    });
    
    await s3Client.send(command);
    
    const publicUrl = `${MINIO_PUBLIC_URL}/${MINIO_BUCKET}/${key}`;
    
    console.log(`✅ Uploaded: ${publicUrl}`);
    
    return {
      url: publicUrl,
      key,
      bucket: MINIO_BUCKET,
      publicUrl,
    };
  } catch (error) {
    console.error('Upload error:', error);
    throw new Error(`Failed to upload file: ${error}`);
  }
}

/**
 * Загрузка из Buffer
 */
export async function uploadBuffer(
  buffer: Buffer,
  filename: string,
  folder: 'videos' | 'thumbnails' | 'backgrounds' | 'avatars' | 'temp' = 'temp'
): Promise<UploadResult> {
  try {
    const ext = path.extname(filename);
    const key = `${folder}/${nanoid()}${ext}`;
    const contentType = getContentType(ext);
    
    const command = new PutObjectCommand({
      Bucket: MINIO_BUCKET,
      Key: key,
      Body: buffer,
      ContentType: contentType,
    });
    
    await s3Client.send(command);
    
    const publicUrl = `${MINIO_PUBLIC_URL}/${MINIO_BUCKET}/${key}`;
    
    console.log(`✅ Uploaded buffer: ${publicUrl}`);
    
    return {
      url: publicUrl,
      key,
      bucket: MINIO_BUCKET,
      publicUrl,
    };
  } catch (error) {
    console.error('Upload buffer error:', error);
    throw new Error(`Failed to upload buffer: ${error}`);
  }
}

/**
 * Загрузка видео
 */
export async function uploadVideo(videoPath: string): Promise<UploadResult> {
  return uploadFile(videoPath, 'videos');
}

/**
 * Загрузка thumbnail
 */
export async function uploadThumbnail(thumbnailPath: string): Promise<UploadResult> {
  return uploadFile(thumbnailPath, 'thumbnails');
}

/**
 * Загрузка фона
 */
export async function uploadBackground(backgroundPath: string): Promise<UploadResult> {
  return uploadFile(backgroundPath, 'backgrounds');
}

/**
 * Загрузка аватара
 */
export async function uploadAvatar(avatarPath: string): Promise<UploadResult> {
  return uploadFile(avatarPath, 'avatars');
}

/**
 * Получение signed URL для приватных файлов
 */
export async function getSignedDownloadUrl(
  key: string,
  expiresIn: number = 3600
): Promise<string> {
  try {
    const command = new GetObjectCommand({
      Bucket: MINIO_BUCKET,
      Key: key,
    });
    
    const signedUrl = await getSignedUrl(s3Client, command, { expiresIn });
    return signedUrl;
  } catch (error) {
    console.error('Get signed URL error:', error);
    throw new Error(`Failed to generate signed URL: ${error}`);
  }
}

/**
 * Удаление файла
 */
export async function deleteFile(key: string): Promise<void> {
  try {
    const command = new DeleteObjectCommand({
      Bucket: MINIO_BUCKET,
      Key: key,
    });
    
    await s3Client.send(command);
    console.log(`🗑️  Deleted: ${key}`);
  } catch (error) {
    console.error('Delete error:', error);
    throw new Error(`Failed to delete file: ${error}`);
  }
}

/**
 * Удаление по URL
 */
export async function deleteByUrl(url: string): Promise<void> {
  try {
    // Извлекаем key из URL
    const urlObj = new URL(url);
    const pathParts = urlObj.pathname.split('/');
    const key = pathParts.slice(2).join('/'); // Убираем /bucket/
    
    await deleteFile(key);
  } catch (error) {
    console.error('Delete by URL error:', error);
    throw new Error(`Failed to delete file by URL: ${error}`);
  }
}

/**
 * Определение Content-Type по расширению
 */
function getContentType(ext: string): string {
  const contentTypes: Record<string, string> = {
    '.mp4': 'video/mp4',
    '.webm': 'video/webm',
    '.mov': 'video/quicktime',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    '.mp3': 'audio/mpeg',
    '.wav': 'audio/wav',
    '.ogg': 'audio/ogg',
  };
  
  return contentTypes[ext.toLowerCase()] || 'application/octet-stream';
}

/**
 * Проверка существования файла
 */
export async function fileExists(key: string): Promise<boolean> {
  try {
    const command = new GetObjectCommand({
      Bucket: MINIO_BUCKET,
      Key: key,
    });
    
    await s3Client.send(command);
    return true;
  } catch (error) {
    return false;
  }
}

/**
 * Получение размера файла
 */
export async function getFileSize(key: string): Promise<number> {
  try {
    const command = new GetObjectCommand({
      Bucket: MINIO_BUCKET,
      Key: key,
    });
    
    const response = await s3Client.send(command);
    return response.ContentLength || 0;
  } catch (error) {
    console.error('Get file size error:', error);
    return 0;
  }
}

/**
 * Копирование файла
 */
export async function copyFile(sourceKey: string, destKey: string): Promise<void> {
  try {
    // MinIO не поддерживает CopyObject напрямую через AWS SDK v3
    // Поэтому скачиваем и загружаем заново
    const getCommand = new GetObjectCommand({
      Bucket: MINIO_BUCKET,
      Key: sourceKey,
    });
    
    const response = await s3Client.send(getCommand);
    const body = await response.Body?.transformToByteArray();
    
    if (!body) {
      throw new Error('Failed to read source file');
    }
    
    const putCommand = new PutObjectCommand({
      Bucket: MINIO_BUCKET,
      Key: destKey,
      Body: Buffer.from(body),
      ContentType: response.ContentType,
    });
    
    await s3Client.send(putCommand);
    console.log(`📋 Copied: ${sourceKey} → ${destKey}`);
  } catch (error) {
    console.error('Copy file error:', error);
    throw new Error(`Failed to copy file: ${error}`);
  }
}
