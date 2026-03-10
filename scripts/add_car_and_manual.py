#!/usr/bin/env python3
"""
Создать авто по имени файла мануала, показать извлечённый текст и загрузить мануал.

Имя файла: Chevrolet_2008_Chevrolet_HHR_... → brand=Chevrolet, model=HHR, year=2008

Использование:
  export ACCESS_TOKEN="ваш_jwt_токен"
  python scripts/add_car_and_manual.py путь/к/файлу.pdf
"""

import argparse
import io
import os
import re
import sys
from pathlib import Path

try:
    import httpx
except ImportError:
    print("Установите httpx: pip install httpx")
    sys.exit(1)

BASE_URL = os.environ.get("BASE_URL", "http://localhost:8888")
PREVIEW_CHARS = 4000  # сколько символов текста показать


def parse_filename(filename: str) -> dict:
    """
    Chevrolet_2008_Chevrolet_HHR_Chevrolet_2008_HHR_Owners_Manual.pdf
    → brand=Chevrolet, model=HHR, year=2008, title=Chevrolet HHR Owners Manual 2008
    """
    name = Path(filename).stem
    parts = [p for p in name.replace(".pdf", "").replace(".docx", "").replace(".txt", "").split("_") if p]
    year = None
    for p in parts:
        if p.isdigit() and len(p) == 4 and 1900 <= int(p) <= 2100:
            year = int(p)
            break
    # Бренд — первое слово, модель — второе (HHR), год уже есть
    if len(parts) >= 2:
        brand = parts[0]
        # Модель: второе слово (HHR) или следующие до "Owners"/"Manual"
        model_words = []
        seen_model = set()
        for p in parts[1:]:
            if p == str(year) or p.upper() == brand.upper():
                continue
            if p in ("Owners", "Manual", "OwnersManual"):
                break
            if p.upper() in seen_model:
                break
            seen_model.add(p.upper())
            model_words.append(p)
        model = " ".join(model_words) if model_words else (parts[1] if len(parts) > 1 else "Manual")
    else:
        brand = parts[0] if parts else "Unknown"
        model = "Manual"
    year = year or 2008
    title = f"{brand} {model} Owners Manual {year}"
    return {"brand": brand, "model": model, "year": year, "title": title}


def extract_pdf_text(filepath: Path) -> str:
    """Извлечь текст из PDF (как в ManualService)."""
    content = filepath.read_bytes()
    try:
        import pdfplumber
        with pdfplumber.open(io.BytesIO(content)) as pdf:
            parts = []
            for page in pdf.pages:
                t = page.extract_text()
                if t:
                    parts.append(t)
            return "\n".join(parts)
    except ImportError:
        import PyPDF2
        reader = PyPDF2.PdfReader(io.BytesIO(content))
        parts = []
        for page in reader.pages:
            t = page.extract_text()
            if t:
                parts.append(t)
        return "\n".join(parts)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("file", type=Path, help="PDF/DOCX/TXT файл мануала")
    parser.add_argument("--preview-only", action="store_true", help="Только показать текст, не загружать")
    args = parser.parse_args()

    token = os.environ.get("ACCESS_TOKEN", "")
    if not token and not args.preview_only:
        print("Ошибка: задайте ACCESS_TOKEN (или используйте --preview-only)")
        sys.exit(1)

    if not args.file.exists():
        print(f"Файл не найден: {args.file}")
        sys.exit(1)

    parsed = parse_filename(args.file.name)
    print("=" * 60)
    print("Парсинг имени файла:")
    print(f"  Марка:  {parsed['brand']}")
    print(f"  Модель: {parsed['model']}")
    print(f"  Год:    {parsed['year']}")
    print(f"  Название мануала: {parsed['title']}")
    print("=" * 60)

    # Извлекаем текст
    print("\nИзвлечение текста из PDF...")
    try:
        text = extract_pdf_text(args.file)
    except Exception as e:
        print(f"Ошибка извлечения текста: {e}")
        sys.exit(1)

    print(f"Извлечено {len(text)} символов.\n")
    print("=" * 60)
    print("ПРЕДПРОСМОТР ТЕКСТА (первые символы):")
    print("=" * 60)
    preview = text[:PREVIEW_CHARS]
    if len(text) > PREVIEW_CHARS:
        preview += "\n\n... [обрезано, всего " + str(len(text)) + " символов]"
    print(preview)
    print("=" * 60)

    if args.preview_only:
        print("\n(режим --preview-only, загрузка пропущена)")
        return

    headers = {"Authorization": f"Bearer {token}"}

    # 1. Создаём авто
    print("\n1. Создание автомобиля...")
    car_data = {
        "brand": parsed["brand"],
        "model": parsed["model"],
        "year": parsed["year"],
        "vin": None,
    }
    try:
        r = httpx.post(f"{BASE_URL}/cars/", json=car_data, headers=headers, timeout=30)
        r.raise_for_status()
        car = r.json()
        car_id = car["id"]
        print(f"   ✓ Создано: {car['brand']} {car['model']} ({car['year']}) id={car_id}")
    except httpx.HTTPStatusError as e:
        print(f"   Ошибка: {e.response.status_code} - {e.response.text}")
        sys.exit(1)

    # 2. Загружаем мануал
    print("\n2. Загрузка мануала (разбивка на чанки, эмбеддинги, Qdrant)...")
    file_content = args.file.read_bytes()
    ext = args.file.suffix.lower()
    mime = {
        "pdf": "application/pdf",
        "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "txt": "text/plain",
    }.get(ext[1:], "application/octet-stream")
    files = {"file": (args.file.name, file_content, mime)}
    data = {"title": parsed["title"], "car_id": str(car_id), "force_ocr": "false"}

    timeout = 600 if ext == ".pdf" else 120
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
        print(f"   ✓ Мануал загружен: {manual.get('title')} (id: {manual.get('id')})")
    except httpx.HTTPStatusError as e:
        print(f"   Ошибка: {e.response.status_code}\n{e.response.text}")
        sys.exit(1)

    print("\n" + "=" * 60)
    print("Готово. Авто и мануал добавлены в каталог.")
    print("=" * 60)


if __name__ == "__main__":
    main()
