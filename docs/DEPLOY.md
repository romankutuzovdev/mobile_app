# Развёртывание бекенда на сервере

## Требования

- Ubuntu 20.04+ / Debian 11+ (или другой Linux с Docker)
- Docker и Docker Compose
- Доступ по SSH

## Быстрый старт

```bash
# 1. Клонируйте/скопируйте проект на сервер
git clone <repo> /opt/auto-assistant
cd /opt/auto-assistant

# 2. Создайте .env
cp .env.production.example .env
nano .env   # Заполните SECRET_KEY, OPENAI_API_KEY, POSTGRES_PASSWORD

# 3. Запустите деплой
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

## Настройка .env

| Переменная | Описание |
|------------|----------|
| `POSTGRES_PASSWORD` | Пароль для PostgreSQL |
| `SECRET_KEY` | Ключ для JWT (сгенерируйте: `openssl rand -hex 32`) |
| `OPENAI_API_KEY` | Ключ OpenAI для чата и RAG |
| `ZYLA_KEY` | Ключ Zyla Labs для SMS (если используется) |

## Доступ к API

После деплоя API доступен по:

```
http://<IP_СЕРВЕРА>:8000
```

Пример для мобильного приложения: задайте `API_URL=http://192.168.1.100:8000` при сборке Flutter.

## Полезные команды

```bash
# Логи
docker compose -f docker-compose.prod.yml logs -f web

# Остановка
docker compose -f docker-compose.prod.yml down

# Перезапуск после изменений
./scripts/deploy.sh
```

## Открытие порта в файрволе (если используется ufw)

```bash
sudo ufw allow 8000/tcp
sudo ufw reload
```
