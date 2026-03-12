from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Optional, Dict, Any
import logging

from app.repositories.car_repository import CarRepository
from app.repositories.car_info_repository import CarInfoRepository
from app.services.nhtsa_vin_service import NHTSAVINService
from app.services.db_vin_service import DbVinService
from app.schemas.car import CarCreate, CarUpdate, CarOut
from app.core.exceptions import UserNotFoundException
from app.models.user import User
from app.config import settings

logger = logging.getLogger(__name__)

# Настройка логирования для вывода в консоль
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
console_handler.setFormatter(formatter)
logger.addHandler(console_handler)
logger.setLevel(logging.INFO)


class CarService:
    """Сервис для работы с автомобилями"""

    @staticmethod
    async def create_car(
        db: AsyncSession,
        user_id: int,
        car_data: CarCreate
    ) -> CarOut:
        """Создание автомобиля с валидациями и поиском по VIN"""
        # Проверка, что у пользователя нет автомобиля с таким VIN
        if car_data.vin:
            user_cars = await CarRepository.get_user_cars(db, user_id)
            for car in user_cars:
                if car.vin == car_data.vin:
                    raise ValueError("У вас уже есть автомобиль с таким VIN кодом")

        # Если указан VIN, ищем или создаем запись в общей базе
        car_info_id = None
        if car_data.vin:
            # Проверяем, есть ли машина в общей базе
            car_info = await CarInfoRepository.get_by_vin(db, car_data.vin)
            
            if not car_info:
                logger.info(f"🔍 [CarService] Создание машины с VIN: {car_data.vin}")
                # Пробуем db.vin первым (история, проверка угона)
                decoded_data = await DbVinService.decode_vin(car_data.vin)
                if not decoded_data:
                    decoded_data = await NHTSAVINService.decode_vin(car_data.vin)
                if decoded_data:
                    logger.info(f"✅ [CarService] Получены данные для VIN: {car_data.vin}")
                else:
                    logger.warning(f"❌ [CarService] Все сервисы не дали результатов для VIN: {car_data.vin}")
                
                if decoded_data:
                    # Извлекаем основные данные из basic_info
                    basic_info = decoded_data.get("basic_info", {}) if isinstance(decoded_data, dict) else {}
                    brand = basic_info.get("brand") if isinstance(basic_info, dict) else decoded_data.get("brand") or car_data.brand
                    model = basic_info.get("model") if isinstance(basic_info, dict) else decoded_data.get("model") or car_data.model
                    year = basic_info.get("year") if isinstance(basic_info, dict) else decoded_data.get("year") or car_data.year
                    
                    # Создаем запись в общей базе с данными из API
                    car_info = await CarInfoRepository.create(
                        db=db,
                        vin=car_data.vin,
                        brand=brand,
                        model=model,
                        year=year,
                        api_data=decoded_data  # Полная структурированная информация
                    )
                else:
                    # Если API не вернул данные, создаем с данными пользователя
                    car_info = await CarInfoRepository.create(
                        db=db,
                        vin=car_data.vin,
                        brand=car_data.brand,
                        model=car_data.model,
                        year=car_data.year
                    )
            
            car_info_id = car_info.id
            
            # Используем данные из общей базы, если они есть
            brand = car_info.brand if car_info.brand else car_data.brand
            model = car_info.model if car_info.model else car_data.model
            year = car_info.year if car_info.year else car_data.year
            
            # Создаем обновленный объект CarCreate
            from app.schemas.car import CarCreate
            car_data = CarCreate(
                vin=car_data.vin,
                brand=brand,
                model=model,
                year=year
            )

        # Создание автомобиля пользователя
        car = await CarRepository.create_car(db, user_id, car_data, car_info_id)
        return CarOut.model_validate(car)

    @staticmethod
    async def update_car(
        db: AsyncSession,
        car_id: int,
        user_id: int,
        car_data: CarUpdate
    ) -> CarOut:
        """Обновление автомобиля с проверкой прав доступа"""
        car = await CarRepository.get_car_by_id(db, car_id)
        if not car:
            raise ValueError("Автомобиль не найден")

        # Проверка, что автомобиль принадлежит пользователю
        if car.user_id != user_id:
            raise ValueError("У вас нет прав на изменение этого автомобиля")

        # Проверка, что у пользователя нет другого автомобиля с таким VIN при обновлении
        if car_data.vin and car_data.vin != car.vin:
            user_cars = await CarRepository.get_user_cars(db, user_id)
            for user_car in user_cars:
                if user_car.vin == car_data.vin and user_car.id != car_id:
                    raise ValueError("У вас уже есть другой автомобиль с таким VIN кодом")

        updated_car = await CarRepository.update_car(db, car_id, car_data)
        if not updated_car:
            raise ValueError("Ошибка при обновлении автомобиля")

        return CarOut.model_validate(updated_car)

    @staticmethod
    async def delete_car(
        db: AsyncSession,
        car_id: int,
        user_id: int
    ) -> bool:
        """Удаление автомобиля с проверкой прав доступа"""
        car = await CarRepository.get_car_by_id(db, car_id)
        if not car:
            raise ValueError("Автомобиль не найден")

        # Проверка, что автомобиль принадлежит пользователю
        if car.user_id != user_id:
            raise ValueError("У вас нет прав на удаление этого автомобиля")

        return await CarRepository.delete_car(db, car_id)

    @staticmethod
    async def get_car(
        db: AsyncSession,
        car_id: int,
        user_id: int
    ) -> CarOut:
        """Получить автомобиль по ID с проверкой прав доступа"""
        from app.repositories.manual_repository import ManualRepository

        car = await CarRepository.get_car_by_id(db, car_id)
        if not car:
            raise ValueError("Автомобиль не найден")

        if car.user_id != user_id:
            raise ValueError("У вас нет доступа к этому автомобилю")

        manuals = await ManualRepository.get_manuals_by_brand_model_year(
            db, car.brand, car.model, car.year
        )
        car_out = CarOut.model_validate(car)
        car_out.has_manuals = len(manuals) > 0
        return car_out

    @staticmethod
    async def list_user_cars(
        db: AsyncSession,
        user_id: int
    ) -> List[CarOut]:
        """Получение списка автомобилей пользователя с флагом has_manuals"""
        from app.repositories.manual_repository import ManualRepository

        cars = await CarRepository.get_user_cars(db, user_id)
        result = []
        for car in cars:
            manuals = await ManualRepository.get_manuals_by_brand_model_year(
                db, car.brand, car.model, car.year
            )
            car_out = CarOut.model_validate(car)
            car_out.has_manuals = len(manuals) > 0
            result.append(car_out)
        return result

    @staticmethod
    async def search_by_vin(
        db: AsyncSession,
        vin: str
    ) -> Dict[str, Any]:
        """Поиск информации о машине по VIN коду"""
        # Проверяем в базе
        car_info = await CarInfoRepository.get_by_vin(db, vin)
        
        if car_info and car_info.api_data:
            api_data = car_info.api_data
            return {
                "vin": car_info.vin,
                "basic_info": api_data.get("basic_info"),
                "engine": api_data.get("engine"),
                "transmission": api_data.get("transmission"),
                "dimensions": api_data.get("dimensions"),
                "fuel": api_data.get("fuel"),
                "safety": api_data.get("safety"),
                "possible_trim_levels": api_data.get("possible_trim_levels", []),
                "notes": api_data.get("notes"),
                "full_data": api_data,
                "in_database": True,
                "vehicle_history_url": api_data.get("vehicleHistory"),
                "stolen_check_url": api_data.get("stolenCheck"),
                "vin_decoder_url": api_data.get("vinDecoder"),
            }
        
        logger.info(f"🔍 [CarService] Поиск информации по VIN: {vin}")
        decoded_data = await DbVinService.decode_vin(vin)
        if not decoded_data:
            decoded_data = await NHTSAVINService.decode_vin(vin)

        if decoded_data:
            logger.info(f"✅ [CarService] Получены данные для VIN: {vin}")
            return {
                "vin": vin,
                "basic_info": decoded_data.get("basic_info"),
                "engine": decoded_data.get("engine"),
                "transmission": decoded_data.get("transmission"),
                "dimensions": decoded_data.get("dimensions"),
                "fuel": decoded_data.get("fuel"),
                "safety": decoded_data.get("safety"),
                "possible_trim_levels": decoded_data.get("possible_trim_levels", []),
                "notes": decoded_data.get("notes"),
                "full_data": decoded_data,
                "in_database": False,
                "vehicle_history_url": decoded_data.get("vehicleHistory"),
                "stolen_check_url": decoded_data.get("stolenCheck"),
                "vin_decoder_url": decoded_data.get("vinDecoder"),
            }
        
        # Более информативное сообщение об ошибке
        error_msg = "Не удалось получить информацию о машине по VIN. DbVin и NHTSA API не вернули данные."
        
        raise ValueError(error_msg)

    @staticmethod
    async def add_car_by_vin(
        db: AsyncSession,
        user_id: int,
        vin: str
    ) -> CarOut:
        """Добавление машины пользователю по VIN с автоматическим поиском информации"""
        # Проверка, что у пользователя нет автомобиля с таким VIN
        user_cars = await CarRepository.get_user_cars(db, user_id)
        for car in user_cars:
            if car.vin == vin:
                raise ValueError("У вас уже есть автомобиль с таким VIN кодом")

        # Ищем или получаем информацию о машине
        car_info = await CarInfoRepository.get_by_vin(db, vin)
        
        if not car_info:
            logger.info(f"🔍 [CarService] Добавление машины по VIN: {vin}")
            decoded_data = await DbVinService.decode_vin(vin)
            if not decoded_data:
                decoded_data = await NHTSAVINService.decode_vin(vin)
            if decoded_data:
                logger.info(f"✅ [CarService] Получены данные для VIN: {vin}")
            
            if not decoded_data:
                raise ValueError("Не удалось получить информацию о машине по VIN")
            
            # Извлекаем основные данные для быстрого доступа
            basic_info = decoded_data.get("basic_info", {}) if isinstance(decoded_data, dict) else {}
            
            # Создаем запись в общей базе
            car_info = await CarInfoRepository.create(
                db=db,
                vin=vin,
                brand=basic_info.get("brand") if isinstance(basic_info, dict) else decoded_data.get("brand"),
                model=basic_info.get("model") if isinstance(basic_info, dict) else decoded_data.get("model"),
                year=basic_info.get("year") if isinstance(basic_info, dict) else decoded_data.get("year"),
                api_data=decoded_data
            )
        
        # Извлекаем данные из api_data если есть, иначе используем базовые поля
        if car_info.api_data and isinstance(car_info.api_data, dict):
            basic_info = car_info.api_data.get("basic_info", {})
            brand = basic_info.get("brand") if isinstance(basic_info, dict) else car_info.brand
            model = basic_info.get("model") if isinstance(basic_info, dict) else car_info.model
            year = basic_info.get("year") if isinstance(basic_info, dict) else car_info.year
        else:
            brand = car_info.brand
            model = car_info.model
            year = car_info.year
        
        # Создаем CarCreate с данными из базы
        car_data = CarCreate(
            vin=vin,
            brand=brand or "Unknown",
            model=model or "Unknown",
            year=year or 2000
        )
        
        # Создаем автомобиль пользователя
        car = await CarRepository.create_car(db, user_id, car_data, car_info.id)
        return CarOut.model_validate(car)

