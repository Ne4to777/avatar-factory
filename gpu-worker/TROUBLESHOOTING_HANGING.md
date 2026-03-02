# 🔧 Troubleshooting: Server Hanging Issues

Решение проблемы "сервер висит после генерации изображения".

---

## ❌ Проблема

```
100%|##########| 30/30 [06:04<00:00, 12.14s/it]
# ... и ничего не происходит несколько минут
```

Сервер завершил генерацию (100%), но "завис" и не отвечает.

---

## 🔍 Причины

### 1. Медленное сохранение файла

Для больших изображений (1080x1920) `image.save()` может занимать:
- PNG без сжатия: ~2-5 сек
- PNG с compression: ~10-30 сек ⚠️
- Проблема: нет логов во время save

### 2. Memory leak (GPU)

После генерации VRAM не очищается:
- SDXL занимает ~8GB
- Без `torch.cuda.empty_cache()` память не освобождается
- Следующая генерация → OOM → hang

### 3. FileResponse медленно отправляет

Для больших файлов (5-10MB PNG):
- Медленная сеть → долгая отправка
- Нет timeout на отправку
- Client может disconnect → server висит

### 4. Background tasks не выполняются

`background_tasks.add_task(cleanup)` может не сработать если:
- Request timeout
- Client disconnect до cleanup
- → Temp files накапливаются

---

## ✅ Решение (применено)

### 1. Детальное логирование

**Было:**
```python
image = sd_pipeline(...).images[0]
image.save(output_path)
logger.info(f"Generated: {output_path}")
return FileResponse(output_path)
```

**Стало:**
```python
logger.debug("Starting SDXL inference...")
image = sd_pipeline(...).images[0]
logger.debug("SDXL inference complete")

torch.cuda.empty_cache()  # ← ВАЖНО!
logger.debug("GPU cache cleared")

logger.debug(f"Saving image to: {output_path.name}")
save_start = time.time()
image.save(output_path)
save_time = time.time() - save_start

file_size_mb = output_path.stat().st_size / 1e6
logger.info(f"✅ Generated: {output_path.name} ({file_size_mb:.2f}MB, save_time={save_time:.1f}s)")

logger.debug(f"Sending FileResponse: {output_path.name}")
return FileResponse(...)
```

**Что это дает:**
- ✅ Видно где именно зависает
- ✅ Timing info для каждого этапа
- ✅ GPU cleanup после генерации

### 2. GPU Memory Cleanup

```python
# После каждой AI операции
torch.cuda.empty_cache()
```

Освобождает неиспользуемую VRAM.

---

## 🧪 Диагностика

### Запустите тест:

```bash
cd gpu-worker
test-background-timeout.bat
```

Тест покажет:
1. Время генерации для разных размеров
2. Где именно зависает
3. Размеры файлов

### Смотрите логи:

```bash
# Windows
type logs\server.log | findstr "Background\|SDXL\|Saving\|Sending"

# Что искать:
# ✅ "Starting SDXL inference..." - началась генерация
# ✅ "SDXL inference complete" - закончилась генерация
# ✅ "GPU cache cleared" - память очищена
# ✅ "Saving image to: ..." - началось сохранение
# ✅ "Background generated: ... (X.XXMБ, save_time=X.Xs)" - сохранено
# ✅ "Sending FileResponse: ..." - отправка клиенту
# ❌ Если нет последних логов → зависло на этом этапе
```

---

## 📊 Типичные timing'и

| Размер | Inference | Save | Send | Total |
|--------|-----------|------|------|-------|
| 512x512 | 15-20s | 1-2s | 1s | ~20s |
| 1024x1024 | 45-60s | 3-5s | 2-3s | ~60s |
| 1080x1920 | 6-7 min | **10-30s** | **5-10s** | ~8 min |

**Проблема:** Для 1080x1920 save + send может занять 30-40 секунд БЕЗ логов!

---

## 🔧 Дополнительные исправления

### 1. Уменьшить compression (если висит на save)

```python
# В server.py, функция generate_background:
image.save(output_path, optimize=False, compress_level=1)
# Вместо:
image.save(output_path)

# Результат:
# - Файл больше (~2x)
# - Сохранение быстрее (~5x)
```

### 2. Streaming response (если висит на send)

```python
# Вместо FileResponse
def iterfile():
    with open(output_path, "rb") as f:
        while chunk := f.read(64 * 1024):
            yield chunk
    output_path.unlink()

return StreamingResponse(iterfile(), media_type="image/png")
```

### 3. Timeout на client

```bash
# Добавить --max-time в curl
curl ... --max-time 600  # 10 минут max
```

---

## 🚨 Если проблема осталась

### Проверка 1: VRAM leak

```bash
# До генерации
nvidia-smi

# После генерации
nvidia-smi

# Если VRAM не освобождается → добавить больше empty_cache()
```

### Проверка 2: Disk I/O

```bash
# Проверить скорость записи
powershell -Command "Measure-Command { dd if=/dev/zero of=test.dat bs=1M count=100 }"

# Если медленно (>5 сек для 100MB) → проблема с диском
```

### Проверка 3: Network

```bash
# Проверить скорость отправки
curl http://localhost:8001/api/generate-background ... --output test.png

# Если висит после "Sending FileResponse" → проблема сети/client
```

---

## 💡 Best Practices

### 1. Используйте разумные размеры

```python
# Плохо: слишком большое разрешение
width=2048, height=4096  # ❌ 15+ минут, ~20MB файл

# Хорошо: оптимальное
width=1024, height=1024  # ✅ 1 минута, ~3MB файл

# Для production
width=1080, height=1920  # ⚠️ 8 минут, но качественно
```

### 2. Batch generation

```python
# Если нужно несколько вариантов:
for i in range(4):
    # Генерировать
    # Между генерациями:
    torch.cuda.empty_cache()
    time.sleep(1)  # Дать GPU остыть
```

### 3. Мониторинг

```bash
# Terminal 1: Server logs
tail -f logs/server.log

# Terminal 2: GPU monitoring
nvidia-smi -l 2

# Terminal 3: Requests
curl ...

# Смотрите:
# - VRAM usage должен падать после генерации
# - Temperature не должна быть >80°C
# - Logs должны появляться регулярно
```

---

## 📞 Если ничего не помогло

### Соберите диагностику:

```bash
# 1. Server logs
type logs\server.log > diagnostics.txt

# 2. GPU info
nvidia-smi >> diagnostics.txt

# 3. System info
systeminfo >> diagnostics.txt

# 4. Test results
test-background-timeout.bat >> diagnostics.txt
```

### Временное решение:

```bash
# Уменьшить размер изображений
curl ... --data-urlencode "width=768" --data-urlencode "height=768"

# Или использовать меньше inference steps
# В server.py изменить num_inference_steps=30 → 20
```

---

## ✅ Что исправлено в последнем commit

```
Commit: [новый commit]

Changes:
- Детальное логирование в generate_background
- torch.cuda.empty_cache() после генерации
- Timing info для save operation
- File size reporting
- Better error handling

Result:
- Видно где именно зависает
- GPU память освобождается
- Можно диагностировать проблему
```

---

**Перезапустите сервер после обновления!**

```bash
# Ctrl+C в окне сервера
venv\Scripts\activate
python server.py

# Тест
test-background-timeout.bat
```
