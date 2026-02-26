from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

from app.schemas.car import CarOut


class UserOut(BaseModel):
    id: int
    phone: str
    email: Optional[str] = None
    username: Optional[str] = None
    cars: List[CarOut] = []

    class Config:
        from_attributes = True

