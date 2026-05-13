from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List
import logging
import traceback

from app.database import get_db
from app.config import settings
from app.auth.utils import get_current_user
from app.models.user import User
from app.models.car import Car
from app.models.car_info import CarInfo
from app.models.chat_message import ChatMessage
from app.schemas.chat import ChatRequest, ChatResponse, ChatMessageOut, CatalogTrimChatRequest
from app.services.chatgpt_vehicle_service import ChatGPTVehicleService
from app.services.carapi_client import carapi_get

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

    # История чата (до текущего вопроса) — для контекста диалога
    hist_result = await db.execute(
        select(ChatMessage)
        .where(
            ChatMessage.user_id == current_user.id,
            ChatMessage.car_id == car.id,
        )
        .order_by(ChatMessage.created_at.asc())
    )
    hist_messages = hist_result.scalars().all()
    history = [{"role": m.role, "content": m.content} for m in hist_messages]

    # Сохраняем вопрос в БД
    user_msg = ChatMessage(
        user_id=current_user.id,
        car_id=car.id,
        role="user",
        content=payload.question,
    )
    db.add(user_msg)
    await db.flush()

    # Вызов ChatGPT с полной историей диалога
    try:
        if not settings.OPENAI_API_KEY or not settings.OPENAI_API_KEY.strip():
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="AI-чат не настроен. Добавьте OPENAI_API_KEY в файл .env и перезапустите бэкенд.",
            )
        logger.info(
            "🔧 [chat.vehicle] user_id=%s car_id=%s question=%r history_len=%d",
            current_user.id,
            car.id,
            payload.question,
            len(history),
        )
        answer = await ChatGPTVehicleService.ask_vehicle_question(
            vehicle_block, payload.question, history=history
        )
        logger.info("✅ [chat.vehicle] GPT ответ получен, длина=%d", len(answer))
    except HTTPException:
        raise
    except Exception as e:
        tb = traceback.format_exc()
        logger.error("❌ [chat.vehicle] Ошибка при обращении к ChatGPT: %s\n%s", e, tb)
        # В stderr для docker logs — полный стек
        import sys
        sys.stderr.write(f"[CHAT] 502 Ошибка: {type(e).__name__}: {e}\n")
        sys.stderr.write(f"[CHAT] Traceback:\n{tb}\n")
        sys.stderr.flush()
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Ошибка при обращении к ChatGPT: {type(e).__name__}: {str(e)[:200]}",
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


def _format_catalog_trim_for_gpt(trim: dict) -> str:
    """Текстовый блок для system prompt по данным комплектации Car API."""
    parts = [
        "Источник: каталог Car API (типовая комплектация для рынка данных API, не конкретный автомобиль пользователя).",
        f"Год: {trim.get('year')}",
        f"Марка: {trim.get('make')}",
        f"Модель: {trim.get('model')}",
    ]
    if trim.get("series"):
        parts.append(f"Серия: {trim.get('series')}")
    if trim.get("submodel"):
        parts.append(f"Подмодель: {trim.get('submodel')}")
    if trim.get("trim"):
        parts.append(f"Комплектация (trim): {trim.get('trim')}")
    if trim.get("description"):
        parts.append(f"Описание: {trim.get('description')}")
    if trim.get("msrp") is not None:
        parts.append(f"MSRP: {trim.get('msrp')}")
    if trim.get("invoice") is not None:
        parts.append(f"Invoice: {trim.get('invoice')}")
    parts.append(
        "Отвечай по-русски. Не выдавай за факт то, чего нет в данных; "
        "если нужен осмотр конкретного авто или региональные отличия — скажи об этом."
    )
    return "\n".join(parts)


@router.get("/catalog-history/{trim_id}", response_model=List[ChatMessageOut])
async def get_catalog_chat_history(
    trim_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """История чата по комплектации из каталога Car API."""
    hist_result = await db.execute(
        select(ChatMessage)
        .where(
            ChatMessage.user_id == current_user.id,
            ChatMessage.catalog_trim_id == trim_id,
            ChatMessage.car_id.is_(None),
        )
        .order_by(ChatMessage.created_at.asc())
    )
    hist_messages = hist_result.scalars().all()
    return [ChatMessageOut.model_validate(m) for m in hist_messages]


@router.post("/catalog-trim", response_model=ChatResponse)
async def chat_catalog_trim(
    payload: CatalogTrimChatRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Вопрос к GPT по выбранной комплектации из каталога Car API."""
    try:
        trim_raw = await carapi_get(f"trims/v2/{payload.trim_id}", None)
    except Exception as e:
        logger.warning("Не удалось загрузить trim %s: %s", payload.trim_id, e)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Не удалось загрузить данные комплектации из каталога",
        )

    if not isinstance(trim_raw, dict) or trim_raw.get("id") is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Комплектация не найдена",
        )

    vehicle_block = _format_catalog_trim_for_gpt(trim_raw)

    hist_result = await db.execute(
        select(ChatMessage)
        .where(
            ChatMessage.user_id == current_user.id,
            ChatMessage.catalog_trim_id == payload.trim_id,
            ChatMessage.car_id.is_(None),
        )
        .order_by(ChatMessage.created_at.asc())
    )
    hist_messages = hist_result.scalars().all()
    history = [{"role": m.role, "content": m.content} for m in hist_messages]

    user_msg = ChatMessage(
        user_id=current_user.id,
        car_id=None,
        catalog_trim_id=payload.trim_id,
        role="user",
        content=payload.question,
    )
    db.add(user_msg)
    await db.flush()

    try:
        if not settings.OPENAI_API_KEY or not settings.OPENAI_API_KEY.strip():
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="AI-чат не настроен. Добавьте OPENAI_API_KEY в файл .env и перезапустите бэкенд.",
            )
        answer = await ChatGPTVehicleService.ask_vehicle_question(
            vehicle_block, payload.question, history=history
        )
    except HTTPException:
        raise
    except Exception as e:
        tb = traceback.format_exc()
        logger.error("❌ [chat.catalog_trim] Ошибка ChatGPT: %s\n%s", e, tb)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Ошибка при обращении к ChatGPT: {type(e).__name__}: {str(e)[:200]}",
        )

    assistant_msg = ChatMessage(
        user_id=current_user.id,
        car_id=None,
        catalog_trim_id=payload.trim_id,
        role="assistant",
        content=answer,
    )
    db.add(assistant_msg)
    await db.commit()

    result = await db.execute(
        select(ChatMessage)
        .where(
            ChatMessage.user_id == current_user.id,
            ChatMessage.catalog_trim_id == payload.trim_id,
            ChatMessage.car_id.is_(None),
        )
        .order_by(ChatMessage.created_at.asc())
    )
    rows = result.scalars().all()
    messages = [ChatMessageOut.model_validate(row) for row in rows]

    return ChatResponse(answer=answer, messages=messages)
