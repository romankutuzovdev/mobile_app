import httpx
from typing import List, Dict, Any, Optional
import logging

from app.config import settings

logger = logging.getLogger(__name__)

# Лимит сообщений в истории (user+assistant пары) — экономия токенов
MAX_HISTORY_MESSAGES = 20


class ChatGPTVehicleService:
    """Сервис общения с ChatGPT по конкретному автомобилю"""

    BASE_URL = "https://api.openai.com/v1/chat/completions"

    @staticmethod
    async def ask_vehicle_question(
        vehicle_text_block: str,
        question: str,
        history: Optional[List[Dict[str, str]]] = None,
    ) -> str:
        """
        Отправка вопроса в ChatGPT с контекстом автомобиля и историей диалога.
        history: список {"role": "user"|"assistant", "content": "..."}
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

        messages: List[Dict[str, str]] = [
            {"role": "system", "content": system_prompt},
        ]
        if history:
            messages.extend(history[-MAX_HISTORY_MESSAGES:])
        messages.append({"role": "user", "content": question})

        headers = {
            "Authorization": f"Bearer {settings.OPENAI_API_KEY}",
            "Content-Type": "application/json",
        }

        payload = {
            "model": settings.OPENAI_MODEL,
            "messages": messages,
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


