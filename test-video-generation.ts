/**
 * Test video generation with minimal settings
 * Tests the full workflow: upload image -> create video -> check status
 */

import axios from 'axios';
import FormData from 'form-data';
import fs from 'fs';
import path from 'path';

const API_URL = 'http://localhost:3000';
const POLL_INTERVAL = 2000; // 2 seconds
const MAX_WAIT_TIME = 120000; // 2 minutes

// Создаем минимальное тестовое изображение (1x1 красный пиксель PNG)
function createTestImage(): Buffer {
  // Минимальный PNG (красный пиксель 1x1)
  const pngData = Buffer.from([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,  // PNG signature
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,  // IHDR chunk
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,  // 1x1 pixels
    0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
    0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,  // IDAT chunk (red pixel)
    0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
    0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D,
    0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,  // IEND chunk
    0x44, 0xAE, 0x42, 0x60, 0x82
  ]);
  
  return pngData;
}

async function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function testVideoGeneration() {
  console.log('============================================================');
  console.log('🎬 Avatar Factory - Video Generation Test');
  console.log('============================================================\n');

  try {
    // 1. Health check
    console.log('1️⃣  Checking system health...');
    const healthRes = await axios.get(`${API_URL}/api/health`);
    console.log(`✅ System healthy: ${healthRes.data.status}`);
    console.log(`   - Database: ${healthRes.data.checks.database}`);
    console.log(`   - Redis: ${healthRes.data.checks.redis}`);
    console.log(`   - GPU: ${healthRes.data.checks.gpu}`);
    console.log(`   - Storage: ${healthRes.data.checks.storage}\n`);

    // 2. Upload avatar image
    console.log('2️⃣  Uploading avatar image...');
    const imageBuffer = createTestImage();
    const uploadForm = new FormData();
    uploadForm.append('file', imageBuffer, {
      filename: 'test-avatar.png',
      contentType: 'image/png'
    });

    const uploadRes = await axios.post(
      `${API_URL}/api/upload`,
      uploadForm,
      {
        headers: uploadForm.getHeaders()
      }
    );

    const avatarUrl = uploadRes.data.url;
    console.log(`✅ Avatar uploaded: ${avatarUrl}\n`);

    // 3. Create video with minimal settings
    console.log('3️⃣  Creating video (minimal settings)...');
    const createRes = await axios.post(`${API_URL}/api/videos/create`, {
      photoUrl: avatarUrl,
      text: 'Test', // Минимальный текст
      backgroundStyle: 'simple',
      voiceId: 'ru_speaker_female',
      format: 'VERTICAL'
    });

    const videoId = createRes.data.videoId;
    console.log(`✅ Video job created: ${videoId}`);
    console.log(`   Status: ${createRes.data.status}\n`);

    // 4. Poll video status
    console.log('4️⃣  Waiting for video generation...');
    console.log('   (Polling every 2 seconds, max 2 minutes)\n');

    const startTime = Date.now();
    let lastStatus = '';

    while (Date.now() - startTime < MAX_WAIT_TIME) {
      const statusRes = await axios.get(`${API_URL}/api/videos/${videoId}`);
      const video = statusRes.data;

      if (video.status !== lastStatus) {
        const elapsed = Math.round((Date.now() - startTime) / 1000);
        console.log(`   [${elapsed}s] Status: ${video.status}`);
        if (video.error) {
          console.log(`   ❌ Error: ${video.error}`);
        }
        if (video.progress) {
          console.log(`   Progress: ${video.progress}%`);
        }
        lastStatus = video.status;
      }

      if (video.status === 'COMPLETED') {
        console.log(`\n✅ VIDEO GENERATED SUCCESSFULLY!`);
        console.log(`   Video URL: ${video.videoUrl}`);
        console.log(`   Thumbnail: ${video.thumbnailUrl}`);
        console.log(`   Duration: ${video.duration}s`);
        console.log(`   Format: ${video.format}`);
        console.log(`   Quality: ${video.quality}\n`);
        return true;
      }

      if (video.status === 'FAILED') {
        console.log(`\n❌ VIDEO GENERATION FAILED`);
        console.log(`   Error: ${video.error}\n`);
        return false;
      }

      await sleep(POLL_INTERVAL);
    }

    console.log(`\n⏱️  Timeout: Video generation took too long (>${MAX_WAIT_TIME/1000}s)\n`);
    return false;

  } catch (error: any) {
    console.error('\n❌ Test failed with error:');
    if (error.response) {
      console.error(`   Status: ${error.response.status}`);
      console.error(`   Data:`, error.response.data);
    } else {
      console.error(`   ${error.message}`);
    }
    console.error();
    return false;
  }
}

// Run test
testVideoGeneration().then(success => {
  console.log('============================================================');
  console.log(success ? '🎉 Test PASSED' : '💥 Test FAILED');
  console.log('============================================================');
  process.exit(success ? 0 : 1);
});
