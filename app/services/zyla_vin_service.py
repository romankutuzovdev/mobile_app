import httpx
from typing import Optional, Dict, Any
import logging

from app.config import settings

logger = logging.getLogger(__name__)

# Настройка логирования для вывода в консоль
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
console_handler.setFormatter(formatter)
logger.addHandler(console_handler)
logger.setLevel(logging.INFO)


class ZylaVINService:
    """Сервис для декодирования VIN через Zyla Labs API"""

    BASE_URL = "https://zylalabs.com/api/11167/car+specs+and+vin-decoder+api/21129/vin+decode"

    @staticmethod
    async def decode_vin(vin: str) -> Optional[Dict[str, Any]]:
        """
        Декодирование VIN через Zyla Labs API
        
        Args:
            vin: VIN код (17 символов)
            
        Returns:
            dict: Полная информация о машине в структурированном формате или None при ошибке
        """
        if len(vin) != 17:
            return None

        if not settings.ZYLA_KEY:
            logger.error("❌ [Zyla] ZYLA_KEY не настроен")
            return None

        logger.info(f"🔍 [Zyla] Запрос декодирования VIN: {vin}")

        try:
            headers = {
                "Authorization": f"Bearer {settings.ZYLA_KEY}",
                "Content-Type": "application/json"
            }

            payload = {
                "vin": vin.upper()
            }

            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    ZylaVINService.BASE_URL,
                    headers=headers,
                    json=payload
                )
                response.raise_for_status()
                data = response.json()

                # Логируем полный ответ для отладки
                logger.info(f"📋 [Zyla] Полный ответ от API для VIN {vin}: {data}")

                # Проверяем на ошибки в ответе
                if not data or isinstance(data, str):
                    logger.warning(f"⚠️  [Zyla] Неверный формат ответа для VIN {vin}: {data}")
                    logger.info(f"❌ [Zyla] Сервис не дал результатов для VIN {vin}")
                    return None

                # Проверяем, есть ли данные о машине
                # Zyla может возвращать данные в разных форматах (camelCase и PascalCase)
                make = data.get("make") or data.get("Make")
                manufacturer_name = data.get("manufacturerName") or data.get("ManufacturerName")
                
                logger.info(f"🔍 [Zyla] Извлеченные данные для VIN {vin}: make={make}, manufacturerName={manufacturer_name}")
                
                if not make and not manufacturer_name:
                    logger.warning(f"⚠️  [Zyla] Пустой ответ для VIN {vin}. Полученные данные: {data}")
                    logger.info(f"❌ [Zyla] Сервис не дал результатов для VIN {vin}")
                    return None

                # Формируем структурированный ответ в том же формате, что и NHTSA/Vincario
                # Извлекаем год (может быть в разных форматах)
                year = None
                model_year = data.get("modelYear") or data.get("ModelYear") or data.get("model_year")
                if model_year:
                    try:
                        if isinstance(model_year, str):
                            year = int(model_year)
                        else:
                            year = int(model_year)
                    except (ValueError, TypeError):
                        pass

                # Извлекаем данные с учетом разных форматов ответа
                make = data.get("make") or data.get("Make") or None
                manufacturer_name = data.get("manufacturerName") or data.get("ManufacturerName") or None
                vehicle_type = data.get("vehicleType") or data.get("VehicleType") or None

                basic_info = {
                    "brand": make,
                    "model": None,  # Zyla не предоставляет модель напрямую
                    "series": None,
                    "body_type": vehicle_type,
                    "generation": None,
                    "year": year,
                    "assembly_plant": None,
                    "manufacturer": manufacturer_name,
                    "country": None
                }

                # Пытаемся извлечь модель из vehicleDescriptor если возможно
                vehicle_descriptor = data.get("vehicleDescriptor") or data.get("VehicleDescriptor") or ""
                if vehicle_descriptor and vehicle_descriptor != "Not Applicable" and vehicle_descriptor != "":
                    # vehicleDescriptor может содержать информацию о модели
                    basic_info["model"] = vehicle_descriptor

                # Информация о двигателе (Zyla не предоставляет детальную информацию)
                engine_info = {
                    "type": None,
                    "code": None,
                    "volume_l": None,
                    "power_hp": None,
                    "cylinders": None,
                    "aspiration": None,
                    "fuel_system": None,
                    "notes": "Данные о двигателе недоступны в Zyla API"
                }

                # Трансмиссия (Zyla не предоставляет)
                transmission_info = {
                    "type": None,
                    "gears": None,
                    "drive": None,
                    "notes": "Данные о трансмиссии недоступны в Zyla API"
                }

                # Габариты (Zyla не предоставляет)
                dimensions_info = {
                    "length_mm": None,
                    "width_mm": None,
                    "height_mm": None,
                    "wheelbase_mm": None,
                    "curb_weight_kg": None,
                    "max_weight_kg": None
                }

                # Топливо (Zyla не предоставляет)
                fuel_info = {
                    "fuel_type": None,
                    "average_consumption_l_per_100km": None,
                    "tank_l": None
                }

                # Безопасность (Zyla не предоставляет)
                safety_info = {
                    "airbags": None,
                    "abs": None,
                    "esp": None,
                    "traction_control": None,
                    "side_impact_protection": None
                }

                # Возможные комплектации
                possible_trim_levels = []
                possible_values = data.get("possibleValues") or data.get("PossibleValues") or ""
                if possible_values and possible_values != "" and possible_values != "Not Applicable":
                    # Если есть возможные значения, можно попытаться их распарсить
                    if isinstance(possible_values, str):
                        possible_trim_levels = [possible_values]
                    elif isinstance(possible_values, list):
                        possible_trim_levels = possible_values

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
                    "notes": f"Данные получены из Zyla Labs API. VIN проверен: {vin.upper()}. CheckDigit валидность: {data.get('isValidCheckDigit') or data.get('IsValidCheckDigit') or 'unknown'}",
                    "api_data": data  # Полные данные от Zyla
                }

                brand = basic_info.get("brand")
                model = basic_info.get("model")
                logger.info(f"✅ [Zyla] Успешно декодирован VIN {vin}: {brand} {model}")

                return car_info

        except httpx.HTTPStatusError as e:
            error_detail = ""
            try:
                error_response = e.response.json()
                error_detail = f" - {error_response}"
            except:
                error_detail = f" - Status: {e.response.status_code}, Text: {e.response.text[:200]}"
            logger.error(f"❌ [Zyla] HTTP ошибка для VIN {vin}: {str(e)}{error_detail}")
            logger.info(f"❌ [Zyla] Сервис не дал результатов для VIN {vin}")
            return None
        except httpx.RequestError as e:
            logger.error(f"❌ [Zyla] Ошибка запроса для VIN {vin}: {str(e)}")
            logger.info(f"❌ [Zyla] Сервис не дал результатов для VIN {vin}")
            return None
        except Exception as e:
            logger.error(f"❌ [Zyla] Неожиданная ошибка для VIN {vin}: {type(e).__name__} - {str(e)}")
            logger.info(f"❌ [Zyla] Сервис не дал результатов для VIN {vin}")
            import traceback
            logger.error(traceback.format_exc())
            return None

