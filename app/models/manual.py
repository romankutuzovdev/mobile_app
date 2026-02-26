from sqlalchemy import Column, String, Integer, Text, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid

from app.database import Base


class Manual(Base):
    """Модель мануала автомобиля"""
    __tablename__ = "manuals"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    car_id = Column(Integer, ForeignKey("cars.id", ondelete="SET NULL"), nullable=True, index=True)
    title = Column(String, nullable=False)
    source_file = Column(String, nullable=False)  # Имя исходного файла
    created_at = Column(DateTime, default=datetime.utcnow)

    chunks = relationship("ManualChunk", back_populates="manual", cascade="all, delete-orphan")


class ManualChunk(Base):
    """Модель чанка мануала для векторного поиска"""
    __tablename__ = "manual_chunks"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    manual_id = Column(UUID(as_uuid=True), ForeignKey("manuals.id", ondelete="CASCADE"), nullable=False, index=True)
    content = Column(Text, nullable=False)
    embedding_id = Column(String, nullable=False, unique=True, index=True)  # ID в Qdrant
    page = Column(Integer, nullable=True)  # Номер страницы (если известен)

    manual = relationship("Manual", back_populates="chunks")
