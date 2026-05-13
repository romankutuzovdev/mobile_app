from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from datetime import datetime

from app.database import Base


class ChatMessage(Base):
    """Сообщения чата пользователя по конкретному автомобилю"""
    __tablename__ = "chat_messages"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    car_id = Column(Integer, ForeignKey("cars.id", ondelete="CASCADE"), nullable=True, index=True)
    # ID комплектации в Car API (чат по каталогу без привязки к cars.id)
    catalog_trim_id = Column(Integer, nullable=True, index=True)
    role = Column(String(16), nullable=False)  # 'user' | 'assistant' | 'system'
    content = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, index=True)

    user = relationship("User", backref="chat_messages")
    car = relationship("Car", backref="chat_messages")


