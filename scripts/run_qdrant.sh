#!/bin/bash
# Установка и запуск Qdrant на macOS (без Docker)
# Qdrant 1.11+ требует --uri и --config-path

set -e
VERSION="v1.11.2"
BIN_DIR="${BIN_DIR:-$(cd "$(dirname "$0")/.." && pwd)/.qdrant_bin}"
QDRANT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STORAGE_DIR="${QDRANT_STORAGE:-$QDRANT_DIR/.qdrant_storage}"
SNAPSHOTS_DIR="$STORAGE_DIR/snapshots"
CONFIG_FILE="$QDRANT_DIR/config/qdrant_local.yaml"
ARCH=$(uname -m)

case "$ARCH" in
  arm64|aarch64)  TARBALL="qdrant-aarch64-apple-darwin.tar.gz" ;;
  x86_64)         TARBALL="qdrant-x86_64-apple-darwin.tar.gz" ;;
  *) echo "Неподдерживаемая архитектура: $ARCH"; exit 1 ;;
esac

URL="https://github.com/qdrant/qdrant/releases/download/$VERSION/$TARBALL"
QDRANT_BIN="$BIN_DIR/qdrant"

mkdir -p "$BIN_DIR" "$STORAGE_DIR" "$SNAPSHOTS_DIR" "$(dirname "$CONFIG_FILE")"

if [ ! -f "$QDRANT_BIN" ] || [ "$1" = "--update" ]; then
  echo "Скачивание Qdrant $VERSION ($TARBALL)..."
  curl -sL "$URL" -o /tmp/qdrant.tar.gz
  tar -xzf /tmp/qdrant.tar.gz -C /tmp
  mv /tmp/qdrant "$QDRANT_BIN"
  rm -f /tmp/qdrant.tar.gz
  chmod +x "$QDRANT_BIN"
  echo "Qdrant установлен: $QDRANT_BIN"
fi

# Создаём конфиг с путями
cat > "$CONFIG_FILE" << EOF
log_level: INFO
storage:
  storage_path: $STORAGE_DIR
  snapshots_path: $SNAPSHOTS_DIR
service:
  host: 0.0.0.0
  http_port: 6333
  grpc_port: 6334
  enable_cors: true
cluster:
  enabled: false
telemetry_disabled: true
EOF

echo "Запуск Qdrant на http://localhost:6333"
echo "Хранилище: $STORAGE_DIR"
exec "$QDRANT_BIN" --uri "http://localhost:6333" --config-path "$CONFIG_FILE" --disable-telemetry
