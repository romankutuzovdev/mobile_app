import httpx
from typing import Optional, Dict, Any
import logging

logger = logging.getLogger(__name__)

# Настройка логирования для вывода в консоль
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
console_handler.setFormatter(formatter)
logger.addHandler(console_handler)
logger.setLevel(logging.INFO)


class NHTSAVINService:
    """Сервис для декодирования VIN через NHTSA API (бесплатный правительственный API США)"""

    BASE_URL = "https://vpic.nhtsa.dot.gov/api/vehicles/decodevinvaluesextended"

    @staticmethod
    async def decode_vin(vin: str) -> Optional[Dict[str, Any]]:
        """
        Декодирование VIN через NHTSA API
        
        Args:
            vin: VIN код (17 символов)
            
        Returns:
            dict: Информация о машине в структурированном формате или None при ошибке
        """
        if len(vin) != 17:
            return None

        logger.info(f"🔍 [NHTSA] Запрос к NHTSA API для VIN: {vin}")
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.get(
                    f"{NHTSAVINService.BASE_URL}/{vin}",
                    params={"format": "json"}
                )
                response.raise_for_status()
                data = response.json()
                
                if data.get("Results") and len(data["Results"]) > 0:
                    result = data["Results"][0]
                    
                    # Проверяем на ошибки
                    if result.get("ErrorCode") != "0" and result.get("ErrorCode") != "1":
                        error_text = result.get("ErrorText", "Unknown error")
                        logger.warning(f"⚠️  [NHTSA] Ошибка для VIN {vin}: {error_text}")
                        logger.info(f"❌ [NHTSA] Сервис не дал результатов для VIN {vin}")
                        return None
                    
                    # Формируем структурированный ответ в формате как ChatGPT
                    basic_info = {
                        "brand": result.get("Make") or None,
                        "model": result.get("Model") or None,
                        "series": result.get("Series") or None,
                        "body_type": result.get("BodyClass") or None,
                        "generation": None,  # NHTSA не предоставляет
                        "year": None,
                        "assembly_plant": result.get("PlantCity") or None,
                        "manufacturer": result.get("ManufacturerName") or None,
                        "country": result.get("PlantCountry") or None
                    }
                    
                    # Парсим год
                    year_str = result.get("ModelYear")
                    if year_str and year_str.isdigit():
                        basic_info["year"] = int(year_str)
                    
                    # Информация о двигателе
                    engine_info = {
                        "type": result.get("FuelTypePrimary") or None,
                        "code": result.get("EngineModel") or None,
                        "volume_l": None,
                        "power_hp": result.get("EngineHP") or None,
                        "cylinders": None,
                        "aspiration": result.get("EngineConfiguration") or None,
                        "fuel_system": result.get("FuelTypePrimary") or None,
                        "notes": result.get("EngineCylinders") or None
                    }
                    
                    # Парсим объем двигателя
                    displacement_str = result.get("DisplacementL")
                    if displacement_str:
                        try:
                            engine_info["volume_l"] = float(displacement_str)
                        except:
                            pass
                    
                    # Парсим количество цилиндров
                    cylinders_str = result.get("EngineCylinders")
                    if cylinders_str and cylinders_str.isdigit():
                        engine_info["cylinders"] = int(cylinders_str)
                    
                    # Трансмиссия
                    transmission_info = {
                        "type": result.get("TransmissionStyle") or None,
                        "gears": result.get("TransmissionSpeeds") or None,
                        "drive": result.get("DriveType") or None,
                        "notes": None
                    }
                    
                    # Габариты
                    dimensions_info = {
                        "length_mm": None,
                        "width_mm": None,
                        "height_mm": None,
                        "wheelbase_mm": None,
                        "curb_weight_kg": result.get("GVWR") or None,
                        "max_weight_kg": result.get("GVWR") or None
                    }
                    
                    # Парсим колесную базу
                    wheelbase_str = result.get("WheelBase")
                    if wheelbase_str:
                        try:
                            # NHTSA возвращает в дюймах, конвертируем в мм
                            wheelbase_inches = float(wheelbase_str)
                            dimensions_info["wheelbase_mm"] = int(wheelbase_inches * 25.4)
                        except:
                            pass
                    
                    # Топливо
                    fuel_info = {
                        "fuel_type": result.get("FuelTypePrimary") or None,
                        "average_consumption_l_per_100km": None,
                        "tank_l": None
                    }
                    
                    # Безопасность
                    safety_info = {
                        "airbags": None,
                        "abs": result.get("ABS") == "Standard" if result.get("ABS") else None,
                        "esp": result.get("ElectronicStabilityControl") == "Standard" if result.get("ElectronicStabilityControl") else None,
                        "traction_control": result.get("TractionControl") == "Standard" if result.get("TractionControl") else None,
                        "side_impact_protection": None
                    }
                    
                    # Формируем полный ответ
                    car_info = {
                        "vin": vin,
                        "basic_info": basic_info,
                        "engine": engine_info,
                        "transmission": transmission_info,
                        "dimensions": dimensions_info,
                        "fuel": fuel_info,
                        "safety": safety_info,
                        "possible_trim_levels": [],
                        "notes": f"Данные получены из NHTSA API. VIN проверен: {result.get('VIN', vin)}",
                        "api_data": result  # Полные данные от NHTSA
                    }
                    
                    brand = basic_info.get("brand")
                    model = basic_info.get("model")
                    logger.info(f"✅ [NHTSA] Успешно декодирован VIN {vin}: {brand} {model}")
                    return car_info
                
                logger.warning(f"⚠️  [NHTSA] Пустой ответ от API для VIN {vin}")
                logger.info(f"❌ [NHTSA] Сервис не дал результатов для VIN {vin}")
                return None
                
        except httpx.HTTPError as e:
            logger.error(f"❌ [NHTSA] HTTP ошибка для VIN {vin}: {str(e)}")
            logger.info(f"❌ [NHTSA] Сервис не дал результатов для VIN {vin}")
            return None
        except Exception as e:
            logger.error(f"❌ [NHTSA] Ошибка декодирования VIN {vin}: {str(e)}")
            logger.info(f"❌ [NHTSA] Сервис не дал результатов для VIN {vin}")
            return None

