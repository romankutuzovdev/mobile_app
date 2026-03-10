#!/usr/bin/env python3
"""
Скрипт для загрузки примера мануала через API.

Использование:
  export ACCESS_TOKEN="ваш_jwt_токен"
  python scripts/upload_sample_manual.py

  # или с указанием URL и car_id:
  BASE_URL=http://localhost:8888 CAR_ID=1 python scripts/upload_sample_manual.py

Токен можно получить после входа в приложении (или через Swagger /auth/login).
"""

import os
import sys
from pathlib import Path

try:
    import httpx
except ImportError:
    print("Установите httpx: pip install httpx")
    sys.exit(1)

BASE_URL = os.environ.get("BASE_URL", "http://localhost:8888")
ACCESS_TOKEN = os.environ.get("ACCESS_TOKEN", "")
CAR_ID = os.environ.get("CAR_ID")  # опционально, если не задан — возьмём первый авто

SCRIPT_DIR = Path(__file__).resolve().parent
SAMPLE_FILE = SCRIPT_DIR / "sample_manual.txt"
TITLE = "Руководство по эксплуатации (пример)"


def main():
    if not ACCESS_TOKEN:
        print("Ошибка: задайте переменную ACCESS_TOKEN")
        print("  export ACCESS_TOKEN='ваш_jwt_токен'")
        sys.exit(1)

    if not SAMPLE_FILE.exists():
        print(f"Ошибка: файл {SAMPLE_FILE} не найден")
        sys.exit(1)

    headers = {"Authorization": f"Bearer {ACCESS_TOKEN}"}

    # Получаем car_id, если не задан
    car_id = CAR_ID
    if not car_id:
        try:
            r = httpx.get(f"{BASE_URL}/cars/", headers=headers, timeout=30)
            r.raise_for_status()
            cars = r.json()
            if not cars:
                print("Ошибка: у пользователя нет автомобилей. Добавьте авто сначала.")
                sys.exit(1)
            car_id = str(cars[0]["id"])
        except httpx.HTTPStatusError as e:
            print(f"Ошибка API: {e.response.status_code} - {e.response.text}")
            sys.exit(1)
        except Exception as e:
            print(f"Ошибка: {e}")
            sys.exit(1)

    # Загружаем мануал
    file_content = SAMPLE_FILE.read_bytes()
    files = {"file": (SAMPLE_FILE.name, file_content, "text/plain")}
    data = {"title": TITLE, "car_id": car_id}

    try:
        r = httpx.post(
            f"{BASE_URL}/manuals/upload",
            headers=headers,
            files=files,
            data=data,
            timeout=120,
        )
        r.raise_for_status()
        manual = r.json()
        print(f"✓ Мануал загружен: {manual.get('title', TITLE)} (id: {manual.get('id')})")
        print(f"  Привязан к авто car_id={car_id}")
    except httpx.HTTPStatusError as e:
        print(f"Ошибка загрузки: {e.response.status_code}")
        print(e.response.text)
        sys.exit(1)
    except Exception as e:
        print(f"Ошибка: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
