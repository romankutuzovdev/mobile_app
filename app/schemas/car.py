from pydantic import BaseModel, Field, field_validator
from typing import Optional
from datetime import datetime


class CarCreate(BaseModel):
    vin: Optional[str] = Field(None, min_length=17, max_length=17, description="VIN код (17 символов)")
    brand: str = Field(..., min_length=1, max_length=100, description="Марка автомобиля")
    model: str = Field(..., min_length=1, max_length=100, description="Модель автомобиля")
    year: int = Field(..., ge=1900, le=2100, description="Год выпуска")

    @field_validator("vin")
    @classmethod
    def validate_vin(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and len(v) != 17:
            raise ValueError("VIN код должен содержать ровно 17 символов")
        return v


class CarUpdate(BaseModel):
    vin: Optional[str] = Field(None, min_length=17, max_length=17)
    brand: Optional[str] = Field(None, min_length=1, max_length=100)
    model: Optional[str] = Field(None, min_length=1, max_length=100)
    year: Optional[int] = Field(None, ge=1900, le=2100)

    @field_validator("vin")
    @classmethod
    def validate_vin(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and len(v) != 17:
            raise ValueError("VIN код должен содержать ровно 17 символов")
        return v


class CarOut(BaseModel):
    id: int
    vin: Optional[str]
    brand: str
    model: str
    year: int
    created_at: datetime

    class Config:
        from_attributes = True

