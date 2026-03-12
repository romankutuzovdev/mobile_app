#!/usr/bin/env python3
"""
Удаление мануала из PostgreSQL и Qdrant (для повторной загрузки после ошибок).
Используется тот же DATABASE_URL и QDRANT_URL, что и upload_local_to_server.sh.

Использование (с туннелем):
  # Сначала запустите туннель в отдельном терминале:
  # ssh -f -N -L 25433:127.0.0.1:5433 -L 26333:127.0.0.1:6333 root@151.242.191.8

  DATABASE_URL="postgresql+asyncpg://postgres:postgres@127.0.0.1:25433/auto_db" \
  QDRANT_URL="http://127.0.0.1:26333" \
  PYTHONPATH=. python3 scripts/delete_manual_and_reupload.py c1581145-d1bf-456f-9a6c-22d54843413c

Или через upload_local_to_server.sh — он запускает туннель и передаёт переменные.
"""
import asyncio
import sys
from pathlib import Path
from uuid import UUID

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.database import AsyncSessionLocal
from app.services.manual_service import ManualService
from app.repositories.manual_repository import ManualRepository


async def main():
    if len(sys.argv) < 2:
        print("Использование: python delete_manual_and_reupload.py <manual_id>")
        print("Пример: python delete_manual_and_reupload.py c1581145-d1bf-456f-9a6c-22d54843413c")
        sys.exit(1)

    manual_id = UUID(sys.argv[1])

    async with AsyncSessionLocal() as db:
        manual = await ManualRepository.get_manual_by_id(db, manual_id)
        if not manual:
            print(f"Мануал {manual_id} не найден в PostgreSQL.")
            sys.exit(1)

        print(f"Найден: {manual.title} ({manual.brand} {manual.model} {manual.year})")
        chunks = await ManualRepository.get_chunks_by_manual_id(db, manual_id)
        print(f"Чанков в PostgreSQL: {len(chunks)}")

        # Удаляем из Qdrant и PostgreSQL (ManualService делает оба)
        ok = await ManualService.delete_manual(db, manual_id)
        if ok:
            print("Удалено из Qdrant и PostgreSQL.")
        else:
            print("Ошибка удаления.")
        print(f"\n✓ Мануал {manual_id} удалён. Можно загружать заново с VPN.")
        print("  ./scripts/upload_local_to_server.sh /path/to/Mazda-CX7-2007-2009-Factory-Workshop-Manual.pdf")


if __name__ == "__main__":
    asyncio.run(main())
