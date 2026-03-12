#!/bin/bash
# Локальная обработка PDF → запись напрямую в базу на сервере
# PDF парсится локально, эмбеддинги через OpenAI — данные пишутся в PostgreSQL и Qdrant на сервере
#
# Использование:
#   1. Убедитесь, что на Mac есть Python, зависимости (pip install -r requirements.txt)
#   2. Запустите: ./scripts/upload_local_to_server.sh /path/to/manual.pdf
#
# Требуется: SSH доступ к серверу, пароль PostgreSQL (из .env на сервере)

set -e
cd "$(dirname "$0")/.."

SERVER="${UPLOAD_SERVER:-root@151.242.191.8}"
PG_PASSWORD="${POSTGRES_PASSWORD:-postgres}"
# Порты для туннеля (меняйте при конфликте "Address already in use")
LOCAL_PG_PORT="${LOCAL_PG_PORT:-25433}"
LOCAL_QDRANT_PORT="${LOCAL_QDRANT_PORT:-26333}"

FILE="$1"
if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  echo "Использование: $0 путь/к/файлу.pdf"
  echo "Пример: $0 ~/Desktop/Mazda-CX7-2007-2009-Manual.pdf"
  exit 1
fi

echo "=== Локальная загрузка PDF на сервер ==="
echo "Файл: $FILE"
echo "Сервер: $SERVER"
echo ""

# Проверка зависимостей
if ! python3 -c "import asyncpg, qdrant_client, openai" 2>/dev/null; then
  echo "Установите зависимости: pip install -r requirements.txt"
  exit 1
fi

# Закрыть старые туннели на этих портах (если остались)
pkill -f "ssh -f -N.*${LOCAL_PG_PORT}:127.0.0.1:5433" 2>/dev/null || true
pkill -f "ssh -f -N.*${LOCAL_QDRANT_PORT}:127.0.0.1:6333" 2>/dev/null || true
sleep 1

# На сервере prod: PostgreSQL на 5433, Qdrant на 6333
# ServerAliveInterval — keepalive каждые 30 сек, туннель не рвётся при долгом парсинге
echo "Запуск SSH-туннеля (порты $LOCAL_PG_PORT, $LOCAL_QDRANT_PORT)..."
ssh -f -N -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=30 -o ServerAliveCountMax=120 \
  -L "${LOCAL_PG_PORT}:127.0.0.1:5433" \
  -L "${LOCAL_QDRANT_PORT}:127.0.0.1:6333" \
  "$SERVER" || {
  echo "Ошибка: не удалось создать SSH-туннель. Проверьте доступ к $SERVER"
  exit 1
}

# Завершить туннель при выходе
cleanup() {
  echo "Закрытие SSH-туннеля..."
  pkill -f "ssh -f -N.*${LOCAL_PG_PORT}:127.0.0.1:5433" 2>/dev/null || true
}
trap cleanup EXIT

sleep 2
echo "Туннель активен. Обработка PDF (может занять 5–15 мин для больших файлов)..."
echo ""

# Опционально: удалить мануал перед загрузкой (для повторной загрузки после ошибок)
# export DELETE_MANUAL_ID=c1581145-d1bf-456f-9a6c-22d54843413c
if [ -n "${DELETE_MANUAL_ID:-}" ]; then
  echo "Удаление предыдущего мануала $DELETE_MANUAL_ID..."
  DATABASE_URL="postgresql+asyncpg://postgres:${PG_PASSWORD}@127.0.0.1:${LOCAL_PG_PORT}/auto_db" \
  QDRANT_URL="http://127.0.0.1:${LOCAL_QDRANT_PORT}" \
  PYTHONPATH=. python3 scripts/delete_manual_and_reupload.py "$DELETE_MANUAL_ID" || true
  echo ""
fi

# Загрузка с подключением к серверу через туннель
# OPENAI_PROXY из .env используется автоматически (если нужен VPN/прокси для OpenAI)
DATABASE_URL="postgresql+asyncpg://postgres:${PG_PASSWORD}@127.0.0.1:${LOCAL_PG_PORT}/auto_db" \
QDRANT_URL="http://127.0.0.1:${LOCAL_QDRANT_PORT}" \
PYTHONPATH=. python3 scripts/upload_manual_direct.py "$FILE" --user-id 1

echo ""
echo "✓ Готово! Мануал загружен в базу на сервере."
