from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List

from app.database import get_db
from app.auth.utils import get_current_user
from app.models.user import User
from app.services.car_service import CarService
from app.schemas.car import CarCreate, CarUpdate, CarOut
from app.schemas.vin import VINSearchRequest, VINSearchResponse, AddCarByVINRequest

router = APIRouter()


@router.post("/", response_model=CarOut, status_code=status.HTTP_201_CREATED)
async def create_car(
    car_data: CarCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Добавить автомобиль пользователю"""
    try:
        car = await CarService.create_car(db, current_user.id, car_data)
        return car
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.get("/", response_model=List[CarOut])
async def list_cars(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Получить список автомобилей пользователя"""
    cars = await CarService.list_user_cars(db, current_user.id)
    return cars


@router.put("/{car_id}", response_model=CarOut)
async def update_car(
    car_id: int,
    car_data: CarUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Обновить автомобиль"""
    try:
        car = await CarService.update_car(db, car_id, current_user.id, car_data)
        return car
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.delete("/{car_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_car(
    car_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Удалить автомобиль"""
    try:
        success = await CarService.delete_car(db, car_id, current_user.id)
        if not success:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Автомобиль не найден"
            )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.post("/search-vin", response_model=VINSearchResponse)
async def search_by_vin(
    request: VINSearchRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Поиск информации о машине по VIN коду через ChatGPT API"""
    try:
        result = await CarService.search_by_vin(db, request.vin)
        # Используем model_validate для правильной обработки типов
        return VINSearchResponse.model_validate(result)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.post("/add-by-vin", response_model=CarOut, status_code=status.HTTP_201_CREATED)
async def add_car_by_vin(
    request: AddCarByVINRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Добавить автомобиль пользователю по VIN с автоматическим поиском информации"""
    try:
        car = await CarService.add_car_by_vin(db, current_user.id, request.vin)
        return car
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )

