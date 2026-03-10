from typing import List

from sqlalchemy import select
from fastapi import APIRouter

from app.database import AsyncSessionLocal
from app.models.car_brand import CarBrand
from app.schemas.car_brand import CarBrandOut

router = APIRouter()


@router.get("/", response_model=List[CarBrandOut])
async def list_car_brands():
    """Список всех марок автомобилей (справочник)"""
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(CarBrand).order_by(CarBrand.name))
        brands = list(result.scalars().all())
    return [CarBrandOut.model_validate(b) for b in brands]
