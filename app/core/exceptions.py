from fastapi import HTTPException, status


class AuthException(HTTPException):
    def __init__(self, detail: str = "Authentication failed"):
        super().__init__(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=detail,
            headers={"WWW-Authenticate": "Bearer"},
        )


class CredentialsException(AuthException):
    def __init__(self, detail: str = "Could not validate credentials"):
        super().__init__(detail=detail)


class TokenExpiredException(AuthException):
    def __init__(self, detail: str = "Token has expired"):
        super().__init__(detail=detail)


class InvalidTokenException(AuthException):
    def __init__(self, detail: str = "Invalid token"):
        super().__init__(detail=detail)


class UserNotFoundException(HTTPException):
    def __init__(self, detail: str = "User not found"):
        super().__init__(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=detail,
        )


class UserAlreadyExistsException(HTTPException):
    def __init__(self, detail: str = "User already exists"):
        super().__init__(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=detail,
        )

