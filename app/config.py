from pydantic_settings import BaseSettings
from pydantic import ConfigDict
from typing import Optional


class Settings(BaseSettings):
    model_config = ConfigDict(
        # Ищем .env и в корне проекта, и в папке app
        env_file=(".env", "app/.env"),
        case_sensitive=True,
        extra='ignore'  # Игнорировать лишние поля из .env
    )
    
    # Database
    DATABASE_URL: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/auto_db"
    
    # JWT
    SECRET_KEY: str = "your-secret-key-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 525600  # 1 год (365 дней * 24 часа * 60 минут)
    REFRESH_TOKEN_EXPIRE_DAYS: int = 365  # 1 год
    
    # App
    APP_NAME: str = "FastAPI JWT Auth"
    DEBUG: bool = True
    
    # OpenAI/ChatGPT API
    OPENAI_API_KEY: str = ""
    # gpt-4o-mini — ~10–20x дешевле gpt-4o, подходит для чата; gpt-4o — для сложных задач
    OPENAI_MODEL: str = "gpt-4o-mini"
    # Прокси для OpenAI API (если требуется обход региональных ограничений)
    OPENAI_PROXY: Optional[str] = None
    
    # Zyla Labs API
    ZYLA_KEY: str = ""
    
    # Qdrant Vector Database
    QDRANT_URL: str = "http://localhost:6333"
    QDRANT_API_KEY: Optional[str] = None


settings = Settings()

