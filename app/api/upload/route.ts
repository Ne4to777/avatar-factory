/**
 * API Route: Upload File
 * POST /api/upload
 */

import { NextRequest, NextResponse } from 'next/server';
import { uploadBuffer, type StorageFolder } from '@/lib/storage';

const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB

export async function POST(req: NextRequest) {
  try {
    const formData = await req.formData();
    const file = formData.get('file') as File | null;
    const type = formData.get('type') as string || 'temp';
    
    if (!file) {
      return NextResponse.json(
        { error: 'No file provided' },
        { status: 400 }
      );
    }
    
    // Проверка размера
    if (file.size > MAX_FILE_SIZE) {
      return NextResponse.json(
        { error: `File too large. Max size is ${MAX_FILE_SIZE / 1024 / 1024}MB` },
        { status: 400 }
      );
    }
    
    // Проверка типа файла
    const allowedTypes = ['image/jpeg', 'image/png', 'image/webp', 'audio/mpeg', 'audio/wav'];
    if (!allowedTypes.includes(file.type)) {
      return NextResponse.json(
        { error: 'Invalid file type. Allowed: JPEG, PNG, WEBP, MP3, WAV' },
        { status: 400 }
      );
    }
    
    // Конвертируем в Buffer
    const bytes = await file.arrayBuffer();
    const buffer = Buffer.from(bytes);
    
    // Загружаем в хранилище
    const folder: StorageFolder = type === 'avatar' ? 'avatars' : type === 'background' ? 'backgrounds' : 'temp';
    const result = await uploadBuffer(buffer, file.name, folder);

    console.log(`✅ File uploaded: ${result.publicUrl}`);
    
    return NextResponse.json({
      success: true,
      url: result.publicUrl,
      key: result.key,
      size: file.size,
      type: file.type,
    });
    
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    console.error('Upload error:', error);
    return NextResponse.json(
      { error: 'Upload failed', message },
      { status: 500 }
    );
  }
}
