from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime

from app.database import Base


class Car(Base):
    """Машины пользователей"""
    __tablename__ = "cars"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    car_info_id = Column(Integer, ForeignKey("car_info.id", ondelete="SET NULL"), nullable=True, index=True)
    vin = Column(String(17), nullable=True, index=True)  # VIN для быстрого поиска
    brand = Column(String, nullable=False)
    model = Column(String, nullable=False)
    year = Column(Integer, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="cars")
    car_info = relationship("CarInfo", backref="cars")

