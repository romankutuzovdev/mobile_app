#!/usr/bin/env python3
"""
Загрузка мануала (PDF/DOCX/TXT) через API.

Использование:
  export ACCESS_TOKEN="ваш_jwt_токен"
  python scripts/upload_manual.py путь/к/файлу.pdf [--title "Название"] [--car-id 1]

  # Без --car-id: авто создаётся из имени файла/названия и мануал привязывается к нему.
  python scripts/upload_manual.py ~/Downloads/BMW_2009.pdf --title "BMW 1 Series 135i 2009"
"""

import argparse
import os
import sys
from pathlib import Path

try:
    import httpx
except ImportError:
    print("Установите httpx: pip install httpx")
    sys.exit(1)

BASE_URL = os.environ.get("BASE_URL", "http://localhost:8888")


def infer_title(filename: str) -> str:
    """Вывести название из имени файла, например BMW_2009_BMW_1_Series_... -> BMW 1 Series 135i Convertible 2009"""
    name = Path(filename).stem
    # Убираем повторы типа BMW_2009_BMW_
    parts = name.replace("_", " ").split()
    seen = set()
    unique = []
    for p in parts:
        pk = p.upper()
        if pk not in seen and p.isalnum():
            seen.add(pk)
            unique.append(p)
    return " ".join(unique) if unique else name.replace("_", " ")


def main():
    parser = argparse.ArgumentParser(description="Загрузка мануала через API")
    parser.add_argument("file", type=Path, help="Путь к файлу (PDF/DOCX/TXT)")
    parser.add_argument("--title", "-t", help="Название мануала (по умолчанию — из имени файла)")
    parser.add_argument("--car-id", "-c", help="ID автомобиля (по умолчанию — первый в списке)")
    parser.add_argument("--force-ocr", action="store_true", help="Для PDF: принудительный OCR по всем страницам")
    args = parser.parse_args()

    token = os.environ.get("ACCESS_TOKEN", "")
    if not token:
        print("Ошибка: задайте ACCESS_TOKEN")
        print("  export ACCESS_TOKEN='ваш_jwt_токен'")
        sys.exit(1)

    if not args.file.exists():
        print(f"Ошибка: файл не найден: {args.file}")
        sys.exit(1)

    title = args.title or infer_title(str(args.file))
    headers = {"Authorization": f"Bearer {token}"}

    ext = args.file.suffix.lower()
    mime = {"pdf": "application/pdf", "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "doc": "application/msword", "txt": "text/plain"}.get(ext[1:], "application/octet-stream")

    file_content = args.file.read_bytes()
    files = {"file": (args.file.name, file_content, mime)}
    data = {"title": title, "force_ocr": str(args.force_ocr).lower()}
    if args.car_id:
        data["car_id"] = args.car_id

    # Большие PDF требуют много времени (парсинг + embedding каждого чанка)
    timeout = 1800.0 if ext == ".pdf" else 120
    print(f"Загрузка {args.file.name} ({len(file_content) / 1024:.1f} KB) как «{title}»...")
    print("(Обработка PDF может занять несколько минут)")

    try:
        r = httpx.post(
            f"{BASE_URL}/manuals/upload",
            headers=headers,
            files=files,
            data=data,
            timeout=timeout,
        )
        r.raise_for_status()
        manual = r.json()
        car_id = manual.get("car_id")
        print(f"✓ Мануал загружен: {manual.get('title')} (id: {manual.get('id')})")
        print(f"  car_id={car_id}")
    except httpx.HTTPStatusError as e:
        print(f"Ошибка: {e.response.status_code}")
        print(e.response.text)
        sys.exit(1)
    except Exception as e:
        print(f"Ошибка: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
