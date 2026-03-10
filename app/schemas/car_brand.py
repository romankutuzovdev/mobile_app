from pydantic import BaseModel, Field


class CarBrandOut(BaseModel):
    id: int
    name: str = Field(..., description="Название марки")

    class Config:
        from_attributes = True
