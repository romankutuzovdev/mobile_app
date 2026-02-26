from datetime import datetime, timedelta
from typing import Optional
import hashlib
import bcrypt
from jose import JWTError, jwt

from app.config import settings


def _prepare_password_for_bcrypt(password: str) -> bytes:
    """
    Подготовка пароля для bcrypt.
    Если пароль длиннее 72 байт, используем SHA-256 для предварительного хеширования.
    """
    password_bytes = password.encode('utf-8')
    if len(password_bytes) > 72:
        # Предварительное хеширование SHA-256 для длинных паролей
        return hashlib.sha256(password_bytes).digest()
    return password_bytes


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Проверка пароля"""
    try:
        prepared_password = _prepare_password_for_bcrypt(plain_password)
        return bcrypt.checkpw(prepared_password, hashed_password.encode('utf-8'))
    except Exception:
        return False


def get_password_hash(password: str) -> str:
    """Хеширование пароля"""
    prepared_password = _prepare_password_for_bcrypt(password)
    # Генерируем соль и хешируем пароль
    salt = bcrypt.gensalt(rounds=12)
    hashed = bcrypt.hashpw(prepared_password, salt)
    return hashed.decode('utf-8')


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Создание access token"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire, "type": "access"})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt


def create_refresh_token(data: dict) -> str:
    """Создание refresh token"""
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode.update({"exp": expire, "type": "refresh"})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt


def decode_token(token: str) -> Optional[dict]:
    """Декодирование токена"""
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        return payload
    except JWTError:
        # Токен истек, неверный формат или подпись
        return None
    except Exception:
        # Любая другая ошибка
        return None

