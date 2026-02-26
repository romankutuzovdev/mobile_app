#!/usr/bin/env python3
"""Создание пользователя: логин 333, пароль 333"""
import asyncio
import sys

from app.database import AsyncSessionLocal
from app.auth.service import create_user, get_user_by_phone


async def main():
    async with AsyncSessionLocal() as db:
        existing = await get_user_by_phone(db, "333")
        if existing:
            print("Пользователь с логином 333 уже существует")
            return
        user = await create_user(
            db=db,
            phone="333",
            password="333",
        )
        print(f"Пользователь создан: id={user.id}, phone={user.phone}")


if __name__ == "__main__":
    asyncio.run(main())
