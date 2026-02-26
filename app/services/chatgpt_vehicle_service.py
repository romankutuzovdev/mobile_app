import httpx
from typing import List
import logging

from app.config import settings

logger = logging.getLogger(__name__)


class ChatGPTVehicleService:
    """Сервис общения с ChatGPT по конкретному автомобилю"""

    BASE_URL = "https://api.openai.com/v1/chat/completions"

    @staticmethod
    async def ask_vehicle_question(
        vehicle_text_block: str,
        question: str,
    ) -> str:
        """
        Отправка вопроса в ChatGPT с системным промптом про конкретный автомобиль.
        Возвращает только текст ответа ассистента.
        """
        if not settings.OPENAI_API_KEY:
            raise RuntimeError("OPENAI_API_KEY не настроен")

        system_prompt = (
            "You are an automotive expert.\n\n"
            "You answer questions ONLY about the given vehicle.\n"
            "If information is unknown or depends on exact configuration,\n"
            "say that it needs clarification and do NOT guess.\n\n"
            "Vehicle data:\n"
            f"{vehicle_text_block}"
        )

        headers = {
            "Authorization": f"Bearer {settings.OPENAI_API_KEY}",
            "Content-Type": "application/json",
        }

        payload = {
            "model": settings.OPENAI_MODEL,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": question},
            ],
        }

        # Даём модели больше времени на ответ, т.к. запросы могут быть "тяжёлыми"
        async with httpx.AsyncClient(timeout=120.0) as client:
            logger.info(
                "🔧 [ChatGPTVehicleService] Запрос к ChatGPT: model=%s, question_len=%d",
                settings.OPENAI_MODEL,
                len(question),
            )
            response = await client.post(
                ChatGPTVehicleService.BASE_URL,
                headers=headers,
                json=payload,
            )
            if response.status_code >= 400:
                # Логируем тело ошибки целиком для отладки
                try:
                    error_json = response.json()
                except Exception:
                    error_json = response.text
                logger.error(
                    "❌ [ChatGPTVehicleService] HTTP %s: %s",
                    response.status_code,
                    error_json,
                )
                response.raise_for_status()

            data = response.json()

        choices: List[dict] = data.get("choices") or []
        if not choices:
            raise RuntimeError("ChatGPT вернул пустой ответ")

        content = (choices[0].get("message") or {}).get("content") or ""
        return content.strip()


