#!/usr/bin/env python3
"""
Локальная загрузка мануала без API (для разработки).
Создаёт запись в каталоге и загружает мануал, привязывая к user_id.

Использование:
  cd /path/to/mobile_app
  PYTHONPATH=. python3 scripts/upload_manual_direct.py /path/to/file.pdf [--user-id 1]

  # По умолчанию user_id=1 (первый пользователь в БД)
"""
import argparse
import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.database import AsyncSessionLocal
from app.services.manual_service import ManualService
from sqlalchemy import select
from app.models.user import User


async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("file", type=Path, help="PDF/DOCX/TXT файл мануала")
    parser.add_argument("--user-id", "-u", type=int, default=1, help="ID пользователя (по умолчанию 1)")
    parser.add_argument("--force-ocr", action="store_true", help="Для PDF: принудительный OCR")
    args = parser.parse_args()

    if not args.file.exists():
        print(f"Ошибка: файл не найден: {args.file}")
        sys.exit(1)

    async with AsyncSessionLocal() as db:
        result = await db.execute(select(User).where(User.id == args.user_id))
        user = result.scalar_one_or_none()
        if not user:
            print(f"Ошибка: пользователь с id={args.user_id} не найден")
            sys.exit(1)

        filename = args.file.name
        title = filename.replace("_", " ").replace(".pdf", "").replace(".docx", "").replace(".txt", "")

        print(f"Загрузка: {filename}")
        print(f"Пользователь: {user.phone or user.email or user.username} (id={args.user_id})")
        print("(Обработка может занять несколько минут для PDF)...")

        try:
            file_content = args.file.read_bytes()
            manual = await ManualService.upload_manual(
                db=db,
                file_content=file_content,
                filename=filename,
                title=title,
                car_id=None,
                user_id=args.user_id,
                use_ocr_for_pdf=args.force_ocr,
            )
            print(f"\n✓ Готово! Мануал добавлен в глобальный каталог")
            print(f"  Название: {manual.title}")
            print(f"  ID: {manual.id}")
            print(f"  {manual.brand} {manual.model} ({manual.year})")
        except Exception as e:
            print(f"Ошибка: {e}")
            sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
