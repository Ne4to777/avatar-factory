"""
GPU Server Test Script
Скрипт для тестирования всех эндпоинтов GPU сервера
"""

import requests
import os
import sys
from pathlib import Path

# URL сервера
SERVER_URL = os.getenv("GPU_SERVER_URL", "http://localhost:8001")
API_KEY = os.getenv("GPU_API_KEY", "your-secret-gpu-key-change-this")

def test_health():
    """Тест health endpoint"""
    print("\n" + "="*60)
    print("🏥 Testing /health endpoint")
    print("="*60)
    
    try:
        response = requests.get(f"{SERVER_URL}/health", timeout=5)
        
        if response.status_code == 200:
            data = response.json()
            print("✅ Health check passed")
            print(f"\n📊 Status: {data['status']}")
            
            if 'gpu' in data:
                gpu = data['gpu']
                print(f"\n🎮 GPU Info:")
                print(f"   Name: {gpu['name']}")
                print(f"   VRAM Total: {gpu['vram_total_gb']:.2f}GB")
                print(f"   VRAM Used: {gpu['vram_used_gb']:.2f}GB")
                print(f"   VRAM Free: {gpu['vram_free_gb']:.2f}GB")
                print(f"   Utilization: {gpu['utilization_percent']:.1f}%")
            
            if 'models' in data:
                print(f"\n📦 Models:")
                for model, loaded in data['models'].items():
                    status = "✅" if loaded else "❌"
                    print(f"   {status} {model}")
            
            return True
        else:
            print(f"❌ Health check failed: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        print(f"\n⚠️  Make sure GPU server is running:")
        print(f"   cd gpu-worker")
        print(f"   python server.py")
        return False

def test_tts():
    """Тест TTS endpoint"""
    print("\n" + "="*60)
    print("🗣️  Testing /api/tts endpoint")
    print("="*60)
    
    try:
        text = "Привет! Это тестовое сообщение для проверки синтеза речи."
        print(f"📝 Text: {text}")
        
        response = requests.post(
            f"{SERVER_URL}/api/tts",
            params={"text": text, "speaker": "xenia"},
            headers={"X-API-Key": API_KEY},
            timeout=30
        )
        
        if response.status_code == 200:
            # Сохраняем аудио
            output_path = Path("/tmp/test_tts.wav")
            output_path.write_bytes(response.content)
            
            print(f"✅ TTS generation successful")
            print(f"📁 Audio saved: {output_path}")
            print(f"📦 Size: {len(response.content) / 1024:.2f}KB")
            
            return True
        else:
            print(f"❌ TTS failed: {response.status_code}")
            print(f"   {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ TTS test failed: {e}")
        return False

def test_lipsync():
    """Тест lip-sync endpoint"""
    print("\n" + "="*60)
    print("👄 Testing /api/lipsync endpoint")
    print("="*60)
    
    # Проверяем наличие тестовых файлов
    test_image = Path("/tmp/test_image.jpg")
    test_audio = Path("/tmp/test_tts.wav")
    
    if not test_image.exists():
        print("⚠️  Test image not found: /tmp/test_image.jpg")
        print("   Please provide a test image or skip this test")
        return None
    
    if not test_audio.exists():
        print("⚠️  Test audio not found (run TTS test first)")
        return None
    
    try:
        print(f"📷 Image: {test_image}")
        print(f"🔊 Audio: {test_audio}")
        
        with open(test_image, 'rb') as img, open(test_audio, 'rb') as aud:
            files = {
                'image': ('test.jpg', img, 'image/jpeg'),
                'audio': ('test.wav', aud, 'audio/wav')
            }
            
            response = requests.post(
                f"{SERVER_URL}/api/lipsync",
                files=files,
                headers={"X-API-Key": API_KEY},
                timeout=180  # 3 минуты
            )
        
        if response.status_code == 200:
            # Сохраняем видео
            output_path = Path("/tmp/test_lipsync.mp4")
            output_path.write_bytes(response.content)
            
            print(f"✅ Lip-sync generation successful")
            print(f"📁 Video saved: {output_path}")
            print(f"📦 Size: {len(response.content) / 1024 / 1024:.2f}MB")
            
            return True
        else:
            print(f"❌ Lip-sync failed: {response.status_code}")
            print(f"   {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Lip-sync test failed: {e}")
        return False

def test_background():
    """Тест генерации фона"""
    print("\n" + "="*60)
    print("🖼️  Testing /api/generate-background endpoint")
    print("="*60)
    
    try:
        prompt = "modern office, clean desk, large window, natural light, 4k"
        print(f"💭 Prompt: {prompt}")
        
        response = requests.post(
            f"{SERVER_URL}/api/generate-background",
            params={
                "prompt": prompt,
                "width": 1080,
                "height": 1920
            },
            headers={"X-API-Key": API_KEY},
            timeout=60
        )
        
        if response.status_code == 200:
            # Сохраняем изображение
            output_path = Path("/tmp/test_background.png")
            output_path.write_bytes(response.content)
            
            print(f"✅ Background generation successful")
            print(f"📁 Image saved: {output_path}")
            print(f"📦 Size: {len(response.content) / 1024:.2f}KB")
            
            return True
        else:
            print(f"❌ Background generation failed: {response.status_code}")
            print(f"   {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Background test failed: {e}")
        return False

def run_all_tests():
    """Запуск всех тестов"""
    print("\n" + "="*60)
    print("🧪 GPU Server Test Suite")
    print("="*60)
    print(f"Server: {SERVER_URL}")
    print(f"API Key: {API_KEY[:10]}...")
    
    results = {
        'health': False,
        'tts': False,
        'lipsync': None,
        'background': False
    }
    
    # 1. Health check (обязательно)
    results['health'] = test_health()
    
    if not results['health']:
        print("\n❌ Server is not healthy. Aborting tests.")
        sys.exit(1)
    
    # 2. TTS test
    results['tts'] = test_tts()
    
    # 3. Lip-sync test (если есть тестовые файлы)
    results['lipsync'] = test_lipsync()
    
    # 4. Background generation test
    results['background'] = test_background()
    
    # Итоги
    print("\n" + "="*60)
    print("📊 Test Summary")
    print("="*60)
    
    for test_name, result in results.items():
        if result is True:
            status = "✅ PASSED"
        elif result is False:
            status = "❌ FAILED"
        else:
            status = "⏭️  SKIPPED"
        
        print(f"{status:12} {test_name}")
    
    # Финальный результат
    passed = sum(1 for r in results.values() if r is True)
    failed = sum(1 for r in results.values() if r is False)
    skipped = sum(1 for r in results.values() if r is None)
    
    print(f"\nTotal: {passed} passed, {failed} failed, {skipped} skipped")
    
    if failed == 0:
        print("\n🎉 All tests passed!")
        return 0
    else:
        print("\n⚠️  Some tests failed. Check logs above.")
        return 1

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Test GPU Server")
    parser.add_argument("--url", help="Server URL", default=SERVER_URL)
    parser.add_argument("--key", help="API Key", default=API_KEY)
    parser.add_argument("--test", choices=['health', 'tts', 'lipsync', 'background', 'all'], 
                       default='all', help="Which test to run")
    
    args = parser.parse_args()
    
    SERVER_URL = args.url
    API_KEY = args.key
    
    if args.test == 'health':
        test_health()
    elif args.test == 'tts':
        test_tts()
    elif args.test == 'lipsync':
        test_lipsync()
    elif args.test == 'background':
        test_background()
    else:
        exit_code = run_all_tests()
        sys.exit(exit_code)
