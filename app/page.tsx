/**
 * Home Page - Create Video
 */

'use client';

import { useState, useEffect } from 'react';
import { Upload, Wand2, Video, Clock, CheckCircle2, XCircle } from 'lucide-react';

export default function HomePage() {
  const [text, setText] = useState('');
  const [photoFile, setPhotoFile] = useState<File | null>(null);
  const [photoPreview, setPhotoPreview] = useState<string>('');
  const [backgroundStyle, setBackgroundStyle] = useState('professional');
  const [format, setFormat] = useState<'VERTICAL' | 'HORIZONTAL' | 'SQUARE'>('VERTICAL');
  const [voiceId, setVoiceId] = useState('ru_speaker_female');
  
  const [status, setStatus] = useState<'idle' | 'uploading' | 'processing'>('idle');
  const [progress, setProgress] = useState(0);
  const [videoId, setVideoId] = useState<string | null>(null);
  const [videoUrl, setVideoUrl] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [cleanupPoll, setCleanupPoll] = useState<(() => void) | null>(null);
  
  // Обработка выбора фото
  const handlePhotoChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setPhotoFile(file);
      const reader = new FileReader();
      reader.onloadend = () => {
        setPhotoPreview(reader.result as string);
      };
      reader.readAsDataURL(file);
    }
  };
  
  // Создание видео
  const handleCreate = async () => {
    if (!photoFile || !text) {
      setError('Пожалуйста, загрузите фото и введите текст');
      return;
    }
    
    setError(null);
    setStatus('uploading');
    
    try {
      // 1. Загружаем фото
      const formData = new FormData();
      formData.append('file', photoFile);
      formData.append('type', 'avatar');
      
      const uploadRes = await fetch('/api/upload', {
        method: 'POST',
        body: formData,
      });
      
      if (!uploadRes.ok) {
        throw new Error('Ошибка загрузки фото');
      }
      
      const uploadData = await uploadRes.json();
      
      // 2. Создаем видео
      setStatus('processing');
      
      const createRes = await fetch('/api/videos/create', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          text,
          photoUrl: uploadData.url,
          backgroundStyle,
          format,
          voiceId,
        }),
      });
      
      if (!createRes.ok) {
        throw new Error('Ошибка создания видео');
      }
      
      const createData = await createRes.json();
      const newVideoId = createData.data?.videoId ?? createData.videoId;
      setVideoId(newVideoId);

      // 3. Отслеживаем прогресс
      const cleanup = await pollVideoStatus(newVideoId);
      setCleanupPoll(() => cleanup);

    } catch (err: any) {
      setError(err.message);
      setStatus('idle');
    }
  };
  
  // Опрос статуса видео — возвращает функцию очистки интервала
  const pollVideoStatus = async (id: string): Promise<() => void> => {
    let intervalId: NodeJS.Timeout | null = null;

    const poll = async (): Promise<string> => {
      try {
        const res = await fetch(`/api/videos/${id}`);
        const data = await res.json();
        const video = data.data ?? data.video;

        setProgress(video?.progress ?? 0);

        if (video?.status === 'COMPLETED') {
          if (intervalId) {
            clearInterval(intervalId);
            intervalId = null;
          }
          setVideoUrl(video.videoUrl);
          setStatus('idle');
          return video.status;
        } else if (video?.status === 'FAILED') {
          if (intervalId) {
            clearInterval(intervalId);
            intervalId = null;
          }
          setError(video.error ?? video.errorMessage ?? 'Ошибка генерации');
          setStatus('idle');
          return video.status;
        }
        return video?.status ?? 'PENDING';
      } catch (err) {
        console.error('Polling error:', err);
        setError('Не удалось проверить статус видео');
        if (intervalId) {
          clearInterval(intervalId);
          intervalId = null;
        }
        return 'FAILED';
      }
    };

    const initialStatus = await poll();
    if (initialStatus !== 'COMPLETED' && initialStatus !== 'FAILED') {
      intervalId = setInterval(() => poll(), 2000);
    }

    return () => {
      if (intervalId) {
        clearInterval(intervalId);
        intervalId = null;
      }
    };
  };

  // Очистка интервала при размонтировании (навигация со страницы)
  useEffect(() => {
    return () => {
      if (cleanupPoll) {
        cleanupPoll();
      }
    };
  }, [cleanupPoll]);
  
  return (
    <div className="min-h-screen bg-gradient-to-br from-purple-50 to-blue-50">
      <div className="max-w-4xl mx-auto px-4 py-12">
        {/* Header */}
        <div className="text-center mb-12">
          <h1 className="text-5xl font-bold text-gray-900 mb-4">
            Avatar Factory
          </h1>
          <p className="text-xl text-gray-600">
            Создавайте видео с говорящими аватарами за минуту
          </p>
        </div>
        
        {/* Main Form */}
        <div className="bg-white rounded-2xl shadow-xl p-8 mb-8">
          {/* Photo Upload */}
          <div className="mb-6">
            <label className="block text-sm font-medium text-gray-700 mb-2">
              1. Загрузите ваше фото
            </label>
            
            <div className="flex items-center gap-4">
              {photoPreview ? (
                <div className="relative w-32 h-32 rounded-lg overflow-hidden">
                  <img src={photoPreview} alt="Preview" className="w-full h-full object-cover" />
                  <button
                    onClick={() => {
                      setPhotoFile(null);
                      setPhotoPreview('');
                    }}
                    className="absolute top-2 right-2 bg-red-500 text-white p-1 rounded-full hover:bg-red-600"
                  >
                    <XCircle size={20} />
                  </button>
                </div>
              ) : (
                <label className="flex flex-col items-center justify-center w-32 h-32 border-2 border-dashed border-gray-300 rounded-lg cursor-pointer hover:border-purple-500 transition">
                  <Upload size={32} className="text-gray-400 mb-2" />
                  <span className="text-sm text-gray-500">Выбрать</span>
                  <input
                    type="file"
                    accept="image/*"
                    onChange={handlePhotoChange}
                    className="hidden"
                  />
                </label>
              )}
              
              <div className="flex-1">
                <p className="text-sm text-gray-600">
                  Загрузите фотографию вашего лица. Лучше всего подходят:
                </p>
                <ul className="text-sm text-gray-500 mt-2 space-y-1">
                  <li>• Фронтальный снимок</li>
                  <li>• Хорошее освещение</li>
                  <li>• Разрешение от 512x512</li>
                </ul>
              </div>
            </div>
          </div>
          
          {/* Text Input */}
          <div className="mb-6">
            <label className="block text-sm font-medium text-gray-700 mb-2">
              2. Введите текст для озвучки
            </label>
            <textarea
              value={text}
              onChange={(e) => setText(e.target.value)}
              placeholder="Напишите текст, который произнесет ваш аватар..."
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent resize-none"
              rows={5}
              maxLength={500}
            />
            <div className="text-right text-sm text-gray-500 mt-1">
              {text.length}/500
            </div>
          </div>
          
          {/* Options */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
            {/* Background Style */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Стиль фона
              </label>
              <select
                value={backgroundStyle}
                onChange={(e) => setBackgroundStyle(e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500"
              >
                <option value="simple">Простой</option>
                <option value="professional">Профессиональный</option>
                <option value="creative">Креативный</option>
                <option value="minimalist">Минималистичный</option>
              </select>
            </div>
            
            {/* Format */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Формат
              </label>
              <select
                value={format}
                onChange={(e) => setFormat(e.target.value as any)}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500"
              >
                <option value="VERTICAL">Вертикальное (9:16)</option>
                <option value="HORIZONTAL">Горизонтальное (16:9)</option>
                <option value="SQUARE">Квадрат (1:1)</option>
              </select>
            </div>
            
            {/* Voice */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Голос
              </label>
              <select
                value={voiceId}
                onChange={(e) => setVoiceId(e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500"
              >
                <option value="ru_speaker_female">Женский</option>
                <option value="ru_speaker_male">Мужской</option>
              </select>
            </div>
          </div>
          
          {/* Error */}
          {error && (
            <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg">
              <p className="text-red-800">{error}</p>
            </div>
          )}
          
          {/* Create Button */}
          <button
            onClick={handleCreate}
            disabled={!photoFile || !text || status !== 'idle'}
            className="w-full bg-gradient-to-r from-purple-600 to-blue-600 text-white py-4 rounded-lg font-semibold text-lg hover:from-purple-700 hover:to-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition flex items-center justify-center gap-2"
          >
            {status === 'idle' && (
              <>
                <Wand2 size={24} />
                Создать видео
              </>
            )}
            {status === 'uploading' && (
              <>
                <Clock size={24} className="animate-spin" />
                Загрузка фото...
              </>
            )}
            {status === 'processing' && (
              <>
                <Video size={24} className="animate-pulse" />
                Генерация {progress}%
              </>
            )}
          </button>
          
          {/* Progress Bar */}
          {status === 'processing' && (
            <div className="mt-4">
              <div className="h-2 bg-gray-200 rounded-full overflow-hidden">
                <div
                  className="h-full bg-gradient-to-r from-purple-600 to-blue-600 transition-all duration-500"
                  style={{ width: `${progress}%` }}
                />
              </div>
              <p className="text-center text-sm text-gray-600 mt-2">
                Обработка может занять 1-3 минуты...
              </p>
            </div>
          )}
        </div>
        
        {/* Result */}
        {videoUrl && (
          <div className="bg-white rounded-2xl shadow-xl p-8">
            <div className="flex items-center gap-2 mb-4">
              <CheckCircle2 size={24} className="text-green-500" />
              <h2 className="text-2xl font-bold text-gray-900">
                Видео готово!
              </h2>
            </div>
            
            <video
              src={videoUrl}
              controls
              className="w-full rounded-lg mb-4"
            />
            
            <div className="flex gap-4">
              <a
                href={videoUrl}
                download
                className="flex-1 bg-purple-600 text-white py-3 rounded-lg font-semibold text-center hover:bg-purple-700 transition"
              >
                Скачать видео
              </a>
              <button
                onClick={() => {
                  setVideoUrl(null);
                  setVideoId(null);
                  setProgress(0);
                  setPhotoFile(null);
                  setPhotoPreview('');
                  setText('');
                }}
                className="flex-1 bg-gray-200 text-gray-800 py-3 rounded-lg font-semibold hover:bg-gray-300 transition"
              >
                Создать новое
              </button>
            </div>
          </div>
        )}
        
        {/* Features */}
        <div className="mt-12 grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="text-center p-6">
            <div className="w-16 h-16 bg-purple-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <Wand2 size={32} className="text-purple-600" />
            </div>
            <h3 className="font-semibold text-lg mb-2">100% Open Source</h3>
            <p className="text-gray-600 text-sm">
              Все работает локально, без внешних API
            </p>
          </div>
          
          <div className="text-center p-6">
            <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <Video size={32} className="text-blue-600" />
            </div>
            <h3 className="font-semibold text-lg mb-2">Быстрая генерация</h3>
            <p className="text-gray-600 text-sm">
              Видео готово за 1-3 минуты
            </p>
          </div>
          
          <div className="text-center p-6">
            <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <CheckCircle2 size={32} className="text-green-600" />
            </div>
            <h3 className="font-semibold text-lg mb-2">Качественный результат</h3>
            <p className="text-gray-600 text-sm">
              Lip-sync и натуральная озвучка
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
