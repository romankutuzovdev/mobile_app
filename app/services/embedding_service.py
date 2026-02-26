from typing import List
from openai import AsyncOpenAI
from app.config import settings

import logging

logger = logging.getLogger(__name__)


class EmbeddingService:
    """Сервис для получения embeddings через OpenAI"""

    MODEL = "text-embedding-3-small"  # 1536 размерность

    def __init__(self):
        if not settings.OPENAI_API_KEY:
            raise ValueError("OPENAI_API_KEY не настроен в конфигурации")
        
        # Настройка клиента с возможностью использования прокси
        client_kwargs = {"api_key": settings.OPENAI_API_KEY}
        
        # Если указан прокси в настройках, используем его
        if hasattr(settings, 'OPENAI_PROXY') and settings.OPENAI_PROXY:
            import httpx
            client_kwargs["http_client"] = httpx.AsyncClient(proxy=settings.OPENAI_PROXY)
        
        self.client = AsyncOpenAI(**client_kwargs)

    async def get_embedding(self, text: str) -> List[float]:
        """Получение embedding для текста"""
        try:
            response = await self.client.embeddings.create(
                model=self.MODEL,
                input=text
            )
            
            return response.data[0].embedding
        except Exception as e:
            error_msg = str(e)
            logger.error(f"Ошибка при получении embedding: {error_msg}")
            
            # Специальная обработка ошибки региона
            if "unsupported_country_region_territory" in error_msg or "403" in error_msg:
                raise ValueError(
                    "OpenAI API недоступен в вашем регионе. "
                    "Решения:\n"
                    "1. Используйте VPN или прокси (настройте OPENAI_PROXY в .env)\n"
                    "2. Используйте альтернативный сервис для embeddings\n"
                    "3. Проверьте настройки вашего OpenAI аккаунта"
                )
            
            raise ValueError(f"Ошибка при получении embedding: {error_msg}")
