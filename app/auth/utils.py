from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.core.security import decode_token
from app.core.exceptions import CredentialsException, InvalidTokenException
from app.auth.service import get_user_by_id

security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db)
):
    """Получение текущего пользователя из токена"""
    token = credentials.credentials
    
    if not token:
        raise CredentialsException("Token is missing")
    
    payload = decode_token(token)
    
    if payload is None:
        raise CredentialsException("Invalid or expired token. Please login again or refresh your token.")
    
    token_type = payload.get("type")
    if token_type != "access":
        raise InvalidTokenException(f"Invalid token type. Expected 'access', got '{token_type}'. Use access_token for API requests, refresh_token only for /auth/refresh endpoint.")
    
    user_id_str = payload.get("sub")
    if user_id_str is None:
        raise CredentialsException("Token does not contain user ID")
    
    # Преобразуем строку обратно в int
    try:
        user_id = int(user_id_str)
    except (ValueError, TypeError):
        raise CredentialsException("Invalid user ID in token")
    
    user = await get_user_by_id(db, user_id)
    if user is None:
        raise CredentialsException("User not found")
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is disabled"
        )
    
    return user

