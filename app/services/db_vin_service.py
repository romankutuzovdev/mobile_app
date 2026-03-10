"""Сервис пробива VIN через db.vin API"""
import httpx
import logging
from typing import Optional, Dict, Any

logger = logging.getLogger(__name__)


class DbVinService:
    """Пробив машины через db.vin (vehicleHistory, stolenCheck, vinDecoder ссылки)"""

    BASE_URL = "https://db.vin/api/v1/vin"

    @staticmethod
    async def decode_vin(vin: str) -> Optional[Dict[str, Any]]:
        """
        Пробив VIN через db.vin API.

        Args:
            vin: VIN код (17 символов)

        Returns:
            dict: Информация о машине или None при ошибке
        """
        if len(vin) != 17:
            return None

        vin = vin.upper().strip()
        logger.info(f"🔍 [DbVin] Запрос пробива VIN: {vin}")

        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.get(f"{DbVinService.BASE_URL}/{vin}")

                if response.status_code == 404:
                    logger.info(f"❌ [DbVin] VIN не найден: {vin}")
                    return None

                response.raise_for_status()
                data = response.json()

                if not data or not data.get("vin"):
                    return None

                # Маппинг в формат, совместимый с CarService
                basic_info = {
                    "brand": data.get("brand"),
                    "model": data.get("model"),
                    "body_type": data.get("bodyType"),
                    "year": data.get("year") if isinstance(data.get("year"), int) else None,
                }

                fuel_info = None
                if data.get("fuelType"):
                    fuel_info = {"fuel_type": data.get("fuelType")}

                decoded_data = {
                    "vin": data.get("vin"),
                    "basic_info": basic_info,
                    "engine": None,
                    "transmission": None,
                    "fuel": fuel_info,
                    "safety": None,
                    "possible_trim_levels": [data["version"]] if data.get("version") else [],
                    "notes": None,
                    "mileage": data.get("mileage"),
                    "price": data.get("price"),
                    "currency": data.get("currency"),
                    "color": data.get("color"),
                    "vehicleHistory": data.get("vehicleHistory"),
                    "stolenCheck": data.get("stolenCheck"),
                    "vinDecoder": data.get("vinDecoder"),
                    "registrationCountry": data.get("registrationCountry"),
                }

                logger.info(f"✅ [DbVin] Пробив успешен: {vin} -> {basic_info.get('brand')} {basic_info.get('model')}")
                return decoded_data

        except httpx.HTTPError as e:
            logger.warning(f"⚠️ [DbVin] HTTP ошибка для VIN {vin}: {e}")
            return None
        except Exception as e:
            logger.warning(f"⚠️ [DbVin] Ошибка для VIN {vin}: {e}")
            return None
