# 🤔 Какой метод установки выбрать?

Быстрый гайд по выбору правильного метода установки для вашей ситуации.

---

## ⚡ Очень быстрый ответ

### Стационарный ПК (GPU Worker):

```bash
# Windows
cd gpu-worker
install.bat
start.bat

# Linux/macOS
cd gpu-worker
make install
make start
```

### Ноутбук (Main App):

```bash
# Одна команда
make install && make dev

# Или с UI + Worker вместе
just install && just dev-all
```

---

## 📊 Выбор по опыту

### 🟢 Новичок (никогда не работал с командной строкой)

```bash
# Интерактивные shell scripts
./quick-start.sh
# Или
./install.sh && ./start.sh
```

**Почему:** Скрипты проведут вас через весь процесс с понятными вопросами.

---

### 🟡 Средний уровень (знаю основы Linux/macOS)

```bash
# npm scripts (самое простое)
npm run install:full
npm run start:dev

# Или Make (стандарт)
make install
make dev
```

**Почему:** npm уже знаком, Make - стандарт индустрии.

---

### 🔴 Опытный (работаю с DevOps/инфраструктурой)

```bash
# Just (современный подход)
just install
just dev-all

# Или Docker (production-ready)
docker-compose -f docker-compose.full.yml up -d
```

**Почему:** Just проще Make, Docker - для production.

---

## 🎯 Выбор по сценарию

### Сценарий 1: "Хочу просто попробовать"

```bash
# Shell script с интерактивными prompts
./quick-start.sh
```

**Время:** 30-50 минут  
**Сложность:** ⭐  
**Результат:** Работающая система

---

### Сценарий 2: "Буду активно разрабатывать"

```bash
# Make или Just
make install
make dev
make worker

# Или
just install
just dev-all
```

**Время:** 15 минут  
**Сложность:** ⭐⭐  
**Результат:** Удобная среда разработки

---

### Сценарий 3: "Нужна быстрая установка без вопросов"

```bash
# npm scripts
npm run install:full
npm run start:dev
```

**Время:** 10 минут  
**Сложность:** ⭐  
**Результат:** Быстрый старт

---

### Сценарий 4: "Готовлю production deployment"

```bash
# Docker
docker-compose -f docker-compose.full.yml up -d
```

**Время:** 30-60 минут (build)  
**Сложность:** ⭐⭐⭐  
**Результат:** Production-ready environment

---

## 🎨 Что есть в проекте

| Инструмент | Файлы | Статус |
|------------|-------|--------|
| **npm scripts** | `package.json` | ✅ Полный набор |
| **Make** | `Makefile`, `gpu-worker/Makefile` | ✅ Для обеих частей |
| **Just** | `Justfile` | ✅ Для main app |
| **Shell Scripts** | `*.sh`, `*.bat` | ✅ Linux/macOS/Windows |
| **Docker** | `Dockerfile`, `docker-compose*.yml` | ✅ Полный стек |
| **Python Tools** | `pyproject.toml`, `setup.py` | ✅ Modern Python |

---

## 💡 Моя рекомендация

### Для стационарного ПК (Windows):

```cmd
REM Самый простой способ
cd gpu-worker
install.bat
start.bat
```

**Почему:**
- Windows batch script проще запустить
- Не требует WSL
- Интерактивный процесс

### Для стационарного ПК (Linux/macOS):

```bash
# Make - стандарт
cd gpu-worker
make install
make start

# Или shell script
./install.sh
./start.sh
```

**Почему:**
- Make уже установлен
- Знаком большинству разработчиков
- Отличное управление зависимостями

### Для ноутбука:

```bash
# Вариант 1: Make (классика)
make install
make dev      # Terminal 1
make worker   # Terminal 2

# Вариант 2: Just (modern)
just install
just dev-all  # Автоматически в tmux

# Вариант 3: npm (проще всего)
npm run install:full
npm run start:dev
```

**Почему:** 
- Make/Just - удобные для разработки
- npm - если не хотите устанавливать доп. инструменты

---

## 🚀 Практический совет

**Используйте комбинацию:**

1. **Первая установка:** Shell scripts
   ```bash
   ./quick-start.sh  # Интерактивный процесс
   ```

2. **Ежедневная работа:** Make/Just
   ```bash
   make dev          # Быстрый запуск
   make test         # Тесты
   make clean        # Очистка
   ```

3. **Quick commands:** npm scripts
   ```bash
   npm run health    # Health check
   npm run docker:ps # Статус Docker
   ```

4. **Production:** Docker
   ```bash
   docker-compose -f docker-compose.full.yml up -d
   ```

---

## ✅ Итоговая таблица

| Метод | Первая установка | Разработка | Production | Автоматизация |
|-------|-----------------|------------|------------|---------------|
| **npm** | ⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐ |
| **Make** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Just** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Shell** | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ |
| **Docker** | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

**Легенда:** ⭐ = хуже, ⭐⭐⭐⭐⭐ = лучше

---

## 🎯 Окончательная рекомендация

### ✅ Используйте Make + Shell Scripts

**Почему:**
- ✅ Make - стандарт индустрии (работает везде)
- ✅ Shell scripts - для first-time setup
- ✅ npm scripts - уже интегрированы
- ✅ Не требует установки Just (один инструмент меньше)
- ✅ Docker - опционально для production

### Практический workflow:

```bash
# === ПЕРВАЯ УСТАНОВКА ===
# Используйте shell script для интерактивной установки
./install.sh

# === ЕЖЕДНЕВНОЕ ИСПОЛЬЗОВАНИЕ ===
# Используйте Make для быстрых команд
make dev
make worker
make test

# === PRODUCTION ===
# Используйте Docker
docker-compose -f docker-compose.full.yml up -d
```

---

## 📝 Вывод

**Да, вы правы!** Shell scripts хороши для первой установки, но для ежедневной работы лучше использовать:

1. **Make** - главный инструмент (есть везде, проверен временем)
2. **npm scripts** - для Node.js задач (уже есть)
3. **pyproject.toml** - для Python части (современный стандарт)
4. **Docker** - для production deployment

**Shell scripts оставляем для:**
- Первой установки (интерактивный процесс)
- CI/CD pipelines
- Автоматизации без user interaction

---

**Теперь у вас есть все инструменты - выбирайте то что удобно!** 🎉

**Quick reference:**
- `make help` - список всех команд
- `just` - список Just команд
- `npm run` - список npm scripts
- `./install.sh` - первая установка
