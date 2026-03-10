from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from datetime import timedelta, datetime

from app.database import get_db
from app.auth.schemas import UserCreate, UserLogin, UserResponse, Token, TokenRefresh, ChangePasswordRequest
from app.auth.service import (
    create_user,
    authenticate_user,
    create_refresh_token_record,
    get_refresh_token,
    delete_refresh_token,
    get_user_by_id,
    send_verification_code,
    verify_phone_code,
    change_password as change_password_service,
)
from app.schemas.sms import (
    SendVerificationCodeRequest,
    SendVerificationCodeResponse,
    VerifyPhoneRequest,
    VerifyPhoneResponse
)
from app.auth.utils import get_current_user
from app.models.user import User
from app.core.security import create_access_token, create_refresh_token, decode_token
from app.core.exceptions import InvalidTokenException, TokenExpiredException
from app.config import settings

router = APIRouter()


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register(
    user_data: UserCreate,
    db: AsyncSession = Depends(get_db)
):
    """Регистрация нового пользователя с телефоном"""
    try:
        user = await create_user(
            db=db,
            phone=user_data.phone,
            password=user_data.password,
            email=user_data.email,
            username=user_data.username
        )
        return user
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.post("/send-verification-code", response_model=SendVerificationCodeResponse)
async def send_code(
    request: SendVerificationCodeRequest,
    db: AsyncSession = Depends(get_db)
):
    """Отправка кода подтверждения на телефон"""
    try:
        await send_verification_code(db, request.phone)
        return SendVerificationCodeResponse()
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.post("/verify-phone", response_model=VerifyPhoneResponse)
async def verify_phone(
    request: VerifyPhoneRequest,
    db: AsyncSession = Depends(get_db)
):
    """Подтверждение телефона кодом"""
    try:
        await verify_phone_code(db, request.phone, request.code)
        return VerifyPhoneResponse()
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.post("/login", response_model=Token)
async def login(
    user_data: UserLogin,
    db: AsyncSession = Depends(get_db)
):
    """Вход пользователя и получение токенов"""
    user = await authenticate_user(
        db=db,
        password=user_data.password,
        email=user_data.email,
        phone=user_data.phone
    )
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is disabled"
        )
    
    # Создание токенов
    # jose требует, чтобы sub был строкой
    access_token = create_access_token(
        data={"sub": str(user.id), "phone": user.phone or user.email}
    )
    refresh_token = create_refresh_token(
        data={"sub": str(user.id), "phone": user.phone or user.email}
    )
    
    # Сохранение refresh token в БД
    await create_refresh_token_record(db, user.id, refresh_token)
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer"
    }


@router.post("/refresh", response_model=Token)
async def refresh_token(
    token_data: TokenRefresh,
    db: AsyncSession = Depends(get_db)
):
    """Обновление access token через refresh token"""
    refresh_token = token_data.refresh_token
    
    # Проверка токена в БД
    db_token = await get_refresh_token(db, refresh_token)
    if not db_token:
        raise InvalidTokenException("Refresh token not found")
    
    # Проверка срока действия
    if datetime.utcnow() > db_token.expires_at:
        await delete_refresh_token(db, refresh_token)
        raise TokenExpiredException("Refresh token has expired")
    
    # Декодирование токена
    payload = decode_token(refresh_token)
    if payload is None:
        await delete_refresh_token(db, refresh_token)
        raise InvalidTokenException("Invalid refresh token")
    
    token_type = payload.get("type")
    if token_type != "refresh":
        raise InvalidTokenException("Invalid token type")
    
    user_id_str = payload.get("sub")
    if user_id_str is None:
        raise InvalidTokenException("Invalid token payload")
    
    # Преобразуем строку обратно в int
    try:
        user_id = int(user_id_str)
    except (ValueError, TypeError):
        raise InvalidTokenException("Invalid user ID in token")
    
    # Проверка пользователя
    user = await get_user_by_id(db, user_id)
    if not user or not user.is_active:
        await delete_refresh_token(db, refresh_token)
        raise InvalidTokenException("User not found or inactive")
    
    # Создание новых токенов
    # jose требует, чтобы sub был строкой
    new_access_token = create_access_token(
        data={"sub": str(user.id), "phone": user.phone or user.email}
    )
    new_refresh_token = create_refresh_token(
        data={"sub": str(user.id), "phone": user.phone or user.email}
    )
    
    # Удаление старого refresh token и создание нового
    await delete_refresh_token(db, refresh_token)
    await create_refresh_token_record(db, user.id, new_refresh_token)
    
    return {
        "access_token": new_access_token,
        "refresh_token": new_refresh_token,
        "token_type": "bearer"
    }


@router.get("/me", response_model=UserResponse)
async def get_current_user_info(
    current_user: User = Depends(get_current_user)
):
    """Получение информации о текущем пользователе"""
    return current_user


@router.patch("/change-password")
async def change_password(
    request: ChangePasswordRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Смена пароля текущего пользователя"""
    success = await change_password_service(
        db=db,
        user_id=current_user.id,
        current_password=request.current_password,
        new_password=request.new_password
    )
    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Неверный текущий пароль"
        )
    return {"message": "Пароль успешно изменён"}


@router.post("/logout")
async def logout(
    token_data: TokenRefresh,
    db: AsyncSession = Depends(get_db)
):
    """Выход пользователя (удаление refresh token)"""
    await delete_refresh_token(db, token_data.refresh_token)
    return {"message": "Successfully logged out"}

