#!/bin/bash
# Загрузка мануала на сервере (внутри контейнера, без HTTP)
# Использование на сервере:
#   1. Скопировать PDF: scp file.pdf root@151.242.191.8:~/mobile_app/uploads/
#   2. Запустить: ./scripts/upload_on_server.sh uploads/filename.pdf

FILE="$1"
if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  echo "Использование: $0 путь/к/файлу.pdf"
  echo "Пример: $0 uploads/Chery_2008.pdf"
  exit 1
fi

cd "$(dirname "$0")/.."
CONTAINER="fastapi_web"
FNAME=$(basename "$FILE")
mkdir -p uploads

# Скопировать файл в контейнер
docker cp "$FILE" "$CONTAINER:/tmp/manual.pdf"

# Загрузить через Python (без HTTP — избегаем таймаутов)
# python -u = unbuffered, PYTHONDONTWRITEBYTECODE = не кэшировать .pyc
echo "Обработка PDF (парсинг + embedding чанков)... может занять 3-10 мин."
docker exec -e UPLOAD_FNAME="$FNAME" -e PYTHONUNBUFFERED=1 -e PYTHONDONTWRITEBYTECODE=1 "$CONTAINER" python -u -B -c "
import asyncio
import os
import sys
from pathlib import Path

async def run():
    try:
        sys.stderr.write('Загрузка модулей...\n')
        sys.stderr.flush()
        from app.database import AsyncSessionLocal
        from app.services.manual_service import ManualService
        from sqlalchemy import select
        from app.models.user import User

        sys.stderr.write('Подключение к БД...\n')
        sys.stderr.flush()
        async with AsyncSessionLocal() as db:
            r = await db.execute(select(User).order_by(User.id).limit(1))
            user = r.scalar_one_or_none()
            if not user:
                sys.stderr.write('Ошибка: нет пользователей в БД\n')
                sys.exit(1)
            content = Path('/tmp/manual.pdf').read_bytes()
            fn = os.environ.get('UPLOAD_FNAME', 'manual.pdf')
            title = fn.replace('_', ' ').replace('.pdf', '').replace('.docx', '').replace('.txt', '')
            sys.stderr.write('Обработка PDF и чанков (подождите)...\n')
            sys.stderr.flush()
            # Проверка: загружен ли код с _debug
            has_debug = hasattr(ManualService, '_debug')
            sys.stderr.write('[DEBUG] ManualService._debug: ' + ('есть (новый код)' if has_debug else 'НЕТ (обновите manual_service.py в контейнере!)') + '\n')
            sys.stderr.flush()
            m = await ManualService.upload_manual(db=db, file_content=content, filename=fn,
                title=title, car_id=None, user_id=user.id, use_ocr_for_pdf=False)
            sys.stderr.write('OK: ' + str(m.title) + ' | ' + str(m.brand) + ' ' + str(m.model) + ' ' + str(m.year) + '\n')
            sys.stderr.flush()
    except Exception as e:
        sys.stderr.write('Ошибка: ' + str(e) + '\n')
        sys.stderr.flush()
        import traceback
        traceback.print_exc()
        sys.exit(1)

asyncio.run(run())
"
