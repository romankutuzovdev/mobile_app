from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional, List, Dict
from uuid import UUID
import logging

logger = logging.getLogger(__name__)

from sqlalchemy import select

from app.database import get_db
from app.auth.utils import get_current_user
from app.models.user import User
from app.models.car import Car
from app.services.manual_service import ManualService
from app.services.rag_service import RAGService
from app.schemas.manual import (
    ManualOut,
    ManualCreate,
    ManualUpdateCar,
    CarWithManualsOut,
    CatalogOut,
    CatalogTreeOut,
    CatalogBrandEntry,
    CatalogModelEntry,
    CatalogYearEntry,
    RAGQuestionRequest,
    RAGQuestionResponse
)

router = APIRouter()


@router.get("", response_model=List[ManualOut])
async def list_manuals(
    car_id: Optional[int] = None,
    orphaned: bool = False,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Список мануалов. car_id — по авто. orphaned=true — мануалы без привязки (после удаления машины)."""
    if car_id is not None:
        result = await db.execute(select(Car).where(Car.id == car_id, Car.user_id == current_user.id))
        if not result.scalar_one_or_none():
            raise HTTPException(status_code=404, detail="Автомобиль не найден")
    manuals = await ManualService.get_manuals_list(db, car_id=car_id, orphaned_only=orphaned)
    return manuals


@router.get("/catalog", response_model=CatalogOut)
async def get_catalog(
    only_with_manuals: bool = False,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Каталог: машины пользователя + мануалы из глобальной базы по совпадению brand/model/year."""
    from app.repositories.manual_repository import ManualRepository
    result = await db.execute(
        select(Car).where(Car.user_id == current_user.id).order_by(Car.created_at.desc())
    )
    cars = list(result.scalars().all())
    catalog_cars = []
    for car in cars:
        manuals = await ManualRepository.get_manuals_by_brand_model_year(
            db, car.brand, car.model, car.year
        )
        manuals_out = [ManualOut.model_validate(m) for m in manuals]
        has_manuals = len(manuals_out) > 0
        if only_with_manuals and not has_manuals:
            continue
        catalog_cars.append(
            CarWithManualsOut(
                id=car.id,
                brand=car.brand,
                model=car.model,
                year=car.year,
                vin=car.vin,
                manuals=manuals_out,
                has_manuals=has_manuals,
            )
        )
    # Сначала машины с мануалами (по ним можно искать)
    catalog_cars.sort(key=lambda c: (not c.has_manuals, -c.year))
    return CatalogOut(cars=catalog_cars)


@router.get("/catalog/tree", response_model=CatalogTreeOut)
async def get_catalog_tree(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Глобальный каталог мануалов: Марки → Модели → Год → Мануалы (общая база)."""
    from app.repositories.manual_repository import ManualRepository
    manuals = await ManualRepository.get_all_manuals_global(db)
    brands_map: Dict[str, Dict[str, Dict[int, List]]] = {}
    for m in manuals:
        b, mod, y = (m.brand or "").strip(), (m.model or "Unknown").strip(), m.year
        if b not in brands_map:
            brands_map[b] = {}
        if mod not in brands_map[b]:
            brands_map[b][mod] = {}
        if y not in brands_map[b][mod]:
            brands_map[b][mod][y] = []
        brands_map[b][mod][y].append(ManualOut.model_validate(m))
    brands_list = []
    for brand_name in sorted(brands_map.keys(), key=str.lower):
        models_list = []
        for model_name in sorted(brands_map[brand_name].keys(), key=str.lower):
            years_data = brands_map[brand_name][model_name]
            years = [
                CatalogYearEntry(year=y, manuals=manuals)
                for y, manuals in sorted(years_data.items(), key=lambda x: -x[0])
            ]
            models_list.append(CatalogModelEntry(name=model_name, years=years))
        brands_list.append(CatalogBrandEntry(name=brand_name, models=models_list))
    return CatalogTreeOut(brands=brands_list)


@router.post("/upload", response_model=ManualOut, status_code=status.HTTP_201_CREATED)
async def upload_manual(
    file: UploadFile = File(...),
    title: str = Form(...),
    car_id: Optional[int] = Form(None),
    force_ocr: bool = Form(False, description="Для PDF: сразу OCR по всем страницам (больше текста, дольше)"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Загрузка мануала (PDF/DOCX/TXT). force_ocr=true — для PDF извлекать текст через OCR по всем страницам."""
    # Проверяем формат файла
    allowed_extensions = {'.pdf', '.docx', '.doc', '.txt'}
    file_ext = '.' + file.filename.split('.')[-1].lower() if '.' in file.filename else ''
    
    if file_ext not in allowed_extensions:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Неподдерживаемый формат файла. Разрешены: {', '.join(allowed_extensions)}"
        )

    try:
        # Читаем содержимое файла
        file_content = await file.read()
        
        # Загружаем мануал
        manual = await ManualService.upload_manual(
            db=db,
            file_content=file_content,
            filename=file.filename,
            title=title,
            car_id=car_id,
            user_id=current_user.id,
            use_ocr_for_pdf=force_ocr
        )
        
        return manual
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Ошибка при загрузке мануала: {str(e)}"
        )


@router.get("/{manual_id}", response_model=ManualOut)
async def get_manual(
    manual_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Получение мануала по ID"""
    manual = await ManualService.get_manual(db, manual_id)
    
    if not manual:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Мануал не найден"
        )
    
    return manual


@router.patch("/{manual_id}/car", response_model=ManualOut)
async def update_manual_car(
    manual_id: UUID,
    body: ManualUpdateCar,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Привязать мануал к автомобилю (для «потерянных» мануалов после удаления авто)"""
    manual = await ManualService.update_manual_car(
        db=db,
        manual_id=manual_id,
        car_id=body.car_id,
        user_id=current_user.id
    )
    if not manual:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Мануал или автомобиль не найден, либо авто не принадлежит вам"
        )
    return manual


@router.delete("/{manual_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_manual(
    manual_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Удаление мануала"""
    success = await ManualService.delete_manual(db, manual_id)
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Мануал не найден"
        )
    
    return None


@router.post("/chat/manual", response_model=RAGQuestionResponse)
async def ask_manual_question(
    request: RAGQuestionRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Задать вопрос по мануалам с использованием RAG"""
    try:
        result = await RAGService.ask_question(
            question=request.question,
            car_id=request.car_id,
            manual_id=request.manual_id,
            brand=request.brand,
            model=request.model,
            year=request.year,
            db=db
        )
        
        return RAGQuestionResponse(
            answer=result["answer"],
            sources=result["sources"],
            context_preview=result.get("context_preview")
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        logger.exception("Ошибка при обработке вопроса по мануалу")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Ошибка при обработке вопроса: {str(e)}"
        )
