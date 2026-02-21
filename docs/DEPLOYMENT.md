# 🚀 Production Deployment Guide

Руководство по развертыванию Avatar Factory в production.

## 📋 Pre-deployment Checklist

### Безопасность
- [ ] Изменить все пароли и API ключи
- [ ] Настроить HTTPS (Let's Encrypt)
- [ ] Настроить firewall
- [ ] Включить rate limiting
- [ ] Добавить JWT аутентификацию
- [ ] Настроить CORS правильно
- [ ] Включить input validation
- [ ] Настроить backup стратегию

### Производительность
- [ ] Оптимизировать размеры изображений
- [ ] Включить CDN для статики
- [ ] Настроить кэширование
- [ ] Добавить мониторинг (Sentry)
- [ ] Настроить логирование
- [ ] Добавить health checks
- [ ] Настроить auto-scaling (если нужно)

### Инфраструктура
- [ ] Настроить production БД
- [ ] Настроить Redis cluster (если нужно)
- [ ] Настроить backup для MinIO
- [ ] Настроить CI/CD pipeline
- [ ] Добавить мониторинг серверов
- [ ] Настроить алерты

## 🔐 Безопасность

### 1. Измените все секреты

```bash
# Генерация случайных ключей
openssl rand -base64 32

# Обновите .env
GPU_API_KEY="новый-случайный-ключ"
NEXTAUTH_SECRET="новый-случайный-ключ"
DATABASE_PASSWORD="сложный-пароль"
MINIO_ACCESS_KEY="новый-ключ"
MINIO_SECRET_KEY="новый-секрет"
```

### 2. Настройте HTTPS

#### С Nginx

```nginx
# /etc/nginx/sites-available/avatar-factory
server {
    listen 80;
    server_name yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name yourdomain.com;
    
    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    
    # Frontend
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
    
    # MinIO
    location /storage/ {
        proxy_pass http://localhost:9000/;
        proxy_set_header Host $host;
    }
}
```

#### Let's Encrypt

```bash
# Установите certbot
sudo apt install certbot python3-certbot-nginx

# Получите сертификат
sudo certbot --nginx -d yourdomain.com

# Auto-renewal
sudo certbot renew --dry-run
```

### 3. Firewall

```bash
# Ubuntu/Debian
sudo ufw allow 22/tcp      # SSH
sudo ufw allow 80/tcp      # HTTP
sudo ufw allow 443/tcp     # HTTPS
sudo ufw enable

# Закройте прямой доступ к сервисам
sudo ufw deny 5432         # PostgreSQL
sudo ufw deny 6379         # Redis
sudo ufw deny 9000         # MinIO
sudo ufw deny 8001         # GPU Server (если в интернете)
```

## 🏗️ Deployment Options

### Option 1: Docker (Рекомендуется)

#### Dockerfile для Next.js

```dockerfile
# Dockerfile
FROM node:18-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci

FROM node:18-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npx prisma generate
RUN npm run build

FROM node:18-alpine AS runner
WORKDIR /app
ENV NODE_ENV production

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000
ENV PORT 3000

CMD ["node", "server.js"]
```

#### Docker Compose для Production

```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  # PostgreSQL
  postgres:
    image: postgres:16-alpine
    restart: always
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: avatar_factory
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backups:/backups
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5
  
  # Redis
  redis:
    image: redis:7-alpine
    restart: always
    command: redis-server --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5
  
  # MinIO
  minio:
    image: minio/minio:latest
    restart: always
    environment:
      MINIO_ROOT_USER: ${MINIO_ACCESS_KEY}
      MINIO_ROOT_PASSWORD: ${MINIO_SECRET_KEY}
    volumes:
      - minio_data:/data
    command: server /data --console-address ":9001"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3
  
  # Next.js App
  app:
    build:
      context: .
      dockerfile: Dockerfile
    restart: always
    depends_on:
      - postgres
      - redis
      - minio
    environment:
      DATABASE_URL: ${DATABASE_URL}
      REDIS_URL: ${REDIS_URL}
      GPU_SERVER_URL: ${GPU_SERVER_URL}
    ports:
      - "3000:3000"
  
  # Worker
  worker:
    build:
      context: .
      dockerfile: Dockerfile
    restart: always
    depends_on:
      - postgres
      - redis
      - minio
    environment:
      DATABASE_URL: ${DATABASE_URL}
      REDIS_URL: ${REDIS_URL}
      GPU_SERVER_URL: ${GPU_SERVER_URL}
    command: ["node", "workers/video-worker.js"]
  
  # Nginx
  nginx:
    image: nginx:alpine
    restart: always
    depends_on:
      - app
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
      - letsencrypt:/etc/letsencrypt

volumes:
  postgres_data:
  redis_data:
  minio_data:
  letsencrypt:
```

### Option 2: Традиционный деплой

#### Systemd Service для Next.js

```ini
# /etc/systemd/system/avatar-factory.service
[Unit]
Description=Avatar Factory Next.js App
After=network.target postgresql.service redis.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/avatar-factory
Environment="NODE_ENV=production"
EnvironmentFile=/var/www/avatar-factory/.env
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

#### Systemd Service для Worker

```ini
# /etc/systemd/system/avatar-factory-worker.service
[Unit]
Description=Avatar Factory Worker
After=network.target postgresql.service redis.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/avatar-factory
Environment="NODE_ENV=production"
EnvironmentFile=/var/www/avatar-factory/.env
ExecStart=/usr/bin/npm run worker
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

#### Запуск

```bash
sudo systemctl enable avatar-factory avatar-factory-worker
sudo systemctl start avatar-factory avatar-factory-worker
sudo systemctl status avatar-factory avatar-factory-worker
```

### Option 3: Vercel (только Frontend)

```bash
# Build
npm run build

# Deploy
vercel --prod

# Настройте environment variables в Vercel Dashboard
```

**Важно:** Worker и GPU сервер должны быть на отдельном сервере.

## 💾 Backup Strategy

### PostgreSQL Backup

```bash
#!/bin/bash
# /usr/local/bin/backup-postgres.sh

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/postgres"
mkdir -p $BACKUP_DIR

pg_dump -U avatar avatar_factory | gzip > $BACKUP_DIR/backup_$DATE.sql.gz

# Удалить старые бэкапы (старше 30 дней)
find $BACKUP_DIR -name "backup_*.sql.gz" -mtime +30 -delete
```

### MinIO Backup

```bash
#!/bin/bash
# /usr/local/bin/backup-minio.sh

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/minio"
mkdir -p $BACKUP_DIR

# Используем mc (MinIO Client)
mc mirror myminio/avatar-videos $BACKUP_DIR/$DATE

# Удалить старые бэкапы
find $BACKUP_DIR -type d -mtime +30 -exec rm -rf {} +
```

### Cron Jobs

```bash
# crontab -e
0 2 * * * /usr/local/bin/backup-postgres.sh
0 3 * * * /usr/local/bin/backup-minio.sh
```

## 📊 Мониторинг

### Health Checks

```bash
# Скрипт для мониторинга
#!/bin/bash
# /usr/local/bin/health-check.sh

FRONTEND_URL="https://yourdomain.com/api/health"
GPU_URL="http://gpu-server:8001/health"

# Проверка frontend
if ! curl -f -s $FRONTEND_URL > /dev/null; then
    echo "ALERT: Frontend is down!" | mail -s "Avatar Factory Alert" admin@yourdomain.com
fi

# Проверка GPU server
if ! curl -f -s $GPU_URL > /dev/null; then
    echo "ALERT: GPU Server is down!" | mail -s "Avatar Factory Alert" admin@yourdomain.com
fi
```

### Sentry Integration

```bash
npm install @sentry/nextjs
```

```typescript
// sentry.client.config.ts
import * as Sentry from "@sentry/nextjs";

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  tracesSampleRate: 0.1,
  environment: process.env.NODE_ENV,
});
```

### Prometheus + Grafana (опционально)

```yaml
# docker-compose.monitoring.yml
services:
  prometheus:
    image: prom/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"
  
  grafana:
    image: grafana/grafana
    ports:
      - "3001:3000"
    environment:
      GF_SECURITY_ADMIN_PASSWORD: admin
```

## 🚀 CI/CD Pipeline

### GitHub Actions

```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run tests
        run: npm test
      
      - name: Build
        run: npm run build
      
      - name: Deploy to server
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.SERVER_HOST }}
          username: ${{ secrets.SERVER_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /var/www/avatar-factory
            git pull origin main
            npm install --production
            npm run build
            systemctl restart avatar-factory
```

## 📈 Масштабирование

### Horizontal Scaling (Workers)

Запустите несколько worker процессов:

```bash
# Systemd template
# /etc/systemd/system/avatar-factory-worker@.service

[Unit]
Description=Avatar Factory Worker %i
After=network.target

[Service]
Type=simple
WorkingDirectory=/var/www/avatar-factory
ExecStart=/usr/bin/npm run worker
Restart=always

[Install]
WantedBy=multi-user.target

# Запуск 3 workers
systemctl enable avatar-factory-worker@{1..3}
systemctl start avatar-factory-worker@{1..3}
```

### Load Balancing

```nginx
# Nginx load balancing
upstream avatar_app {
    least_conn;
    server localhost:3000;
    server localhost:3001;
    server localhost:3002;
}

server {
    listen 443 ssl;
    server_name yourdomain.com;
    
    location / {
        proxy_pass http://avatar_app;
    }
}
```

## 💰 Cost Optimization

### Стоимость Production

**VPS (App + DB + Redis):**
- Hetzner CPX31: €10-15/мес (4 vCPU, 8GB RAM)
- DigitalOcean: $24/мес (4 vCPU, 8GB RAM)

**Стационарный ПК (GPU):**
- Электричество: $5-10/мес
- Интернет: уже есть

**Домен + SSL:**
- Домен: $10-15/год
- SSL: бесплатно (Let's Encrypt)

**Итого: ~$30-50/мес**

vs платные API: **$100-500/мес** 💸

## 🔧 Maintenance

### Daily Tasks
- Проверка логов
- Мониторинг метрик
- Проверка disk space

### Weekly Tasks
- Проверка backups
- Анализ ошибок
- Обновление зависимостей (security)

### Monthly Tasks
- Full backup test (restore)
- Performance review
- Cost analysis

## 📞 Support & Monitoring

### Alerts Setup

```bash
# Telegram bot для алертов
# Install telegram-send
pip install telegram-send
telegram-send --configure

# Алерт скрипт
#!/bin/bash
if ! curl -f -s https://yourdomain.com/api/health; then
    telegram-send "🚨 Avatar Factory is DOWN!"
fi
```

### Log Rotation

```bash
# /etc/logrotate.d/avatar-factory
/var/log/avatar-factory/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data www-data
    sharedscripts
    postrotate
        systemctl reload avatar-factory > /dev/null
    endscript
}
```

---

## 🎉 Post-Deployment

После деплоя проверьте:

- [ ] Все сервисы запущены
- [ ] Health check возвращает OK
- [ ] Можно создать тестовое видео
- [ ] Backups работают
- [ ] Мониторинг настроен
- [ ] SSL сертификат валиден
- [ ] Логи пишутся корректно

**Готово!** Ваша система в production 🚀

Если что-то пошло не так - проверьте логи:
```bash
journalctl -u avatar-factory -f
docker-compose logs -f
tail -f /var/log/nginx/error.log
```
