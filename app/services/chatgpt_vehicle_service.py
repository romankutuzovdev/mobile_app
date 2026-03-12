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
        if not settings.OPENAI_API_KEY or not str(settings.OPENAI_API_KEY).strip():
            logger.error("❌ [ChatGPTVehicleService] OPENAI_API_KEY пустой или не задан")
            raise RuntimeError("OPENAI_API_KEY не настроен. Добавьте ключ в .env")

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

        # Прокси для доступа к OpenAI (регионы, где API заблокирован)
        client_kwargs = {"timeout": 120.0}
        if getattr(settings, "OPENAI_PROXY", None) and str(settings.OPENAI_PROXY).strip():
            client_kwargs["proxy"] = settings.OPENAI_PROXY
            logger.info("🔧 [ChatGPTVehicleService] Используется прокси: %s", settings.OPENAI_PROXY[:50] + "..." if len(str(settings.OPENAI_PROXY)) > 50 else settings.OPENAI_PROXY)

        # Даём модели больше времени на ответ, т.к. запросы могут быть "тяжёлыми"
        async with httpx.AsyncClient(**client_kwargs) as client:
            logger.info(
                "🔧 [ChatGPTVehicleService] Запрос к ChatGPT: model=%s, question_len=%d",
                settings.OPENAI_MODEL,
                len(question),
            )
            try:
                response = await client.post(
                    ChatGPTVehicleService.BASE_URL,
                    headers=headers,
                    json=payload,
                )
            except (httpx.ConnectError, httpx.TimeoutException, httpx.RequestError) as req_err:
                import sys
                err_detail = f"{type(req_err).__name__}: {req_err}"
                logger.error("❌ [ChatGPTVehicleService] Сетевая ошибка: %s", err_detail)
                sys.stderr.write(f"[CHAT] Сетевая ошибка при обращении к OpenAI: {err_detail}\n")
                sys.stderr.write("[CHAT] Возможно, OpenAI заблокирован в регионе. Настройте OPENAI_PROXY в .env\n")
                sys.stderr.flush()
                raise RuntimeError(f"Не удалось подключиться к OpenAI: {err_detail}") from req_err
            if response.status_code >= 400:
                # Логируем тело ошибки целиком для отладки
                try:
                    error_json = response.json()
                except Exception:
                    error_json = response.text
                err_msg = f"HTTP {response.status_code}: {error_json}"
                logger.error("❌ [ChatGPTVehicleService] %s", err_msg)
                # В stderr для docker logs
                import sys
                sys.stderr.write(f"[CHAT] ChatGPT API error: {err_msg}\n")
                sys.stderr.flush()
                response.raise_for_status()

            data = response.json()

        choices: List[dict] = data.get("choices") or []
        if not choices:
            raise RuntimeError("ChatGPT вернул пустой ответ")

        content = (choices[0].get("message") or {}).get("content") or ""
        return content.strip()


