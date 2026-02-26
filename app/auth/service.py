from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime, timedelta

from app.models.user import User
from app.models.refresh_token import RefreshToken
from app.core.security import get_password_hash, verify_password
from app.core.exceptions import UserAlreadyExistsException
from app.config import settings
from app.services.sms_service import SMSCService


async def get_user_by_email(db: AsyncSession, email: str) -> User | None:
    """Получение пользователя по email"""
    result = await db.execute(select(User).where(User.email == email))
    return result.scalar_one_or_none()


async def get_user_by_id(db: AsyncSession, user_id: int) -> User | None:
    """Получение пользователя по ID"""
    result = await db.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()


async def get_user_by_username(db: AsyncSession, username: str) -> User | None:
    """Получение пользователя по username"""
    result = await db.execute(select(User).where(User.username == username))
    return result.scalar_one_or_none()


async def get_user_by_phone(db: AsyncSession, phone: str) -> User | None:
    """Получение пользователя по телефону"""
    result = await db.execute(select(User).where(User.phone == phone))
    return result.scalar_one_or_none()


async def create_user(
    db: AsyncSession, 
    phone: str, 
    password: str,
    email: str = None,
    username: str = None
) -> User:
    """Создание нового пользователя с телефоном"""
    # Проверка существования пользователя по телефону
    existing_user = await get_user_by_phone(db, phone)
    if existing_user:
        raise UserAlreadyExistsException("User with this phone already exists")
    
    # Проверка email если указан
    if email:
        existing_email = await get_user_by_email(db, email)
        if existing_email:
            raise UserAlreadyExistsException("User with this email already exists")
    
    # Проверка username если указан
    if username:
        existing_username = await get_user_by_username(db, username)
        if existing_username:
            raise UserAlreadyExistsException("User with this username already exists")
    
    # Создание пользователя
    hashed_password = get_password_hash(password)
    db_user = User(
        phone=phone,
        email=email,
        username=username,
        hashed_password=hashed_password,
        phone_verified=False
    )
    db.add(db_user)
    await db.commit()
    await db.refresh(db_user)
    return db_user


async def send_verification_code(db: AsyncSession, phone: str) -> bool:
    """Отправка кода подтверждения на телефон"""
    user = await get_user_by_phone(db, phone)
    if not user:
        raise ValueError("Пользователь с таким телефоном не найден")
    
    # Генерация и отправка кода
    code, error = await SMSCService.send_verification_code(phone)
    if error:
        raise ValueError(f"Ошибка отправки SMS: {error}")
    
    # Сохранение кода в БД
    user.verification_code = code
    user.verification_code_expires_at = datetime.utcnow() + timedelta(minutes=10)  # Код действителен 10 минут
    await db.commit()
    
    return True


async def verify_phone_code(db: AsyncSession, phone: str, code: str) -> bool:
    """Проверка кода подтверждения"""
    user = await get_user_by_phone(db, phone)
    if not user:
        raise ValueError("Пользователь с таким телефоном не найден")
    
    # Проверка кода
    if not user.verification_code:
        raise ValueError("Код подтверждения не был отправлен")
    
    if user.verification_code != code:
        raise ValueError("Неверный код подтверждения")
    
    # Проверка срока действия
    if user.verification_code_expires_at and datetime.utcnow() > user.verification_code_expires_at:
        raise ValueError("Код подтверждения истек")
    
    # Подтверждение телефона
    user.phone_verified = True
    user.verification_code = None
    user.verification_code_expires_at = None
    await db.commit()
    
    return True


async def authenticate_user(
    db: AsyncSession, 
    password: str,
    email: str = None,
    phone: str = None
) -> User | None:
    """Аутентификация пользователя по email или телефону"""
    user = None
    
    # Ищем пользователя по телефону или email
    if phone:
        user = await get_user_by_phone(db, phone)
    elif email:
        user = await get_user_by_email(db, email)
    else:
        return None
    
    if not user:
        return None
    
    if not verify_password(password, user.hashed_password):
        return None
    
    return user


async def create_refresh_token_record(db: AsyncSession, user_id: int, token: str) -> RefreshToken:
    """Создание записи refresh token в БД"""
    expires_at = datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    
    db_token = RefreshToken(
        user_id=user_id,
        token=token,
        expires_at=expires_at
    )
    db.add(db_token)
    await db.commit()
    await db.refresh(db_token)
    return db_token


async def get_refresh_token(db: AsyncSession, token: str) -> RefreshToken | None:
    """Получение refresh token из БД"""
    result = await db.execute(select(RefreshToken).where(RefreshToken.token == token))
    return result.scalar_one_or_none()


async def delete_refresh_token(db: AsyncSession, token: str) -> None:
    """Удаление refresh token из БД"""
    db_token = await get_refresh_token(db, token)
    if db_token:
        await db.delete(db_token)
        await db.commit()


async def delete_all_user_refresh_tokens(db: AsyncSession, user_id: int) -> None:
    """Удаление всех refresh tokens пользователя"""
    result = await db.execute(select(RefreshToken).where(RefreshToken.user_id == user_id))
    tokens = result.scalars().all()
    for token in tokens:
        await db.delete(token)
    await db.commit()

