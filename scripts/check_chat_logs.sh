#!/bin/bash
# Диагностика логов чата — почему 502 и ошибки с AI
# Запуск на сервере: ./scripts/check_chat_logs.sh

CONTAINER="${1:-fastapi_web}"
LINES="${2:-200}"

echo "=== Последние $LINES строк логов $CONTAINER (chat, ChatGPT, 502, CHAT) ==="
echo ""

docker logs --tail "$LINES" "$CONTAINER" 2>&1 | grep -E "chat|ChatGPT|502|CHAT|OpenAI|OPENAI|proxy|Ошибка|Error" || docker logs --tail "$LINES" "$CONTAINER" 2>&1

echo ""
echo "=== Проверка .env (OPENAI_API_KEY, OPENAI_PROXY) на сервере ==="
if [ -f .env ]; then
  grep -E "^OPENAI_|^# OPENAI" .env | sed 's/sk-[^.]*\./sk-***./g'
else
  echo ".env не найден в текущей директории"
fi

echo ""
echo "=== Тест доступа к OpenAI с сервера ==="
docker exec "$CONTAINER" python -c "
import os
import sys
from app.config import settings
key = getattr(settings, 'OPENAI_API_KEY', '') or ''
print('OPENAI_API_KEY:', 'задан' if key and len(key) > 10 else 'НЕ ЗАДАН или пустой')
print('OPENAI_PROXY:', getattr(settings, 'OPENAI_PROXY', None) or '(не задан)')
print('OPENAI_MODEL:', getattr(settings, 'OPENAI_MODEL', '?'))
" 2>/dev/null || echo "Не удалось выполнить проверку"
