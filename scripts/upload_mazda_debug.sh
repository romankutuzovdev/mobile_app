#!/bin/bash
# Загрузка Mazda CX7 мануала с отладочным выводом процесса
# Использование: ./scripts/upload_mazda_debug.sh

set -e
cd "$(dirname "$0")/.."

SERVER="root@151.242.191.8"
REMOTE_DIR="~/mobile_app"
# Можно передать путь как аргумент: ./scripts/upload_mazda_debug.sh /путь/к/file.pdf
LOCAL_PDF="${1:-/Users/admin/Desktop/2010-cx-7-owners-manual.pdf}"
REMOTE_PDF="uploads/$(basename "$LOCAL_PDF")"

if [ ! -f "$LOCAL_PDF" ]; then
  echo "Файл не найден: $LOCAL_PDF"
  exit 1
fi

echo "=== 1. Синхронизация изменённого кода (отладочный вывод) на сервер ==="
scp -q app/services/manual_service.py "$SERVER:$REMOTE_DIR/app/services/"
scp -q app/repositories/qdrant_repository.py "$SERVER:$REMOTE_DIR/app/repositories/"
scp -q scripts/upload_on_server.sh "$SERVER:$REMOTE_DIR/scripts/"

echo "=== 2. Копирование PDF на сервер ==="
scp "$LOCAL_PDF" "$SERVER:$REMOTE_DIR/$REMOTE_PDF"

echo "=== 3. Копирование обновлённого кода в контейнер и запуск загрузки ==="
echo "---"
ssh "$SERVER" "
  cd $REMOTE_DIR
  mkdir -p uploads
  docker cp app/services/manual_service.py fastapi_web:/app/app/services/ 2>/dev/null || true
  docker cp app/repositories/qdrant_repository.py fastapi_web:/app/app/repositories/ 2>/dev/null || true
  ./scripts/upload_on_server.sh $REMOTE_PDF
"
echo "---"
echo "Готово."
