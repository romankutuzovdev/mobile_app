from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List, Optional

from app.models.car import Car
from app.schemas.car import CarCreate, CarUpdate


class CarRepository:
    """Репозиторий для работы с автомобилями"""

    @staticmethod
    async def create_car(db: AsyncSession, user_id: int, car_data: CarCreate, car_info_id: int = None) -> Car:
        """Создание нового автомобиля"""
        db_car = Car(
            user_id=user_id,
            car_info_id=car_info_id,
            vin=car_data.vin,
            brand=car_data.brand,
            model=car_data.model,
            year=car_data.year
        )
        db.add(db_car)
        await db.commit()
        await db.refresh(db_car)
        return db_car

    @staticmethod
    async def get_car_by_id(db: AsyncSession, car_id: int) -> Optional[Car]:
        """Получение автомобиля по ID"""
        result = await db.execute(select(Car).where(Car.id == car_id))
        return result.scalar_one_or_none()

    @staticmethod
    async def get_car_by_vin(db: AsyncSession, vin: str) -> Optional[Car]:
        """Получение первого автомобиля по VIN коду (может быть несколько)"""
        result = await db.execute(select(Car).where(Car.vin == vin).limit(1))
        return result.scalar_one_or_none()
    
    @staticmethod
    async def get_user_car_by_vin(db: AsyncSession, user_id: int, vin: str) -> Optional[Car]:
        """Получение автомобиля пользователя по VIN коду"""
        result = await db.execute(
            select(Car).where(Car.user_id == user_id, Car.vin == vin)
        )
        return result.scalar_one_or_none()

    @staticmethod
    async def get_user_cars(db: AsyncSession, user_id: int) -> List[Car]:
        """Получение всех автомобилей пользователя"""
        result = await db.execute(
            select(Car).where(Car.user_id == user_id).order_by(Car.created_at.desc())
        )
        return list(result.scalars().all())

    @staticmethod
    async def update_car(db: AsyncSession, car_id: int, car_data: CarUpdate) -> Optional[Car]:
        """Обновление автомобиля"""
        car = await CarRepository.get_car_by_id(db, car_id)
        if not car:
            return None

        update_data = car_data.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(car, field, value)

        await db.commit()
        await db.refresh(car)
        return car

    @staticmethod
    async def delete_car(db: AsyncSession, car_id: int) -> bool:
        """Удаление автомобиля"""
        car = await CarRepository.get_car_by_id(db, car_id)
        if not car:
            return False

        await db.delete(car)
        await db.commit()
        return True

