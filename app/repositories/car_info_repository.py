from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import Optional

from app.models.car_info import CarInfo


class CarInfoRepository:
    """Репозиторий для работы с общей базой машин"""

    @staticmethod
    async def get_by_vin(db: AsyncSession, vin: str) -> Optional[CarInfo]:
        """Получение информации о машине по VIN"""
        result = await db.execute(select(CarInfo).where(CarInfo.vin == vin))
        return result.scalar_one_or_none()

    @staticmethod
    async def create(db: AsyncSession, vin: str, brand: str = None, model: str = None, 
                     year: int = None, api_data: dict = None) -> CarInfo:
        """Создание записи о машине в общей базе"""
        car_info = CarInfo(
            vin=vin,
            brand=brand,
            model=model,
            year=year,
            api_data=api_data
        )
        db.add(car_info)
        await db.commit()
        await db.refresh(car_info)
        return car_info

    @staticmethod
    async def get_or_create_by_vin(
        db: AsyncSession,
        vin: str,
        brand: str = None,
        model: str = None,
        year: int = None,
        api_data: dict = None
    ) -> CarInfo:
        """Получить или создать запись о машине"""
        car_info = await CarInfoRepository.get_by_vin(db, vin)
        if car_info:
            return car_info
        
        return await CarInfoRepository.create(db, vin, brand, model, year, api_data)

