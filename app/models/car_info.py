from sqlalchemy import Column, Integer, String, DateTime, JSON
from datetime import datetime

from app.database import Base


class CarInfo(Base):
    """Общая база информации о машинах по VIN"""
    __tablename__ = "car_info"

    id = Column(Integer, primary_key=True, index=True)
    vin = Column(String(17), unique=True, nullable=False, index=True)  # VIN уникален в общей базе
    brand = Column(String, nullable=True)
    model = Column(String, nullable=True)
    year = Column(Integer, nullable=True)
    # Дополнительная информация из API в формате JSON
    api_data = Column(JSON, nullable=True)
    # Дата создания записи
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

