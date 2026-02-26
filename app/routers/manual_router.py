from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional, List
from uuid import UUID
import logging

logger = logging.getLogger(__name__)

from app.database import get_db
from app.auth.utils import get_current_user
from app.models.user import User
from app.services.manual_service import ManualService
from app.services.rag_service import RAGService
from app.schemas.manual import (
    ManualOut,
    ManualCreate,
    RAGQuestionRequest,
    RAGQuestionResponse
)

router = APIRouter()


@router.get("", response_model=List[ManualOut])
async def list_manuals(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Список всех загруженных мануалов"""
    manuals = await ManualService.get_manuals_list(db)
    return manuals


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
