#!/usr/bin/env python3
"""
Диагностика мануалов и автомобилей.
Проверяет: мануалы без привязки (car_id=NULL), машины без мануалов, дубликаты.

Запуск: cd /path/to/mobile_app && PYTHONPATH=. python3 scripts/check_manuals_cars.py
"""
import asyncio
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from app.database import AsyncSessionLocal
from sqlalchemy import text


async def main():
    async with AsyncSessionLocal() as db:
        # Мануалы без привязки (orphaned)
        r = await db.execute(
            text("SELECT id, title, source_file, car_id FROM manuals WHERE car_id IS NULL")
        )
        orphaned = list(r.fetchall())
        print("=" * 60)
        print("Мануалы без привязки (car_id = NULL):")
        print("=" * 60)
        if not orphaned:
            print("  Нет.")
        else:
            for row in orphaned:
                print(f"  id={row[0]}  title={row[1][:50]}...  car_id={row[3]}")

        # Машины с мануалами
        r2 = await db.execute(
            text("""
                SELECT c.id, c.brand, c.model, c.year, c.user_id,
                       (SELECT COUNT(*) FROM manuals m WHERE m.car_id = c.id) as manual_count
                FROM cars c
                ORDER BY c.id
            """)
        )
        cars = list(r2.fetchall())
        print("\n" + "=" * 60)
        print("Автомобили и количество мануалов:")
        print("=" * 60)
        for row in cars:
            count = row[5] or 0
            flag = " ⚠️ без мануалов" if count == 0 else f" ✓ {count} мануал(ов)"
            print(f"  id={row[0]}  {row[1]} {row[2]} ({row[3]})  user_id={row[4]}{flag}")

        # Привязка: мануалы и их машины
        r3 = await db.execute(
            text("SELECT m.id, m.title, m.car_id, c.brand, c.model FROM manuals m LEFT JOIN cars c ON m.car_id = c.id")
        )
        manuals = list(r3.fetchall())
        print("\n" + "=" * 60)
        print("Все мануалы и привязки:")
        print("=" * 60)
        for row in manuals:
            car_info = f"{row[3]} {row[4]}" if row[3] else "(машина удалена или не указана)"
            print(f"  manual_id={row[0]}  car_id={row[2]}  car={car_info}")
            print(f"    title: {row[1][:60]}...")

        if orphaned:
            print("\n" + "=" * 60)
            print("Чтобы привязать мануал к авто, используйте:")
            print("  PATCH /manuals/{manual_id}/car  body: {\"car_id\": <id_машины>}")
            print("Или откройте авто в приложении — появится кнопка «Привязать».")
            print("=" * 60)


if __name__ == "__main__":
    asyncio.run(main())
