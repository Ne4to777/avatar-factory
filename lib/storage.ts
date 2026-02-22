/**
 * Storage Client (MinIO / S3)
 * Загрузка и управление файлами в S3-compatible хранилище
 */

import { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { promises as fs } from 'fs';
import path from 'path';
import { nanoid } from 'nanoid';
import { ENV, STORAGE_CONFIG, STORAGE_PATHS } from './config';
import { logger } from './logger';
import { StorageError, ValidationError, type StorageUploadResult } from './types';

// S3 Client configuration
const s3Client = new S3Client({
  endpoint: STORAGE_CONFIG.endpoint,
  region: STORAGE_CONFIG.region || 'us-east-1',
  credentials: {
    accessKeyId: STORAGE_CONFIG.accessKeyId,
    secretAccessKey: STORAGE_CONFIG.secretAccessKey,
  },
  forcePathStyle: true, // Важно для MinIO
});

export type StorageFolder = 'videos' | 'thumbnails' | 'backgrounds' | 'avatars' | 'temp';

interface UploadResult extends StorageUploadResult {
  publicUrl: string;
}

/**
 * Загрузка файла из пути
 */
export async function uploadFile(
  filePath: string,
  folder: StorageFolder = 'temp',
  customKey?: string
): Promise<UploadResult> {
  // Validation
  if (!filePath || filePath.trim().length === 0) {
    throw new ValidationError('File path cannot be empty', { operation: 'upload' });
  }

  try {
    // Проверяем существование файла
    await fs.access(filePath);
    
    const fileBuffer = await fs.readFile(filePath);
    const ext = path.extname(filePath);
    const key = customKey || `${folder}/${nanoid()}${ext}`;
    
    return await uploadBuffer(fileBuffer, key);
    
  } catch (error: any) {
    if (error.code === 'ENOENT') {
      logger.storageError('upload', error, { filePath });
      throw new StorageError(`File not found: ${filePath}`, { operation: 'upload', filePath });
    }
    
    logger.storageError('upload', error, { filePath, folder });
    throw error instanceof StorageError 
      ? error 
      : new StorageError(`Failed to upload file: ${error.message}`, { operation: 'upload', filePath });
  }
}

/**
 * Загрузка из Buffer (основной метод)
 */
export async function uploadBuffer(
  buffer: Buffer,
  keyOrFilename: string,
  folder?: StorageFolder
): Promise<UploadResult> {
  // Validation
  if (!buffer || buffer.length === 0) {
    throw new ValidationError('Buffer cannot be empty', { operation: 'upload' });
  }

  try {
    // Определяем key
    const isFullKey = keyOrFilename.includes('/');
    const key = isFullKey 
      ? keyOrFilename 
      : `${folder || 'temp'}/${nanoid()}${path.extname(keyOrFilename)}`;
    
    const ext = path.extname(key);
    const contentType = getContentType(ext);
    
    logger.storageOperation('upload', { 
      key, 
      size: buffer.length,
      contentType 
    });

    const command = new PutObjectCommand({
      Bucket: STORAGE_CONFIG.bucketName,
      Key: key,
      Body: buffer,
      ContentType: contentType,
    });
    
    await s3Client.send(command);
    
    const publicUrl = `${ENV.S3_ENDPOINT}/${STORAGE_CONFIG.bucketName}/${key}`;
    
    logger.info('File uploaded', { key, size: buffer.length });
    
    return {
      url: publicUrl,
      key,
      bucket: STORAGE_CONFIG.bucketName,
      publicUrl,
    };
  } catch (error: any) {
    logger.storageError('upload', error, { size: buffer.length });
    throw new StorageError(`Failed to upload buffer: ${error.message}`, { 
      operation: 'upload',
      size: buffer.length 
    });
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
  if (!key || key.trim().length === 0) {
    throw new ValidationError('Key cannot be empty', { operation: 'getSignedUrl' });
  }

  try {
    const command = new GetObjectCommand({
      Bucket: STORAGE_CONFIG.bucketName,
      Key: key,
    });
    
    logger.storageOperation('getSignedUrl', { key, expiresIn });
    const signedUrl = await getSignedUrl(s3Client, command, { expiresIn });
    
    return signedUrl;
  } catch (error: any) {
    logger.storageError('getSignedUrl', error, { key });
    throw new StorageError(`Failed to generate signed URL: ${error.message}`, { 
      operation: 'getSignedUrl',
      key 
    });
  }
}

/**
 * Удаление файла
 */
export async function deleteFile(key: string): Promise<void> {
  if (!key || key.trim().length === 0) {
    throw new ValidationError('Key cannot be empty', { operation: 'delete' });
  }

  try {
    const command = new DeleteObjectCommand({
      Bucket: STORAGE_CONFIG.bucketName,
      Key: key,
    });
    
    await s3Client.send(command);
    logger.info('File deleted', { key });
  } catch (error: any) {
    logger.storageError('delete', error, { key });
    throw new StorageError(`Failed to delete file: ${error.message}`, { 
      operation: 'delete',
      key 
    });
  }
}

/**
 * Удаление по URL
 */
export async function deleteByUrl(url: string): Promise<void> {
  if (!url || url.trim().length === 0) {
    throw new ValidationError('URL cannot be empty', { operation: 'deleteByUrl' });
  }

  try {
    const urlObj = new URL(url);
    const pathParts = urlObj.pathname.split('/');
    const key = pathParts.slice(2).join('/'); // Убираем /bucket/
    
    if (!key) {
      throw new ValidationError('Invalid URL - cannot extract key', { 
        operation: 'deleteByUrl',
        url 
      });
    }
    
    await deleteFile(key);
  } catch (error: any) {
    if (error instanceof ValidationError || error instanceof StorageError) {
      throw error;
    }
    
    logger.storageError('deleteByUrl', error, { url });
    throw new StorageError(`Failed to delete file by URL: ${error.message}`, { 
      operation: 'deleteByUrl',
      url 
    });
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
  if (!key) return false;

  try {
    const command = new GetObjectCommand({
      Bucket: STORAGE_CONFIG.bucketName,
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
  if (!key) {
    throw new ValidationError('Key cannot be empty', { operation: 'getFileSize' });
  }

  try {
    const command = new GetObjectCommand({
      Bucket: STORAGE_CONFIG.bucketName,
      Key: key,
    });
    
    const response = await s3Client.send(command);
    return response.ContentLength || 0;
  } catch (error: any) {
    logger.warn('Failed to get file size', { key, error: error.message });
    return 0;
  }
}

/**
 * Копирование файла
 */
export async function copyFile(sourceKey: string, destKey: string): Promise<void> {
  if (!sourceKey || !destKey) {
    throw new ValidationError('Source and destination keys are required', { 
      operation: 'copy',
      sourceKey,
      destKey 
    });
  }

  try {
    logger.storageOperation('copy', { sourceKey, destKey });

    const getCommand = new GetObjectCommand({
      Bucket: STORAGE_CONFIG.bucketName,
      Key: sourceKey,
    });
    
    const response = await s3Client.send(getCommand);
    const body = await response.Body?.transformToByteArray();
    
    if (!body) {
      throw new StorageError('Failed to read source file', { 
        operation: 'copy',
        sourceKey 
      });
    }
    
    const putCommand = new PutObjectCommand({
      Bucket: STORAGE_CONFIG.bucketName,
      Key: destKey,
      Body: Buffer.from(body),
      ContentType: response.ContentType,
    });
    
    await s3Client.send(putCommand);
    logger.info('File copied', { sourceKey, destKey });
  } catch (error: any) {
    if (error instanceof StorageError) throw error;
    
    logger.storageError('copy', error, { sourceKey, destKey });
    throw new StorageError(`Failed to copy file: ${error.message}`, { 
      operation: 'copy',
      sourceKey,
      destKey 
    });
  }
}
