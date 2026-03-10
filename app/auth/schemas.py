from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import datetime


class UserBase(BaseModel):
    phone: str = Field(..., min_length=10, max_length=15, description="Номер телефона")
    email: Optional[EmailStr] = None
    username: Optional[str] = Field(None, min_length=3, max_length=50)


class UserCreate(UserBase):
    password: str = Field(..., min_length=8)


class UserLogin(BaseModel):
    email: Optional[EmailStr] = None
    phone: Optional[str] = Field(None, min_length=1, max_length=15)
    password: str
    
    def model_post_init(self, __context):
        if not self.email and not self.phone:
            raise ValueError("Необходимо указать email или phone")


class UserResponse(BaseModel):
    id: int
    phone: Optional[str] = None
    email: Optional[str] = None
    username: Optional[str] = None
    is_active: bool
    is_superuser: bool
    phone_verified: bool = False
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class TokenRefresh(BaseModel):
    refresh_token: str


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str = Field(..., min_length=8)


class TokenData(BaseModel):
    user_id: Optional[int] = None
    email: Optional[str] = None
