from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List
import logging
import traceback

from app.database import get_db
from app.auth.utils import get_current_user
from app.models.user import User
from app.models.car import Car
from app.models.car_info import CarInfo
from app.models.chat_message import ChatMessage
from app.schemas.chat import ChatRequest, ChatResponse, ChatMessageOut
from app.services.chatgpt_vehicle_service import ChatGPTVehicleService

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get("/history/{car_id}", response_model=List[ChatMessageOut])
async def get_chat_history(
    car_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """История чата пользователя по конкретному автомобилю."""
    result = await db.execute(
        ChatMessage.__table__
        .select()
        .where(
            ChatMessage.user_id == current_user.id,
            ChatMessage.car_id == car_id,
        )
        .order_by(ChatMessage.created_at.asc())
    )
    rows = result.fetchall()
    messages = [ChatMessageOut.model_validate(row) for row in rows]
    return messages


@router.post("/vehicle", response_model=ChatResponse)
async def chat_about_vehicle(
    payload: ChatRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Задать вопрос по конкретному автомобилю (GPT + сохранение диалога)."""
    # Проверяем, что машина принадлежит пользователю
    car = await db.get(Car, payload.car_id)
    if not car or car.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Автомобиль не найден",
        )

    # Готовим блок с данными автомобиля:
    # базовые поля + подробности из CarInfo.api_data (результат пробития VIN)
    lines = [
        f"Brand: {car.brand}",
        f"Model: {car.model}",
        f"Year: {car.year}",
        f"VIN: {car.vin or 'unknown'}",
    ]

    if car.car_info_id:
        car_info = await db.get(CarInfo, car.car_info_id)
        if car_info and isinstance(car_info.api_data, dict):
            api = car_info.api_data
            basic = api.get("basic_info") or {}
            engine = api.get("engine") or {}
            transmission = api.get("transmission") or {}
            fuel = api.get("fuel") or {}

            def add_block(title: str, data: dict, mapping: dict):
                if not isinstance(data, dict):
                    return
                parts = []
                for label, key in mapping.items():
                    val = data.get(key)
                    if val is not None and str(val).strip() != "":
                        parts.append(f"{label}: {val}")
                if parts:
                    lines.append(f"{title}:")
                    lines.extend(f"  - {p}" for p in parts)

            add_block(
                "Basic info",
                basic,
                {
                    "Series": "series",
                    "Body type": "body_type",
                    "Generation": "generation",
                    "Assembly plant": "assembly_plant",
                    "Manufacturer": "manufacturer",
                    "Country": "country",
                },
            )
            add_block(
                "Engine",
                engine,
                {
                    "Type": "type",
                    "Code": "code",
                    "Volume (L)": "volume_l",
                    "Power (hp)": "power_hp",
                    "Cylinders": "cylinders",
                    "Aspiration": "aspiration",
                    "Fuel system": "fuel_system",
                },
            )
            add_block(
                "Transmission",
                transmission,
                {
                    "Type": "type",
                    "Gears": "gears",
                    "Drive": "drive",
                },
            )
            add_block(
                "Fuel",
                fuel,
                {
                    "Fuel type": "fuel_type",
                    "Avg consumption (L/100km)": "average_consumption_l_per_100km",
                    "Tank (L)": "tank_l",
                },
            )

    vehicle_block = "\n".join(lines)

    # Сохраняем вопрос в БД
    user_msg = ChatMessage(
        user_id=current_user.id,
        car_id=car.id,
        role="user",
        content=payload.question,
    )
    db.add(user_msg)
    await db.flush()

    # Вызов ChatGPT
    try:
        logger.info(
            "🔧 [chat.vehicle] user_id=%s car_id=%s question=%r",
            current_user.id,
            car.id,
            payload.question,
        )
        answer = await ChatGPTVehicleService.ask_vehicle_question(
            vehicle_block, payload.question
        )
        logger.info("✅ [chat.vehicle] GPT ответ получен, длина=%d", len(answer))
    except Exception as e:
        logger.error(
            "❌ [chat.vehicle] Ошибка при обращении к ChatGPT: %s\n%s",
            e,
            traceback.format_exc(),
        )
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Ошибка при обращении к ChatGPT: {type(e).__name__}: {e}",
        )

    # Сохраняем ответ ассистента
    assistant_msg = ChatMessage(
        user_id=current_user.id,
        car_id=car.id,
        role="assistant",
        content=answer,
    )
    db.add(assistant_msg)
    await db.commit()

    # Возвращаем обновлённую историю (для простоты)
    result = await db.execute(
        ChatMessage.__table__
        .select()
        .where(
            ChatMessage.user_id == current_user.id,
            ChatMessage.car_id == car.id,
        )
        .order_by(ChatMessage.created_at.asc())
    )
    rows = result.fetchall()
    messages = [ChatMessageOut.model_validate(row) for row in rows]

    return ChatResponse(answer=answer, messages=messages)


