/**
 * Avatar Factory Frontend Server
 * Node.js + Express server that serves UI and proxies requests to GPU worker
 */

import express from 'express';
import cors from 'cors';
import fetch from 'node-fetch';
import FormData from 'form-data';
import multer from 'multer';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const upload = multer({ storage: multer.memoryStorage() });

// Configuration
const GPU_SERVER_URL = process.env.GPU_SERVER_URL || 'http://192.168.1.100:8001';
const GPU_API_KEY = process.env.GPU_API_KEY || 'your-secret-gpu-key-change-this';
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'frontend')));

// Health check
app.get('/api/health', async (req, res) => {
  try {
    const response = await fetch(`${GPU_SERVER_URL}/health`);
    const data = await response.json();
    res.json(data);
  } catch (error) {
    res.status(503).json({ 
      error: error.message, 
      status: 'disconnected' 
    });
  }
});

// TTS endpoint
app.post('/api/tts', async (req, res) => {
  try {
    const { text, speaker = 'xenia' } = req.query;
    
    const response = await fetch(
      `${GPU_SERVER_URL}/api/tts?text=${encodeURIComponent(text)}&speaker=${speaker}`,
      {
        method: 'POST',
        headers: { 'x-api-key': GPU_API_KEY }
      }
    );
    
    if (!response.ok) {
      const error = await response.text();
      return res.status(response.status).json({ error });
    }
    
    const buffer = await response.buffer();
    res.setHeader('Content-Type', 'audio/wav');
    res.send(buffer);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Background generation endpoint
app.post('/api/background', async (req, res) => {
  try {
    const response = await fetch(`${GPU_SERVER_URL}/api/background`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': GPU_API_KEY
      },
      body: JSON.stringify(req.body)
    });
    
    if (!response.ok) {
      const error = await response.text();
      return res.status(response.status).json({ error });
    }
    
    const buffer = await response.buffer();
    res.setHeader('Content-Type', 'image/png');
    res.send(buffer);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Lip-sync endpoint
app.post('/api/lipsync', upload.fields([
  { name: 'image', maxCount: 1 },
  { name: 'audio', maxCount: 1 }
]), async (req, res) => {
  try {
    const imageFile = req.files['image']?.[0];
    const audioFile = req.files['audio']?.[0];
    
    if (!imageFile || !audioFile) {
      return res.status(400).json({ error: 'Image and audio required' });
    }
    
    const formData = new FormData();
    formData.append('image', imageFile.buffer, imageFile.originalname);
    formData.append('audio', audioFile.buffer, audioFile.originalname);
    formData.append('fps', req.body.fps || '25');
    
    const response = await fetch(`${GPU_SERVER_URL}/api/lipsync`, {
      method: 'POST',
      headers: {
        'x-api-key': GPU_API_KEY,
        ...formData.getHeaders()
      },
      body: formData
    });
    
    if (!response.ok) {
      const error = await response.text();
      return res.status(response.status).json({ error });
    }
    
    const buffer = await response.buffer();
    res.setHeader('Content-Type', 'video/mp4');
    res.send(buffer);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log('='.repeat(60));
  console.log('Avatar Factory Frontend Server');
  console.log('='.repeat(60));
  console.log(`GPU Server: ${GPU_SERVER_URL}`);
  console.log('');
  console.log(`Server running on:`);
  console.log(`  Local:   http://localhost:${PORT}`);
  console.log(`  Network: http://<your-ip>:${PORT}`);
  console.log('='.repeat(60));
});
