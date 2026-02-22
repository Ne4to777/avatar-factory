/**
 * Mock GPU Server for testing
 */

import { vi } from 'vitest';
import type { GPUHealthCheck } from '@/lib/types';

export const mockGPUHealthCheck: GPUHealthCheck = {
  status: 'healthy',
  gpu: {
    name: 'Mock GPU',
    vram_total_gb: 12,
    vram_used_gb: 4,
    vram_free_gb: 8,
    utilization_percent: 33,
  },
  models: {
    musetalk: true,
    stable_diffusion: true,
    silero_tts: true,
  },
  mode: 'GPU',
  device: 'cuda:0',
};

export const createMockAudioBuffer = (durationSeconds: number = 1): Buffer => {
  // Create a simple WAV header + silence
  const sampleRate = 48000;
  const samples = sampleRate * durationSeconds;
  const dataSize = samples * 2; // 16-bit mono
  
  const buffer = Buffer.alloc(44 + dataSize);
  
  // WAV header (simplified)
  buffer.write('RIFF', 0);
  buffer.writeUInt32LE(36 + dataSize, 4);
  buffer.write('WAVE', 8);
  buffer.write('fmt ', 12);
  buffer.writeUInt32LE(16, 16); // fmt chunk size
  buffer.writeUInt16LE(1, 20); // PCM
  buffer.writeUInt16LE(1, 22); // Mono
  buffer.writeUInt32LE(sampleRate, 24);
  buffer.writeUInt32LE(sampleRate * 2, 28); // byte rate
  buffer.writeUInt16LE(2, 32); // block align
  buffer.writeUInt16LE(16, 34); // bits per sample
  buffer.write('data', 36);
  buffer.writeUInt32LE(dataSize, 40);
  
  return buffer;
};

export const createMockVideoBuffer = (width: number = 640, height: number = 480): Buffer => {
  // Create minimal valid MP4 structure (just enough to pass basic validation)
  // This is a simplified mock - real MP4 structure is complex
  const ftyp = Buffer.from([
    0x00, 0x00, 0x00, 0x20, // size
    0x66, 0x74, 0x79, 0x70, // 'ftyp'
    0x69, 0x73, 0x6f, 0x6d, // 'isom'
    0x00, 0x00, 0x02, 0x00,
    0x69, 0x73, 0x6f, 0x6d,
    0x69, 0x73, 0x6f, 0x32,
    0x61, 0x76, 0x63, 0x31,
    0x6d, 0x70, 0x34, 0x31,
  ]);
  
  return ftyp;
};

export const createMockImageBuffer = (width: number = 1080, height: number = 1920): Buffer => {
  // Create minimal valid PNG
  const png = Buffer.from([
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, // PNG signature
    0x00, 0x00, 0x00, 0x0d, // IHDR length
    0x49, 0x48, 0x44, 0x52, // 'IHDR'
    (width >> 24) & 0xff, (width >> 16) & 0xff, (width >> 8) & 0xff, width & 0xff,
    (height >> 24) & 0xff, (height >> 16) & 0xff, (height >> 8) & 0xff, height & 0xff,
    0x08, 0x02, 0x00, 0x00, 0x00, // bit depth, color type, compression, filter, interlace
    0x00, 0x00, 0x00, 0x00, // CRC (invalid but sufficient for mock)
    0x00, 0x00, 0x00, 0x00, // IEND length
    0x49, 0x45, 0x4e, 0x44, // 'IEND'
    0xae, 0x42, 0x60, 0x82, // IEND CRC
  ]);
  
  return png;
};

export const mockGPUClientSuccess = {
  checkHealth: vi.fn().mockResolvedValue(mockGPUHealthCheck),
  textToSpeech: vi.fn().mockImplementation(async (text: string) => {
    return createMockAudioBuffer(Math.ceil(text.length / 10));
  }),
  createLipSync: vi.fn().mockResolvedValue(createMockVideoBuffer()),
  generateBackground: vi.fn().mockResolvedValue(createMockImageBuffer()),
  cleanup: vi.fn().mockResolvedValue(undefined),
};

export const mockGPUClientError = {
  checkHealth: vi.fn().mockRejectedValue(new Error('GPU Server unavailable')),
  textToSpeech: vi.fn().mockRejectedValue(new Error('TTS failed')),
  createLipSync: vi.fn().mockRejectedValue(new Error('Lip-sync failed')),
  generateBackground: vi.fn().mockRejectedValue(new Error('Background generation failed')),
  cleanup: vi.fn().mockResolvedValue(undefined),
};
