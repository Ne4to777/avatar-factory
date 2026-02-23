"""
Frontend Server для Avatar Factory
Простой веб-сервер для UI, который проксирует запросы на GPU Worker
"""

from flask import Flask, render_template, request, send_file, jsonify
from flask_cors import CORS
import requests
import os
from pathlib import Path
import tempfile

app = Flask(__name__, 
            static_folder='frontend/static',
            template_folder='frontend')
CORS(app)

# URL GPU сервера (измените на IP вашей Windows машины)
GPU_SERVER_URL = os.getenv('GPU_SERVER_URL', 'http://192.168.1.100:8001')
GPU_API_KEY = os.getenv('GPU_API_KEY', 'your-secret-gpu-key-change-this')

@app.route('/')
def index():
    """Главная страница с UI"""
    return render_template('index.html')

@app.route('/api/health')
def health():
    """Проксируем health check на GPU сервер"""
    try:
        response = requests.get(f'{GPU_SERVER_URL}/health', timeout=5)
        return response.json(), response.status_code
    except Exception as e:
        return {'error': str(e), 'status': 'disconnected'}, 503

@app.route('/api/tts', methods=['POST'])
def tts():
    """Проксируем TTS на GPU сервер"""
    try:
        text = request.args.get('text', '')
        speaker = request.args.get('speaker', 'xenia')
        
        response = requests.post(
            f'{GPU_SERVER_URL}/api/tts',
            params={'text': text, 'speaker': speaker},
            headers={'x-api-key': GPU_API_KEY},
            timeout=60
        )
        
        if response.status_code == 200:
            # Сохраняем во временный файл и отправляем
            with tempfile.NamedTemporaryFile(delete=False, suffix='.wav') as f:
                f.write(response.content)
                temp_path = f.name
            
            return send_file(temp_path, mimetype='audio/wav')
        else:
            return {'error': response.text}, response.status_code
            
    except Exception as e:
        return {'error': str(e)}, 500

@app.route('/api/background', methods=['POST'])
def background():
    """Проксируем генерацию фона на GPU сервер"""
    try:
        data = request.get_json()
        
        response = requests.post(
            f'{GPU_SERVER_URL}/api/background',
            json=data,
            headers={'x-api-key': GPU_API_KEY},
            timeout=120  # 2 минуты для генерации
        )
        
        if response.status_code == 200:
            # Сохраняем во временный файл и отправляем
            with tempfile.NamedTemporaryFile(delete=False, suffix='.png') as f:
                f.write(response.content)
                temp_path = f.name
            
            return send_file(temp_path, mimetype='image/png')
        else:
            return {'error': response.text}, response.status_code
            
    except Exception as e:
        return {'error': str(e)}, 500

@app.route('/api/lipsync', methods=['POST'])
def lipsync():
    """Проксируем lip-sync на GPU сервер"""
    try:
        # Получаем файлы от клиента
        image = request.files.get('image')
        audio = request.files.get('audio')
        fps = request.form.get('fps', 25)
        
        if not image or not audio:
            return {'error': 'Image and audio required'}, 400
        
        # Сохраняем во временные файлы
        with tempfile.NamedTemporaryFile(delete=False, suffix=Path(image.filename).suffix) as img_f:
            image.save(img_f.name)
            img_path = img_f.name
        
        with tempfile.NamedTemporaryFile(delete=False, suffix=Path(audio.filename).suffix) as aud_f:
            audio.save(aud_f.name)
            aud_path = aud_f.name
        
        # Отправляем на GPU сервер
        with open(img_path, 'rb') as img_file, open(aud_path, 'rb') as aud_file:
            files = {
                'image': (image.filename, img_file, image.content_type),
                'audio': (audio.filename, aud_file, audio.content_type)
            }
            data = {'fps': fps}
            
            response = requests.post(
                f'{GPU_SERVER_URL}/api/lipsync',
                files=files,
                data=data,
                headers={'x-api-key': GPU_API_KEY},
                timeout=300  # 5 минут для генерации видео
            )
        
        # Удаляем временные файлы
        os.unlink(img_path)
        os.unlink(aud_path)
        
        if response.status_code == 200:
            # Сохраняем видео во временный файл и отправляем
            with tempfile.NamedTemporaryFile(delete=False, suffix='.mp4') as f:
                f.write(response.content)
                temp_path = f.name
            
            return send_file(temp_path, mimetype='video/mp4')
        else:
            return {'error': response.text}, response.status_code
            
    except Exception as e:
        return {'error': str(e)}, 500

if __name__ == '__main__':
    # Создаем директорию для frontend если её нет
    frontend_dir = Path(__file__).parent / 'frontend'
    frontend_dir.mkdir(exist_ok=True)
    
    print("="*60)
    print("Avatar Factory Frontend Server")
    print("="*60)
    print(f"GPU Server: {GPU_SERVER_URL}")
    print(f"")
    print(f"Starting server on http://0.0.0.0:3000")
    print(f"Access from network: http://<your-laptop-ip>:3000")
    print("="*60)
    
    app.run(host='0.0.0.0', port=3000, debug=True)
