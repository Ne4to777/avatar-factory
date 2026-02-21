/**
 * Basic System Test (без GPU)
 * Проверка базовой функциональности без AI моделей
 */

import { PrismaClient } from '@prisma/client';
import Redis from 'ioredis';

const prisma = new PrismaClient();

async function testDatabase() {
  console.log('\n🗄️  Testing Database Connection...');
  
  try {
    // Простой запрос
    await prisma.$queryRaw`SELECT 1 as test`;
    console.log('✅ Database: Connected');
    
    // Создаем тестового пользователя
    const user = await prisma.user.upsert({
      where: { email: 'test@example.com' },
      update: {},
      create: {
        email: 'test@example.com',
        name: 'Test User',
      },
    });
    
    console.log('✅ Database: User created:', user.id);
    
    // Создаем тестовое видео
    const video = await prisma.video.create({
      data: {
        userId: user.id,
        text: 'Это тестовое видео для проверки системы',
        voiceId: 'ru_speaker_female',
        backgroundStyle: 'modern-office',
        format: 'VERTICAL',
        status: 'PENDING',
        progress: 0,
      },
    });
    
    console.log('✅ Database: Video created:', video.id);
    
    // Проверяем получение видео
    const fetchedVideo = await prisma.video.findUnique({
      where: { id: video.id },
    });
    
    if (fetchedVideo) {
      console.log('✅ Database: Video fetched successfully');
    }
    
    return true;
  } catch (error) {
    console.error('❌ Database test failed:', error);
    return false;
  }
}

async function testRedis() {
  console.log('\n📦 Testing Redis Connection...');
  
  try {
    const redis = new Redis({
      host: 'localhost',
      port: 6379,
    });
    
    // Ping
    const pong = await redis.ping();
    console.log('✅ Redis: Connected (ping:', pong + ')');
    
    // Set/Get
    await redis.set('test-key', 'test-value');
    const value = await redis.get('test-key');
    
    if (value === 'test-value') {
      console.log('✅ Redis: Set/Get working');
    }
    
    await redis.del('test-key');
    await redis.quit();
    
    return true;
  } catch (error) {
    console.error('❌ Redis test failed:', error);
    return false;
  }
}

async function testMinIO() {
  console.log('\n📁 Testing MinIO Connection...');
  
  try {
    const response = await fetch('http://localhost:9000/minio/health/live');
    
    if (response.ok) {
      console.log('✅ MinIO: Server is running');
      return true;
    } else {
      console.error('❌ MinIO: Server returned', response.status);
      return false;
    }
  } catch (error) {
    console.error('❌ MinIO test failed:', error);
    return false;
  }
}

async function testQueueSystem() {
  console.log('\n⚙️  Testing Queue System...');
  
  try {
    const { Queue } = await import('bullmq');
    const Redis = (await import('ioredis')).default;
    
    const connection = new Redis({
      host: 'localhost',
      port: 6379,
      maxRetriesPerRequest: null,
    });
    
    const testQueue = new Queue('test-queue', { connection });
    
    // Добавляем тестовую задачу
    const job = await testQueue.add('test-job', {
      message: 'Hello from test',
    });
    
    console.log('✅ Queue: Job added:', job.id);
    
    // Проверяем статус
    const jobStatus = await job.getState();
    console.log('✅ Queue: Job state:', jobStatus);
    
    // Очищаем
    await testQueue.obliterate({ force: true });
    await testQueue.close();
    await connection.quit();
    
    return true;
  } catch (error) {
    console.error('❌ Queue test failed:', error);
    return false;
  }
}

async function runTests() {
  console.log('=' .repeat(60));
  console.log('🧪 Avatar Factory - Basic System Test');
  console.log('=' .repeat(60));
  
  const results = {
    database: false,
    redis: false,
    minio: false,
    queue: false,
  };
  
  results.database = await testDatabase();
  results.redis = await testRedis();
  results.minio = await testMinIO();
  results.queue = await testQueueSystem();
  
  console.log('\n' + '='.repeat(60));
  console.log('📊 Test Results');
  console.log('='.repeat(60));
  
  const passed = Object.values(results).filter(r => r).length;
  const total = Object.keys(results).length;
  
  Object.entries(results).forEach(([name, passed]) => {
    const status = passed ? '✅ PASSED' : '❌ FAILED';
    console.log(`${status.padEnd(12)} ${name}`);
  });
  
  console.log('\n' + `Total: ${passed}/${total} tests passed`);
  
  if (passed === total) {
    console.log('\n🎉 All basic tests passed!');
    console.log('\n✅ System is ready for development');
    console.log('   (GPU server not tested - requires separate machine)');
  } else {
    console.log('\n⚠️  Some tests failed. Check errors above.');
  }
  
  await prisma.$disconnect();
  process.exit(passed === total ? 0 : 1);
}

runTests().catch((error) => {
  console.error('Test suite failed:', error);
  process.exit(1);
});
