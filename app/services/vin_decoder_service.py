import httpx
from typing import Optional, Dict, Any
import logging

logger = logging.getLogger(__name__)


class VINDecoderService:
    """Сервис для декодирования VIN через внешние API"""

    # Пример API для декодирования VIN (можно использовать разные сервисы)
    # Используем бесплатный API: https://vpic.nhtsa.dot.gov/api/
    BASE_URL = "https://vpic.nhtsa.dot.gov/api/vehicles/decodevinvalues"

    @staticmethod
    async def decode_vin(vin: str) -> Optional[Dict[str, Any]]:
        """
        Декодирование VIN через NHTSA API
        
        Args:
            vin: VIN код (17 символов)
            
        Returns:
            dict: Информация о машине или None при ошибке
        """
        if len(vin) != 17:
            return None

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(
                    f"{VINDecoderService.BASE_URL}/{vin}",
                    params={"format": "json"}
                )
                response.raise_for_status()
                data = response.json()
                
                if data.get("Results") and len(data["Results"]) > 0:
                    result = data["Results"][0]
                    
                    # Извлекаем основную информацию
                    car_info = {
                        "vin": vin,
                        "brand": result.get("Make") or None,
                        "model": result.get("Model") or None,
                        "year": None,
                        "api_data": result  # Сохраняем полные данные из API
                    }
                    
                    # Парсим год
                    year_str = result.get("ModelYear")
                    if year_str and year_str.isdigit():
                        car_info["year"] = int(year_str)
                    
                    return car_info
                
                return None
                
        except httpx.HTTPError as e:
            logger.error(f"HTTP error decoding VIN {vin}: {str(e)}")
            return None
        except Exception as e:
            logger.error(f"Error decoding VIN {vin}: {str(e)}")
            return None

