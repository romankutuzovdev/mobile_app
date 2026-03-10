#!/bin/bash
# Скрипт развёртывания бекенда на сервере
# Использование: ./scripts/deploy.sh
# После запуска API доступен по http://<IP_СЕРВЕРА>:8000

set -e
cd "$(dirname "$0")/.."
PROJECT_ROOT="$(pwd)"

echo "=== Деплой AI Auto Assistant Backend ==="

# 1. Проверка Docker
if ! command -v docker &> /dev/null; then
    echo "Docker не установлен. Установите Docker: https://docs.docker.com/engine/install/"
    echo ""
    echo "Для Ubuntu/Debian:"
    echo "  curl -fsSL https://get.docker.com | sh"
    echo "  sudo usermod -aG docker \$USER"
    echo "  # Перелогиньтесь и запустите скрипт снова"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo "Docker Compose не найден. Установите: https://docs.docker.com/compose/install/"
    exit 1
fi

# 2. Создание .env если нет
if [ ! -f .env ]; then
    echo ""
    echo "Файл .env не найден. Создаю из .env.production.example..."
    if [ -f .env.production.example ]; then
        cp .env.production.example .env
        echo "Создан .env. ОТРЕДАКТИРУЙТЕ его (SECRET_KEY, OPENAI_API_KEY, POSTGRES_PASSWORD) и запустите скрипт снова."
        echo ""
        echo "  nano .env"
        echo "  ./scripts/deploy.sh"
        exit 1
    else
        echo "Ошибка: .env.production.example не найден"
        exit 1
    fi
fi

# 3. Проверка обязательных переменных
source .env 2>/dev/null || true
if [ -z "$SECRET_KEY" ] || [ "$SECRET_KEY" = "your-very-long-random-secret-key-min-32-chars" ]; then
    echo ""
    echo "ВНИМАНИЕ: Задайте SECRET_KEY в .env для продакшена!"
    echo "  openssl rand -hex 32"
    echo ""
fi

# 4. Сборка и запуск
echo ""
echo "Сборка и запуск контейнеров..."
docker compose -f docker-compose.prod.yml build --no-cache
docker compose -f docker-compose.prod.yml up -d

# 5. Ожидание запуска
echo ""
echo "Ожидание готовности сервисов..."
sleep 10

# Проверка health
if docker compose -f docker-compose.prod.yml ps | grep -q "fastapi_web"; then
    echo ""
    echo "=== Деплой завершён ==="
    echo ""
    echo "API доступен по адресу:"
    echo "  http://\$(hostname -I | awk '{print \$1}'):8000"
    echo "  http://localhost:8000"
    echo ""
    echo "Полезные эндпоинты:"
    echo "  GET  /          - приветствие"
    echo "  GET  /health    - проверка здоровья"
    echo "  GET  /docs      - Swagger UI"
    echo ""
    echo "Управление:"
    echo "  docker compose -f docker-compose.prod.yml logs -f web  # логи"
    echo "  docker compose -f docker-compose.prod.yml down         # остановить"
else
    echo ""
    echo "Возможная ошибка. Проверьте логи:"
    echo "  docker compose -f docker-compose.prod.yml logs"
    exit 1
fi
