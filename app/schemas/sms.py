from pydantic import BaseModel, Field


class SendVerificationCodeRequest(BaseModel):
    phone: str = Field(..., min_length=10, max_length=15, description="Номер телефона")


class SendVerificationCodeResponse(BaseModel):
    message: str = "Код подтверждения отправлен на ваш телефон"
    success: bool = True


class VerifyPhoneRequest(BaseModel):
    phone: str = Field(..., min_length=10, max_length=15, description="Номер телефона")
    code: str = Field(..., min_length=4, max_length=10, description="Код подтверждения")


class VerifyPhoneResponse(BaseModel):
    message: str = "Телефон успешно подтвержден"
    success: bool = True

