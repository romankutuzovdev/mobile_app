#!/bin/bash
# Вариант 2: Полностью локальная обработка → экспорт → импорт на сервер
# ВНИМАНИЕ: Импорт ЗАМЕНЯЕТ коллекцию Qdrant и данные в PostgreSQL на сервере!
# Используйте для первоначальной загрузки или полной синхронизации.
# Для добавления ОДНОГО мануала к существующим — лучше upload_local_to_server.sh
#
# Шаг 1 (локально): Обработать PDF и экспортировать
#   ./scripts/export_and_import_vector_db.sh export /path/to/file.pdf
#
# Шаг 2: Скопировать экспорт на сервер
#   scp -r ./export_vector_db root@151.242.191.8:~/mobile_app/
#
# Шаг 3 (на сервере): Импортировать
#   ./scripts/export_and_import_vector_db.sh import

set -e
cd "$(dirname "$0")/.."

EXPORT_DIR="./export_vector_db"
SERVER="${UPLOAD_SERVER:-root@151.242.191.8}"

export_data() {
  local FILE="$1"
  if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    echo "Использование: $0 export путь/к/файлу.pdf"
    exit 1
  fi

  echo "=== Шаг 1: Локальная обработка PDF ==="
  echo "Требуется: локальный Docker (postgres, qdrant) или docker-compose"
  echo "Файл: $FILE"
  echo ""

  # Проверяем, что локальный стек запущен
  if ! curl -s http://localhost:6333/collections 2>/dev/null | grep -q collections; then
    echo "Запустите локально: docker compose up -d"
    echo "Или: docker run -d -p 6333:6333 -p 5432:5432 ... (postgres + qdrant)"
    exit 1
  fi

  mkdir -p "$EXPORT_DIR"
  rm -rf "$EXPORT_DIR"/*

  # Обработка PDF (пишем в локальные БД)
  # Локальный docker-compose: postgres на 5432, qdrant на 6333
  echo "Обработка PDF..."
  DATABASE_URL="postgresql+asyncpg://postgres:postgres@127.0.0.1:5432/auto_db" \
  QDRANT_URL="http://127.0.0.1:6333" \
  PYTHONPATH=. python3 scripts/upload_manual_direct.py "$FILE" --user-id 1

  # Экспорт Qdrant snapshot
  echo "Создание снапшота Qdrant..."
  SNAP_RESP=$(curl -s -X POST "http://localhost:6333/collections/manual_chunks/snapshots?wait=true")
  SNAP=$(echo "$SNAP_RESP" | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)
  if [ -z "$SNAP" ]; then
    echo "Ошибка: коллекция manual_chunks пуста или не существует."
    echo "Сначала обработайте PDF локально (docker compose up -d, затем upload_manual_direct.py)"
    exit 1
  fi
  curl -s "http://localhost:6333/collections/manual_chunks/snapshots/$SNAP" -o "$EXPORT_DIR/manual_chunks.snapshot"
  echo "  Снапшот: $SNAP"

  # Экспорт PostgreSQL (только manuals и manual_chunks)
  echo "Экспорт PostgreSQL..."
  if docker exec fastapi_db pg_dump -U postgres -t manuals -t manual_chunks --data-only auto_db 2>/dev/null > "$EXPORT_DIR/manuals_data.sql"; then
    echo "  pg_dump через docker"
  elif pg_dump -h localhost -p 5432 -U postgres -t manuals -t manual_chunks --data-only auto_db 2>/dev/null > "$EXPORT_DIR/manuals_data.sql"; then
    echo "  pg_dump локально"
  else
    echo "Не удалось выполнить pg_dump. Убедитесь, что PostgreSQL запущен (docker compose up -d)."
    exit 1
  fi

  echo "✓ Экспорт в $EXPORT_DIR"
  echo "  - manual_chunks.snapshot (Qdrant)"
  echo "  - manuals_data.sql (PostgreSQL)"
  echo ""
  echo "Далее: scp -r $EXPORT_DIR $SERVER:~/mobile_app/"
}

import_data() {
  echo "=== Импорт на сервер ==="
  if [ ! -f "$EXPORT_DIR/manual_chunks.snapshot" ] || [ ! -f "$EXPORT_DIR/manuals_data.sql" ]; then
    echo "Файлы экспорта не найдены в $EXPORT_DIR"
    echo "Скопируйте папку с сервера: scp -r $SERVER:~/mobile_app/$EXPORT_DIR ."
    exit 1
  fi

  # Восстановление Qdrant (загрузить снапшот)
  echo "Восстановление Qdrant из снапшота..."
  curl -X POST "http://localhost:6333/collections/manual_chunks/snapshots/upload?wait=true" \
    -F "snapshot=@$EXPORT_DIR/manual_chunks.snapshot" || {
    echo "Ошибка загрузки снапшота. Qdrant запущен? (docker ps | grep qdrant)"
    exit 1
  }

  # Восстановление PostgreSQL
  echo "Восстановление PostgreSQL..."
  docker exec -i fastapi_db psql -U postgres auto_db 2>/dev/null < "$EXPORT_DIR/manuals_data.sql" || \
  docker exec -i fastapi_db psql -U postgres auto_db < "$EXPORT_DIR/manuals_data.sql"

  echo "✓ Импорт завершён"
}

case "${1:-}" in
  export) export_data "$2" ;;
  import) import_data ;;
  *)
    echo "Использование:"
    echo "  $0 export /path/to/file.pdf   # Локально: обработать и экспортировать"
    echo "  $0 import                     # На сервере: импортировать"
    exit 1
    ;;
esac
