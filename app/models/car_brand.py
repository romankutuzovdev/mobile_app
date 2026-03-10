from sqlalchemy import Column, Integer, String

from app.database import Base


class CarBrand(Base):
    """Справочник марок автомобилей (для каталога и привязки мануалов)"""
    __tablename__ = "car_brands"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False, unique=True)
