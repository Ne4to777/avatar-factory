/**
 * Complete API Test Suite
 * Tests all endpoints with real data
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const API_URL = 'http://localhost:3000';
const GPU_URL = 'http://192.168.1.100:8001';
const GPU_API_KEY = 'your-secret-gpu-key-change-this';

// Colors for console output
const colors = {
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  reset: '\x1b[0m',
};

function log(message: string, color: keyof typeof colors = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

// Test 1: Next.js Health
async function testNextHealth() {
  log('\n[1/6] Testing Next.js Health...', 'blue');
  
  try {
    const response = await fetch(`${API_URL}/api/health`, {
      signal: AbortSignal.timeout(5000)
    });
    const data = await response.json();
    
    log(`✓ Next.js server: ${response.status}`, 'green');
    console.log(JSON.stringify(data, null, 2));
    return true;
  } catch (error: any) {
    log(`✗ Next.js server failed: ${error.message}`, 'red');
    return false;
  }
}

// Test 2: GPU Worker Health
async function testGPUHealth() {
  log('\n[2/6] Testing GPU Worker Health...', 'blue');
  
  try {
    const response = await fetch(`${GPU_URL}/health`, {
      signal: AbortSignal.timeout(5000)
    });
    const data = await response.json();
    
    log(`✓ GPU Worker: ${response.status}`, 'green');
    log(`  GPU: ${data.gpu?.name}`, 'green');
    log(`  VRAM: ${data.gpu?.vram_used_gb}/${data.gpu?.vram_total_gb} GB`, 'green');
    log(`  Models:`, 'green');
    log(`    - MuseTalk: ${data.models?.musetalk ? '✓' : '✗'}`, data.models?.musetalk ? 'green' : 'red');
    log(`    - SDXL: ${data.models?.stable_diffusion ? '✓' : '✗'}`, data.models?.stable_diffusion ? 'green' : 'red');
    log(`    - TTS: ${data.models?.silero_tts ? '✓' : '✗'}`, data.models?.silero_tts ? 'green' : 'red');
    
    return data.models?.musetalk && data.models?.stable_diffusion && data.models?.silero_tts;
  } catch (error: any) {
    log(`✗ GPU Worker failed: ${error.message}`, 'red');
    return false;
  }
}

// Test 3: Create test image
function createTestImage(): Buffer {
  log('\n[3/6] Creating test image...', 'blue');
  
  // Create a simple 512x512 PNG with a circle
  const { createCanvas } = require('canvas');
  const canvas = createCanvas(512, 512);
  const ctx = canvas.getContext('2d');
  
  // Gradient background
  const gradient = ctx.createLinearGradient(0, 0, 512, 512);
  gradient.addColorStop(0, '#667eea');
  gradient.addColorStop(1, '#764ba2');
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, 512, 512);
  
  // White circle (face placeholder)
  ctx.fillStyle = 'white';
  ctx.beginPath();
  ctx.arc(256, 256, 150, 0, Math.PI * 2);
  ctx.fill();
  
  // Eyes
  ctx.fillStyle = 'black';
  ctx.beginPath();
  ctx.arc(220, 230, 20, 0, Math.PI * 2);
  ctx.arc(292, 230, 20, 0, Math.PI * 2);
  ctx.fill();
  
  // Smile
  ctx.strokeStyle = 'black';
  ctx.lineWidth = 5;
  ctx.beginPath();
  ctx.arc(256, 256, 80, 0, Math.PI, false);
  ctx.stroke();
  
  const buffer = canvas.toBuffer('image/png');
  log(`✓ Test image created: ${buffer.length} bytes`, 'green');
  
  return buffer;
}

// Test 4: Upload test image
async function testUpload(imageBuffer: Buffer): Promise<string | null> {
  log('\n[4/6] Testing file upload...', 'blue');
  
  try {
    const FormData = (await import('form-data')).default;
    const formData = new FormData();
    formData.append('file', imageBuffer, 'test-avatar.png');
    formData.append('type', 'avatar');
    
    const response = await fetch(`${API_URL}/api/upload`, {
      method: 'POST',
      body: formData as any,
      signal: AbortSignal.timeout(30000)
    });
    
    const data = await response.json();
    
    if (response.ok) {
      log(`✓ Upload successful: ${response.status}`, 'green');
      log(`  URL: ${data.url}`, 'green');
      return data.url;
    } else {
      log(`✗ Upload failed: ${data.error || data.message}`, 'red');
      console.log(data);
      return null;
    }
  } catch (error: any) {
    log(`✗ Upload error: ${error.message}`, 'red');
    return null;
  }
}

// Test 5: Create video
async function testCreateVideo(photoUrl: string): Promise<string | null> {
  log('\n[5/6] Testing video creation...', 'blue');
  
  try {
    const response = await fetch(`${API_URL}/api/videos/create`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        text: 'Привет! Это тестовое видео из Avatar Factory.',
        photoUrl,
        backgroundStyle: 'professional',
        format: 'VERTICAL',
        voiceId: 'ru_speaker_female',
      }),
      signal: AbortSignal.timeout(30000)
    });
    
    const data = await response.json();
    
    if (response.ok) {
      log(`✓ Video job created: ${response.status}`, 'green');
      log(`  Video ID: ${data.videoId}`, 'green');
      log(`  Status: ${data.status}`, 'green');
      return data.videoId;
    } else {
      log(`✗ Create video failed: ${data.error}`, 'red');
      console.log(data);
      return null;
    }
  } catch (error: any) {
    log(`✗ Create video error: ${error.message}`, 'red');
    return null;
  }
}

// Test 6: Check video status
async function testVideoStatus(videoId: string) {
  log('\n[6/6] Testing video status...', 'blue');
  
  try {
    const response = await fetch(`${API_URL}/api/videos/${videoId}`, {
      signal: AbortSignal.timeout(5000)
    });
    
    const data = await response.json();
    
    if (response.ok) {
      log(`✓ Video status: ${data.video.status}`, 'green');
      log(`  Progress: ${data.video.progress}%`, 'green');
      
      if (data.video.status === 'COMPLETED') {
        log(`  Video URL: ${data.video.videoUrl}`, 'green');
      }
      
      return data.video;
    } else {
      log(`✗ Status check failed`, 'red');
      return null;
    }
  } catch (error: any) {
    log(`✗ Status check error: ${error.message}`, 'red');
    return null;
  }
}

// Main test runner
async function runTests() {
  log('='.repeat(60), 'blue');
  log('Avatar Factory - Complete API Test', 'blue');
  log('='.repeat(60), 'blue');
  
  // Test infrastructure
  const nextOk = await testNextHealth();
  const gpuOk = await testGPUHealth();
  
  if (!nextOk) {
    log('\n✗ Next.js server not available. Start it with: npm run dev', 'red');
    process.exit(1);
  }
  
  if (!gpuOk) {
    log('\n⚠ GPU Worker not fully available, but continuing...', 'yellow');
  }
  
  // Test upload flow
  const imageBuffer = createTestImage();
  const photoUrl = await testUpload(imageBuffer);
  
  if (!photoUrl) {
    log('\n✗ Upload failed. Cannot continue.', 'red');
    process.exit(1);
  }
  
  // Test video creation
  const videoId = await testCreateVideo(photoUrl);
  
  if (!videoId) {
    log('\n✗ Video creation failed.', 'red');
    process.exit(1);
  }
  
  // Check initial status
  const video = await testVideoStatus(videoId);
  
  // Summary
  log('\n' + '='.repeat(60), 'blue');
  log('Test Summary', 'blue');
  log('='.repeat(60), 'blue');
  log(`Next.js server: ${nextOk ? '✓' : '✗'}`, nextOk ? 'green' : 'red');
  log(`GPU Worker: ${gpuOk ? '✓' : '✗'}`, gpuOk ? 'green' : 'red');
  log(`File upload: ${photoUrl ? '✓' : '✗'}`, photoUrl ? 'green' : 'red');
  log(`Video creation: ${videoId ? '✓' : '✗'}`, videoId ? 'green' : 'red');
  log('='.repeat(60), 'blue');
  
  if (videoId) {
    log(`\nMonitor video: ${API_URL}/api/videos/${videoId}`, 'yellow');
    log(`Video will be processed by worker in background.`, 'yellow');
  }
}

runTests().catch(console.error);
