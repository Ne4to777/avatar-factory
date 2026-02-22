# 📥 Ручная загрузка моделей MuseTalk

Если автоматическая загрузка через `install-musetalk.ps1` не работает или слишком медленная, можно скачать модели вручную.

---

## 🎯 Вариант 1: Через браузер (рекомендуется)

### Шаг 1: Откройте репозиторий на HuggingFace

Перейдите по ссылке: https://huggingface.co/TMElyralab/MuseTalk

### Шаг 2: Скачайте все файлы

**Способ А: Скачать архив целиком (проще)**

1. Нажмите на кнопку **"Files and versions"** (вверху справа)
2. Нажмите **"Download repository"** или используйте прямую ссылку:
   ```
   https://huggingface.co/TMElyralab/MuseTalk/tree/main
   ```
3. Справа от списка файлов найдите кнопку со стрелкой вниз для скачивания ZIP

**Способ Б: Скачать файлы по одному**

Скачайте следующие файлы (нажимайте на каждый файл → кнопка Download):

**Обязательные файлы:**
- `config.json` (~1 KB)
- `model_index.json` (~500 B)
- `pytorch_model.bin` или `model.safetensors` (~2 GB) - **основная модель**
- `config/` (папка с конфигурациями)
- `checkpoints/` (папка с весами моделей)
- `models/` (папка с дополнительными моделями)

**Полный список файлов для загрузки:**
```
MuseTalk/
├── models/
│   ├── dwpose/
│   │   └── dw-ll_ucoco_384.pth (~200 MB)
│   ├── face-parse-bisent/
│   │   ├── 79999_iter.pth (~50 MB)
│   │   └── resnet18-5c106cde.pth (~45 MB)
│   ├── sd-vae-ft-mse/
│   │   └── diffusion_pytorch_model.safetensors (~335 MB)
│   ├── whisper/
│   │   └── tiny.pt (~75 MB)
│   ├── musetalk/
│   │   └── musetalk.json (~1 KB)
│   └── unet.pth (~1.2 GB) - **ВАЖНО: самый большой файл**
├── scripts/
├── configs/
├── README.md
└── .gitattributes
```

### Шаг 3: Распакуйте файлы

1. Если скачали ZIP - распакуйте его
2. Переместите **содержимое** в папку:
   ```
   C:\dev\avatar-factory\gpu-worker\MuseTalk\models\
   ```

**Важно:** Структура должна быть такой:
```
C:\dev\avatar-factory\gpu-worker\
└── MuseTalk\
    └── models\
        ├── dwpose\
        ├── face-parse-bisent\
        ├── sd-vae-ft-mse\
        ├── whisper\
        ├── musetalk\
        └── unet.pth
```

---

## 🎯 Вариант 2: Через Git LFS (для опытных пользователей)

### Требования:
- Git установлен
- Git LFS установлен

### Шаг 1: Установите Git LFS (если ещё не установлен)

```cmd
winget install -e --id GitHub.GitLFS
```

Или скачайте с https://git-lfs.github.com/

### Шаг 2: Инициализируйте Git LFS

```cmd
git lfs install
```

### Шаг 3: Клонируйте репозиторий

```cmd
cd C:\dev\avatar-factory\gpu-worker\MuseTalk
git lfs clone https://huggingface.co/TMElyralab/MuseTalk models
```

**Важно:** Это скачает ~2 GB данных. Убедитесь что есть место на диске.

---

## 🎯 Вариант 3: Через huggingface-cli (из Python)

### Шаг 1: Активируйте виртуальное окружение

```cmd
cd C:\dev\avatar-factory\gpu-worker
venv\Scripts\activate
```

### Шаг 2: Установите huggingface-cli

```cmd
pip install -U "huggingface_hub[cli]"
```

### Шаг 3: (Опционально) Авторизуйтесь

```cmd
huggingface-cli login
```

Введите ваш токен: `hf_YOUR_TOKEN_HERE`

### Шаг 4: Скачайте модели

```cmd
cd MuseTalk
huggingface-cli download TMElyralab/MuseTalk --local-dir ./models --local-dir-use-symlinks False
```

---

## ✅ Проверка установки

После загрузки проверьте что файлы на месте:

```cmd
cd C:\dev\avatar-factory\gpu-worker
dir MuseTalk\models /s
```

Должны быть видны:
- ✅ `unet.pth` (~1.2 GB)
- ✅ `dwpose/dw-ll_ucoco_384.pth` (~200 MB)
- ✅ `face-parse-bisent/79999_iter.pth` (~50 MB)
- ✅ `sd-vae-ft-mse/diffusion_pytorch_model.safetensors` (~335 MB)
- ✅ `whisper/tiny.pt` (~75 MB)

### Проверка через Python

```cmd
venv\Scripts\python.exe -c "import os; print('OK' if os.path.exists('MuseTalk/models/unet.pth') else 'MISSING')"
```

Должно вывести: `OK`

---

## 🚀 Запуск после ручной установки

После того как модели скачаны вручную:

1. **Запустите сервер:**
   ```cmd
   start.bat
   ```

2. **Проверьте здоровье:**
   ```cmd
   curl http://localhost:8001/health
   ```

   Должно быть:
   ```json
   {
     "status": "healthy",
     "models": {
       "musetalk": true,
       ...
     }
   }
   ```

---

## 🐛 Troubleshooting

### Проблема: "MuseTalk not loaded"

**Решение:**
1. Убедитесь что путь правильный:
   ```cmd
   dir MuseTalk\models\unet.pth
   ```
2. Перезапустите сервер:
   ```cmd
   stop.bat
   start.bat
   ```

### Проблема: "Model file not found"

**Решение:**
- Проверьте структуру папок - все файлы должны быть в `MuseTalk\models\`, а не в `MuseTalk\models\MuseTalk\`
- Возможно при распаковке ZIP создалась вложенная папка

### Проблема: Загрузка прерывается

**Решение:**
- Используйте менеджер загрузок (например, Free Download Manager)
- Или используйте Git LFS (поддерживает продолжение загрузки)
- Или скачайте файлы по одному, начиная с самых больших

---

## 📊 Размеры файлов (для планирования)

| Компонент | Размер | Описание |
|-----------|--------|----------|
| **unet.pth** | ~1.2 GB | Основная модель U-Net |
| **dwpose** | ~200 MB | Определение позы |
| **face-parse-bisent** | ~95 MB | Парсинг лица |
| **sd-vae-ft-mse** | ~335 MB | VAE энкодер |
| **whisper** | ~75 MB | Распознавание речи |
| **Остальные** | ~50 MB | Конфиги и утилиты |
| **ИТОГО** | ~2 GB | Общий размер |

---

## 💡 Советы

1. **Быстрая загрузка:** Используйте HF_TOKEN для авторизации на HuggingFace (увеличивает скорость)
2. **Медленный интернет:** Скачивайте файлы по одному в несколько заходов
3. **Нестабильный интернет:** Используйте Git LFS - он поддерживает продолжение загрузки
4. **Корпоративная сеть:** Возможно понадобится настроить прокси для Git LFS

---

## 🔗 Полезные ссылки

- Репозиторий MuseTalk: https://huggingface.co/TMElyralab/MuseTalk
- Git LFS: https://git-lfs.github.com/
- HuggingFace Hub: https://huggingface.co/docs/hub/index
- Получить HF токен: https://huggingface.co/settings/tokens

---

**После успешной загрузки моделей, сервер автоматически обнаружит их при следующем запуске!**
