#!/usr/bin/env python3
"""Удалить все мануалы, кроме привязанных к car_id=9."""

import argparse
import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import select
from app.database import AsyncSessionLocal
from app.models.manual import Manual
from app.repositories.manual_repository import ManualRepository
from app.repositories.qdrant_repository import QdrantRepository


async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("car_id", type=int, nargs="?", default=12, help="Оставить мануалы с этим car_id (по умолчанию 12)")
    parser.add_argument("--db-only", action="store_true", help="Только PostgreSQL, не трогать Qdrant")
    args = parser.parse_args()

    keep_car_id = args.car_id
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(Manual).where(Manual.car_id != keep_car_id)
        )
        to_delete = list(result.scalars().all())
        result2 = await db.execute(select(Manual).where(Manual.car_id.is_(None)))
        to_delete += [m for m in result2.scalars().all() if m not in to_delete]

    print(f"Мануалы для удаления (все кроме car_id={keep_car_id}): {len(to_delete)}")
    for m in to_delete:
        print(f"  - {m.id}: {m.title} (car_id={m.car_id})")

    for m in to_delete:
        if not args.db_only:
            try:
                qdrant = QdrantRepository()
                await qdrant.delete_by_manual_id(m.id)
                print(f"Qdrant: удалены векторы для {m.title}")
            except Exception as e:
                print(f"Qdrant недоступен: {e}. Используйте --db-only для удаления только из БД.")
                sys.exit(1)
        async with AsyncSessionLocal() as db:
            await ManualRepository.delete_manual(db, m.id)
        print(f"Удалён: {m.title}")

    print("Готово.")


if __name__ == "__main__":
    asyncio.run(main())
