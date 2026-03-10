from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from uuid import UUID


class ManualCreate(BaseModel):
    """Схема для создания мануала"""
    title: str = Field(..., min_length=1, max_length=500, description="Название мануала")
    car_id: Optional[int] = Field(None, description="ID автомобиля (опционально)")


class ManualUpdateCar(BaseModel):
    """Схема для привязки мануала к автомобилю"""
    car_id: int = Field(..., description="ID автомобиля для привязки")


class ManualOut(BaseModel):
    """Схема для вывода мануала"""
    id: UUID
    car_id: Optional[int] = None
    brand: str = ""
    model: str = ""
    year: int = 0
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


class CarWithManualsOut(BaseModel):
    """Автомобиль с его мануалами (запись в каталоге для поиска по мануалам)"""
    id: int
    brand: str
    model: str
    year: int
    vin: Optional[str] = None
    manuals: List[ManualOut] = []
    has_manuals: bool = False  # true если есть хотя бы один мануал — по нему можно искать


class CatalogOut(BaseModel):
    """Каталог: машины пользователя с их мануалами"""
    cars: List[CarWithManualsOut]


class CatalogYearEntry(BaseModel):
    """Год выпуска с мануалами (глобальный каталог)"""
    year: int
    manuals: List[ManualOut] = []


class CatalogModelEntry(BaseModel):
    """Модель с годами выпуска"""
    name: str
    years: List[CatalogYearEntry] = []


class CatalogBrandEntry(BaseModel):
    """Марка с моделями"""
    name: str
    models: List[CatalogModelEntry] = []


class CatalogTreeOut(BaseModel):
    """Иерархический каталог: Марки → Модели → Год → Мануалы"""
    brands: List[CatalogBrandEntry] = []


class RAGQuestionRequest(BaseModel):
    """Схема для запроса RAG"""
    car_id: Optional[int] = Field(None, description="ID машины пользователя — ищем мануалы по brand/model/year")
    manual_id: Optional[UUID] = Field(None, description="Искать только в этом мануале")
    brand: Optional[str] = Field(None, description="Марка (при запросе из каталога без car_id)")
    model: Optional[str] = Field(None, description="Модель")
    year: Optional[int] = Field(None, description="Год")
    question: str = Field(..., min_length=1, max_length=2000, description="Вопрос пользователя")


class RAGQuestionResponse(BaseModel):
    """Схема для ответа RAG"""
    answer: str = Field(..., description="Ответ на основе контекста")
    sources: List[dict] = Field(default_factory=list, description="Источники информации")
    context_preview: Optional[str] = Field(None, description="Превью текста из мануала, по которому сформирован ответ (для отладки)")