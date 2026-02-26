from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime


class ChatMessageBase(BaseModel):
  role: str = Field(..., description="Роль сообщения: user | assistant | system")
  content: str


class ChatMessageOut(ChatMessageBase):
  id: int
  car_id: Optional[int] = None
  created_at: datetime

  class Config:
    from_attributes = True


class ChatRequest(BaseModel):
  car_id: int
  question: str


class ChatResponse(BaseModel):
  answer: str
  messages: List[ChatMessageOut]


