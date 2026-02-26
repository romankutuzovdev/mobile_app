import httpx
from typing import Optional, Dict, Any
import logging
import json

from app.config import settings

logger = logging.getLogger(__name__)

# Настройка логирования для вывода в консоль
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
console_handler.setFormatter(formatter)
logger.addHandler(console_handler)
logger.setLevel(logging.INFO)


class ChatGPTVINService:
    """Сервис для декодирования VIN через ChatGPT API"""

    BASE_URL = "https://api.openai.com/v1/chat/completions"

    @staticmethod
    async def decode_vin(vin: str) -> Optional[Dict[str, Any]]:
        """
        Декодирование VIN через ChatGPT API
        
        Args:
            vin: VIN код (17 символов)
            
        Returns:
            dict: Полная информация о машине или None при ошибке
        """
        if len(vin) != 17:
            return None

        if not settings.OPENAI_API_KEY:
            logger.error("❌ [ChatGPT] OPENAI_API_KEY не настроен")
            return None

        logger.info(f"🤖 [ChatGPT] Запрос декодирования VIN: {vin}")

        prompt = f"""Ты — эксперт по VIN-декодированию и автомобилестроительным стандартам (ISO 3779 / ISO 3780 / OEM-структуры).

Разбирай VIN строго по структуре, **только по официальным правилам**, без домыслов и выдуманных данных.

Твоя задача — выполнить **структурный разбор VIN**, используя:
- стандарт ISO 3779 (структура VIN)
- ISO 3780 (WMI — коды производителей)
- открытые таблицы годовых кодов
- заводские схемы (завод, страна производства)
- WMI-каталоги
- коды модельного года
- общие расшифровки VDS/VIS
- проверенные принципы кодирования производителей

⚠️ **Правила:**
- Не использовать закрытые OEM-базы (EPC, VeDoc, ETKA, ETK и т.д.)
- Не придумывать технические характеристики, которых нет в VIN
- Использовать только публичные стандарты и VIN-структуру
- Если символьная серия не имеет публичной расшифровки — честно указывать это
- Не придумывай, какие именно двигатель, объём, мощность или комплектация — если VIN их не содержит
- Пиши только то, что можно определить **по структуре VIN**, а не по базам производителей

Если точная информация невозможна — указывай:
"Нет точной информации. Возможные варианты:"
и приводи только реальные варианты, основанные на данных серии модели.

**Разбор VIN: {vin}**

Выполни структурный разбор:
1) **WMI** (символы 1-3): страна, производитель, тип автомобиля
2) **VDS** (символы 4-9): модельная серия, тип кузова/модели, ограничения
3) **Контрольная цифра** (символ 9): является ли она контрольной или заглушкой
4) **Год модели** (символ 10): расшифровка по таблице модельных годов
5) **Завод** (символ 11): расшифровка завода (если данные доступны)
6) **Серийный номер** (символы 12-17): уникальный номер, характеристик не содержит

**Отвечай строго в формате JSON** с ключами:
- vin
- basic_info (объект с полями: brand, model, series, body_type, generation, year, assembly_plant, manufacturer, country)
- engine (объект с полями: type, code, volume_l, power_hp, cylinders, aspiration, fuel_system, notes) - только если можно определить из VIN
- transmission (объект с полями: type, gears, drive, notes) - только если можно определить из VIN
- dimensions (объект с полями: length_mm, width_mm, height_mm, wheelbase_mm, curb_weight_kg, max_weight_kg) - только если можно определить из VIN
- fuel (объект с полями: fuel_type, average_consumption_l_per_100km, tank_l) - только если можно определить из VIN
- safety (объект с полями: airbags, abs, esp, traction_control, side_impact_protection) - только если можно определить из VIN
- possible_trim_levels (массив строк) - возможные варианты на основе серии модели
- notes (строка) - подробный разбор структуры VIN, ограничения и комментарии

Если VIN неверный — укажи причину в notes и не генерируй данные.

Верни ТОЛЬКО валидный JSON без дополнительного текста, markdown разметки или комментариев."""
        prompt = f"""Структурный разбор VIN: {vin} по стандартам ISO, ищи информацию в интернете"""
        headers = {
            "Authorization": f"Bearer {settings.OPENAI_API_KEY}",
            "Content-Type": "application/json"
        }

        # Формируем payload
        payload = {
            "model": settings.OPENAI_MODEL,
            "messages": [
                {
                    "role": "system",
                    "content": "Ты эксперт по расшифровке VIN номеров автомобилей по стандартам ISO 3779/3780. Всегда отвечай только валидным JSON без дополнительного текста, markdown разметки или комментариев."
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            "temperature": 0.1,  # Низкая температура для более точных ответов
            "max_tokens": 3000  # Увеличено для подробных ответов с полной информацией
        }
        
        # response_format поддерживается только для некоторых моделей (gpt-4o, gpt-4o-mini, gpt-4-turbo, gpt-3.5-turbo новее 1106)
        models_with_json_mode = ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-3.5-turbo"]
        if any(model in settings.OPENAI_MODEL.lower() for model in models_with_json_mode):
            payload["response_format"] = {"type": "json_object"}

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    ChatGPTVINService.BASE_URL,
                    headers=headers,
                    json=payload
                )
                response.raise_for_status()
                data = response.json()
                
                # Извлекаем ответ от ChatGPT
                if data.get("choices") and len(data["choices"]) > 0:
                    content = data["choices"][0]["message"]["content"].strip()
                    
                    if not content:
                        logger.error(f"❌ [ChatGPT] Вернул пустой ответ для VIN {vin}")
                        logger.info(f"❌ [ChatGPT] Сервис не дал результатов для VIN {vin}")
                        return None
                    
                    # Убираем markdown код блоки если есть
                    if content.startswith("```json"):
                        content = content[7:]
                    if content.startswith("```"):
                        content = content[3:]
                    if content.endswith("```"):
                        content = content[:-3]
                    content = content.strip()
                    
                    if not content:
                        logger.error(f"❌ [ChatGPT] Вернул пустой контент после очистки для VIN {vin}")
                        logger.info(f"❌ [ChatGPT] Сервис не дал результатов для VIN {vin}")
                        return None
                    
                    # Парсим JSON
                    try:
                        car_info = json.loads(content)
                    except json.JSONDecodeError as e:
                        logger.error(f"❌ [ChatGPT] Ошибка парсинга JSON для VIN {vin}: {str(e)}")
                        logger.error(f"❌ [ChatGPT] Полученный контент (первые 500 символов): {content[:500]}")
                        logger.info(f"❌ [ChatGPT] Сервис не дал результатов для VIN {vin}")
                        return None
                    
                    # Формируем стандартизированный ответ
                    # ChatGPT уже возвращает правильную структуру с basic_info, engine, transmission и т.д.
                    # Убеждаемся, что структура соответствует формату NHTSA
                    if "vin" not in car_info:
                        car_info["vin"] = vin
                    
                    # Извлекаем данные для логирования
                    basic_info = car_info.get("basic_info", {}) if isinstance(car_info.get("basic_info"), dict) else {}
                    brand = basic_info.get("brand") if isinstance(basic_info, dict) else None
                    model = basic_info.get("model") if isinstance(basic_info, dict) else None
                    
                    logger.info(f"✅ [ChatGPT] Успешно декодирован VIN {vin}: {brand} {model}")
                    
                    # Возвращаем структурированный ответ в том же формате, что и NHTSA
                    # car_info уже содержит: vin, basic_info, engine, transmission, dimensions, fuel, safety, possible_trim_levels, notes
                    # Добавляем api_data для совместимости
                    result = car_info.copy()
                    result["api_data"] = car_info  # Полные данные от ChatGPT
                    
                    return result
                
                logger.warning(f"⚠️  [ChatGPT] Не вернул choices для VIN {vin}")
                logger.info(f"❌ [ChatGPT] Сервис не дал результатов для VIN {vin}")
                return None
                
        except httpx.HTTPStatusError as e:
            error_detail = ""
            try:
                error_response = e.response.json()
                error_detail = f" - {error_response}"
            except:
                error_detail = f" - Status: {e.response.status_code}, Text: {e.response.text[:200]}"
            logger.error(f"❌ [ChatGPT] HTTP ошибка для VIN {vin}: {str(e)}{error_detail}")
            logger.info(f"❌ [ChatGPT] Сервис не дал результатов для VIN {vin}")
            return None
        except httpx.RequestError as e:
            logger.error(f"❌ [ChatGPT] Ошибка запроса для VIN {vin}: {str(e)}")
            logger.info(f"❌ [ChatGPT] Сервис не дал результатов для VIN {vin}")
            return None
        except json.JSONDecodeError as e:
            logger.error(f"❌ [ChatGPT] Ошибка парсинга JSON для VIN {vin}: {str(e)}")
            logger.info(f"❌ [ChatGPT] Сервис не дал результатов для VIN {vin}")
            return None
        except Exception as e:
            logger.error(f"❌ [ChatGPT] Неожиданная ошибка для VIN {vin}: {type(e).__name__} - {str(e)}")
            logger.info(f"❌ [ChatGPT] Сервис не дал результатов для VIN {vin}")
            import traceback
            logger.error(traceback.format_exc())
            return None

