import httpx
from typing import Optional, Dict, Any
import logging
import hashlib

from app.config import settings

logger = logging.getLogger(__name__)

# Настройка логирования для вывода в консоль
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
console_handler.setFormatter(formatter)
logger.addHandler(console_handler)
logger.setLevel(logging.INFO)


class VincarioVINService:
    """Сервис для декодирования VIN через Vincario API"""

    BASE_URL = "https://api.vincario.com/3.2/"
    ID_DECODE = "decode"

    @staticmethod
    def _calculate_control_sum(vin: str, api_key: str, secret_key: str) -> str:
        """
        Вычисление контрольной суммы для Vincario API
        
        Control sum = первые 10 символов SHA1(VIN|ID|API key|Secret key)
        VIN должен быть в UPPER CASE
        """
        vin_upper = vin.upper()
        string_to_hash = f"{vin_upper}|{VincarioVINService.ID_DECODE}|{api_key}|{secret_key}"
        sha1_hash = hashlib.sha1(string_to_hash.encode('utf-8')).hexdigest()
        return sha1_hash[:10]

    @staticmethod
    async def decode_vin(vin: str) -> Optional[Dict[str, Any]]:
        """
        Декодирование VIN через Vincario API
        
        Args:
            vin: VIN код (17 символов)
            
        Returns:
            dict: Полная информация о машине в структурированном формате или None при ошибке
        """
        if len(vin) != 17:
            return None

        if not settings.VINCARIO_API_KEY or not settings.VINCARIO_SECRET_KEY:
            logger.error("❌ [Vincario] VINCARIO_API_KEY или VINCARIO_SECRET_KEY не настроены")
            return None

        logger.info(f"🔍 [Vincario] Запрос декодирования VIN: {vin}")

        try:
            # Вычисляем контрольную сумму
            control_sum = VincarioVINService._calculate_control_sum(
                vin, 
                settings.VINCARIO_API_KEY, 
                settings.VINCARIO_SECRET_KEY
            )

            # Формируем URL с параметрами
            params = {
                "id": VincarioVINService.ID_DECODE,
                "key": settings.VINCARIO_API_KEY,
                "control": control_sum,
                "vin": vin.upper()
            }

            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    VincarioVINService.BASE_URL,
                    params=params
                )
                response.raise_for_status()
                data = response.json()

                # Проверяем на ошибки в ответе
                if data.get("error"):
                    error_msg = data.get("error", {}).get("message", "Unknown error")
                    logger.warning(f"⚠️  [Vincario] Ошибка для VIN {vin}: {error_msg}")
                    logger.info(f"❌ [Vincario] Сервис не дал результатов для VIN {vin}")
                    return None

                # Извлекаем данные о машине
                vehicle_data = data.get("vehicle", {})
                if not vehicle_data:
                    logger.warning(f"⚠️  [Vincario] Пустой ответ для VIN {vin}")
                    logger.info(f"❌ [Vincario] Сервис не дал результатов для VIN {vin}")
                    return None

                # Формируем структурированный ответ в том же формате, что и NHTSA/ChatGPT
                basic_info = {
                    "brand": vehicle_data.get("make") or None,
                    "model": vehicle_data.get("model") or None,
                    "series": vehicle_data.get("series") or None,
                    "body_type": vehicle_data.get("body") or None,
                    "generation": vehicle_data.get("generation") or None,
                    "year": vehicle_data.get("year") or None,
                    "assembly_plant": vehicle_data.get("plant") or None,
                    "manufacturer": vehicle_data.get("manufacturer") or None,
                    "country": vehicle_data.get("country") or None
                }

                # Информация о двигателе
                engine_data = vehicle_data.get("engine", {})
                engine_info = {
                    "type": engine_data.get("type") if isinstance(engine_data, dict) else None,
                    "code": engine_data.get("code") if isinstance(engine_data, dict) else None,
                    "volume_l": engine_data.get("displacement") if isinstance(engine_data, dict) else None,
                    "power_hp": engine_data.get("power") if isinstance(engine_data, dict) else None,
                    "cylinders": engine_data.get("cylinders") if isinstance(engine_data, dict) else None,
                    "aspiration": engine_data.get("aspiration") if isinstance(engine_data, dict) else None,
                    "fuel_system": engine_data.get("fuel_system") if isinstance(engine_data, dict) else None,
                    "notes": None
                }

                # Трансмиссия
                transmission_data = vehicle_data.get("transmission", {})
                transmission_info = {
                    "type": transmission_data.get("type") if isinstance(transmission_data, dict) else None,
                    "gears": transmission_data.get("gears") if isinstance(transmission_data, dict) else None,
                    "drive": vehicle_data.get("drive") or None,
                    "notes": None
                }

                # Габариты
                dimensions_data = vehicle_data.get("dimensions", {})
                dimensions_info = {
                    "length_mm": dimensions_data.get("length") if isinstance(dimensions_data, dict) else None,
                    "width_mm": dimensions_data.get("width") if isinstance(dimensions_data, dict) else None,
                    "height_mm": dimensions_data.get("height") if isinstance(dimensions_data, dict) else None,
                    "wheelbase_mm": dimensions_data.get("wheelbase") if isinstance(dimensions_data, dict) else None,
                    "curb_weight_kg": vehicle_data.get("weight") or None,
                    "max_weight_kg": vehicle_data.get("gvwr") or None
                }

                # Топливо
                fuel_info = {
                    "fuel_type": vehicle_data.get("fuel") or None,
                    "average_consumption_l_per_100km": None,  # Vincario обычно не предоставляет
                    "tank_l": vehicle_data.get("tank_capacity") or None
                }

                # Безопасность
                safety_info = {
                    "airbags": vehicle_data.get("airbags") or None,
                    "abs": vehicle_data.get("abs") or None,
                    "esp": vehicle_data.get("esp") or None,
                    "traction_control": vehicle_data.get("traction_control") or None,
                    "side_impact_protection": vehicle_data.get("side_impact_protection") or None
                }

                # Возможные комплектации
                possible_trim_levels = vehicle_data.get("trim_levels", [])
                if not isinstance(possible_trim_levels, list):
                    possible_trim_levels = []

                # Формируем полный ответ
                car_info = {
                    "vin": vin.upper(),
                    "basic_info": basic_info,
                    "engine": engine_info,
                    "transmission": transmission_info,
                    "dimensions": dimensions_info,
                    "fuel": fuel_info,
                    "safety": safety_info,
                    "possible_trim_levels": possible_trim_levels,
                    "notes": f"Данные получены из Vincario API. VIN проверен: {vin.upper()}",
                    "api_data": data  # Полные данные от Vincario
                }

                brand = basic_info.get("brand")
                model = basic_info.get("model")
                logger.info(f"✅ [Vincario] Успешно декодирован VIN {vin}: {brand} {model}")

                return car_info

        except httpx.HTTPStatusError as e:
            error_detail = ""
            try:
                error_response = e.response.json()
                error_detail = f" - {error_response}"
            except:
                error_detail = f" - Status: {e.response.status_code}, Text: {e.response.text[:200]}"
            logger.error(f"❌ [Vincario] HTTP ошибка для VIN {vin}: {str(e)}{error_detail}")
            logger.info(f"❌ [Vincario] Сервис не дал результатов для VIN {vin}")
            return None
        except httpx.RequestError as e:
            logger.error(f"❌ [Vincario] Ошибка запроса для VIN {vin}: {str(e)}")
            logger.info(f"❌ [Vincario] Сервис не дал результатов для VIN {vin}")
            return None
        except Exception as e:
            logger.error(f"❌ [Vincario] Неожиданная ошибка для VIN {vin}: {type(e).__name__} - {str(e)}")
            logger.info(f"❌ [Vincario] Сервис не дал результатов для VIN {vin}")
            import traceback
            logger.error(traceback.format_exc())
            return None

