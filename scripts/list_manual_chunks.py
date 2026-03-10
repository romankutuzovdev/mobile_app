#!/usr/bin/env python3
"""Вывести чанки мануала из БД. manual_id — UUID из ответа загрузки."""

import asyncio
import os
import sys
import uuid
from pathlib import Path

# Добавляем корень проекта в path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import select, text
from app.database import AsyncSessionLocal
from app.models.manual import ManualChunk


async def main():
    manual_id_str = sys.argv[1] if len(sys.argv) > 1 else "af547654-3e08-46e7-94f5-5c075ff549ea"
    try:
        manual_id = uuid.UUID(manual_id_str)
    except ValueError:
        print(f"Неверный UUID: {manual_id_str}")
        sys.exit(1)

    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(ManualChunk)
            .where(ManualChunk.manual_id == manual_id)
            .order_by(ManualChunk.id)
        )
        chunks = result.scalars().all()

    print(f"Чанков в БД: {len(chunks)}\n")
    print("=" * 80)
    for i, c in enumerate(chunks, 1):
        preview = (c.content[:250] + "...") if len(c.content) > 250 else c.content
        preview = preview.replace("\n", " ")
        emb_preview = (c.embedding_id[:24] + "...") if len(c.embedding_id) > 24 else c.embedding_id
        print(f"\n--- Чанк {i} (id={c.id}, len={len(c.content)}, embedding_id={emb_preview}) ---")
        print(preview)
    print("\n" + "=" * 80)
    print(f"Всего: {len(chunks)} чанков")


if __name__ == "__main__":
    asyncio.run(main())
