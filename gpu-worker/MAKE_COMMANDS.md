# GPU Worker - Make Commands Reference

Быстрая справка по командам `make` для установки и запуска GPU Worker на Windows.

## Требования

- **Git Bash** (поставляется с Git для Windows) — рекомендуется
- **WSL** (Windows Subsystem for Linux) — альтернатива
- **GNU Make** через Chocolatey: `choco install make` — альтернатива

> **Рекомендуется Git Bash** — уже установлен, если у тебя есть Git.

---

## Основные команды

### Установка

```bash
# Полная установка (создаст venv, установит все зависимости)
make install

# Проверить статус установки
make status

# Проверить Python
make check-python

# Проверить CUDA
make check-cuda
```

### Запуск

```bash
# Запустить сервер (блокирующий режим)
make run

# Запустить в фоне
make run-background

# Смотреть логи (если запущен в фоне)
make logs

# Проверить здоровье сервера
make health
```

### Тестирование

```bash
# Запустить тесты
make test
```

### Обслуживание

```bash
# Очистить temp файлы
make clean

# Удалить venv
make clean-venv

# Полная переустановка (удалить venv + установить заново)
make reinstall
```

### Помощь

```bash
# Показать все команды
make help
```

---

## Пошаговая установка

### 1. Открой Git Bash

Найди "Git Bash" в меню Пуск или:
- Правой кнопкой в папке проекта → "Git Bash Here"
- Или через CMD/PowerShell: `"C:\Program Files\Git\bin\bash.exe"`

### 2. Перейди в папку gpu-worker

```bash
cd /c/Projects/avatar-factory/gpu-worker
```

> **Примечание:** В Git Bash пути Windows `C:\` пишутся как `/c/`

### 3. Запусти установку

```bash
make install
```

Это займет 10-15 минут. Make автоматически:
1. Создаст `venv`
2. Обновит `pip`, `setuptools`, `wheel`
3. Установит PyTorch 2.1.0 + CUDA 11.8
4. Установит `mmcv` через `mim` (без ошибок компиляции!)
5. Установит все остальные зависимости

### 4. Проверь установку

```bash
make status
```

Должно быть:
```
PyTorch: 2.1.0+cu118
CUDA Available: True
mmcv: 2.1.0
```

### 5. Запусти сервер

```bash
make run
```

Первый запуск скачает AI модели (~5GB). Подожди пока увидишь:
```
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8001
```

---

## Troubleshooting

### Make не найден

```bash
# В Git Bash проверь:
which make

# Если "not found", установи через Chocolatey:
choco install make

# Или используй PowerShell скрипт вместо Make:
.\install_windows.ps1
```

### Ошибки компиляции mmcv

```bash
# Удали старый venv и переустанови
make reinstall
```

Make использует `mim` для установки `mmcv`, что загружает предкомпилированный wheel вместо компиляции из исходников.

### Конфликты зависимостей (openxlab, setuptools)

```bash
# Полная переустановка с чистым venv
make reinstall
```

### CUDA not available

```bash
# Проверь CUDA
make check-cuda

# Если ошибка:
# 1. Убедись что NVIDIA драйверы установлены
# 2. Установи CUDA Toolkit 11.8
# 3. Переустанови PyTorch: make reinstall
```

### Сервер не запускается

```bash
# Проверь статус
make status

# Переустанови
make reinstall

# Если всё равно не работает, проверь логи:
python server.py  # Запусти вручную чтобы видеть ошибки
```

---

## Сравнение методов установки

| Метод | Плюсы | Минусы |
|-------|-------|--------|
| **`make install`** | ✅ Простые команды<br>✅ Автоматический порядок<br>✅ Правильная установка mmcv<br>✅ Проверки версий | Требует Git Bash/WSL/GNU Make |
| **`install_windows.ps1`** | ✅ Работает в PowerShell<br>✅ GUI прогресс | Требует выполнение скриптов PowerShell |
| **`install_windows.bat`** | ✅ Работает в CMD<br>✅ Не требует прав | Менее информативный вывод |
| **Ручная установка** | ✅ Полный контроль | ❌ Легко ошибиться в порядке<br>❌ Много команд |

**Вывод:** Используй `make install` в Git Bash — самый простой и надёжный способ! 🎯

---

## Quick Reference

```bash
# === УСТАНОВКА ===
make install          # Полная установка
make status           # Проверить статус

# === ЗАПУСК ===
make run              # Запустить (блокирующий)
make run-background   # Запустить в фоне
make health           # Проверить здоровье

# === ОБСЛУЖИВАНИЕ ===
make clean            # Очистить temp
make reinstall        # Переустановить всё
make help             # Все команды
```

---

**Готов начать? Открой Git Bash и запусти:**

```bash
cd /c/Projects/avatar-factory/gpu-worker
make install
make run
```

🚀 **Enjoy!**
