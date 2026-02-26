from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from uuid import UUID


class ManualCreate(BaseModel):
    """Схема для создания мануала"""
    title: str = Field(..., min_length=1, max_length=500, description="Название мануала")
    car_id: Optional[int] = Field(None, description="ID автомобиля (опционально)")


class ManualOut(BaseModel):
    """Схема для вывода мануала"""
    id: UUID
    car_id: Optional[int]
    title: str
    source_file: str
    created_at: datetime

    class Config:
        from_attributes = True


class ManualChunkOut(BaseModel):
    """Схема для вывода чанка"""
    id: UUID
    manual_id: UUID
    content: str
    embedding_id: str
    page: Optional[int]

    class Config:
        from_attributes = True


class ManualWithChunksOut(BaseModel):
    """Схема для вывода мануала с чанками"""
    id: UUID
    car_id: Optional[int]
    title: str
    source_file: str
    created_at: datetime
    chunks: List[ManualChunkOut] = []

    class Config:
        from_attributes = True


class RAGQuestionRequest(BaseModel):
    """Схема для запроса RAG"""
    car_id: Optional[int] = Field(None, description="ID автомобиля для фильтрации")
    manual_id: Optional[UUID] = Field(None, description="Искать только в этом мануале (ID мануала)")
    question: str = Field(..., min_length=1, max_length=2000, description="Вопрос пользователя")


class RAGQuestionResponse(BaseModel):
    """Схема для ответа RAG"""
    answer: str = Field(..., description="Ответ на основе контекста")
    sources: List[dict] = Field(default_factory=list, description="Источники информации")
    context_preview: Optional[str] = Field(None, description="Превью текста из мануала, по которому сформирован ответ (для отладки)")