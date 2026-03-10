from pydantic import BaseModel, Field, field_validator, model_validator
from typing import Optional, Dict, Any, List, Union


class VINSearchRequest(BaseModel):
    vin: str = Field(..., min_length=17, max_length=17, description="VIN код (17 символов)")


class BasicInfo(BaseModel):
    brand: Optional[str] = None
    model: Optional[str] = None
    series: Optional[str] = None
    body_type: Optional[str] = None
    generation: Optional[str] = None
    year: Optional[int] = None
    assembly_plant: Optional[str] = None
    manufacturer: Optional[str] = None
    country: Optional[str] = None


class Engine(BaseModel):
    type: Optional[str] = None
    code: Optional[str] = None
    volume_l: Optional[float] = None
    power_hp: Optional[str] = None
    cylinders: Optional[int] = None
    aspiration: Optional[str] = None
    fuel_system: Optional[str] = None
    notes: Optional[str] = None
    
    @field_validator('power_hp', mode='before')
    @classmethod
    def convert_power_hp(cls, v):
        if v is None:
            return None
        if isinstance(v, (int, float)):
            return str(v)
        return v
    
    @field_validator('volume_l', mode='before')
    @classmethod
    def convert_volume_l(cls, v):
        if v is None:
            return None
        if isinstance(v, (int, float)):
            return float(v)
        if isinstance(v, str):
            v_lower = v.lower().strip()
            if v_lower in ['неизвестно', 'unknown', 'н/д', 'n/a', 'нет данных', '']:
                return None
            try:
                return float(v)
            except (ValueError, TypeError):
                return None
        return None
    
    @field_validator('cylinders', mode='before')
    @classmethod
    def convert_cylinders(cls, v):
        if v is None:
            return None
        if isinstance(v, int):
            return v
        if isinstance(v, str):
            v_lower = v.lower().strip()
            if v_lower in ['неизвестно', 'unknown', 'н/д', 'n/a', 'нет данных', '']:
                return None
            try:
                return int(v)
            except (ValueError, TypeError):
                return None
        return None


class Transmission(BaseModel):
    type: Optional[str] = None
    gears: Optional[str] = None
    drive: Optional[str] = None
    notes: Optional[str] = None
    
    @field_validator('gears', mode='before')
    @classmethod
    def convert_gears(cls, v):
        if v is None:
            return None
        if isinstance(v, (int, float)):
            return str(v)
        return v


class Dimensions(BaseModel):
    length_mm: Optional[int] = None
    width_mm: Optional[int] = None
    height_mm: Optional[int] = None
    wheelbase_mm: Optional[int] = None
    curb_weight_kg: Optional[str] = None
    max_weight_kg: Optional[str] = None
    
    @field_validator('curb_weight_kg', 'max_weight_kg', mode='before')
    @classmethod
    def convert_weight(cls, v):
        if v is None:
            return None
        if isinstance(v, (int, float)):
            return str(v)
        return v
    
    @field_validator('length_mm', 'width_mm', 'height_mm', 'wheelbase_mm', mode='before')
    @classmethod
    def convert_dimension(cls, v):
        if v is None:
            return None
        if isinstance(v, int):
            return v
        if isinstance(v, str):
            v_lower = v.lower().strip()
            if v_lower in ['неизвестно', 'unknown', 'н/д', 'n/a', 'нет данных', '']:
                return None
            try:
                return int(v)
            except (ValueError, TypeError):
                return None
        return None


class Fuel(BaseModel):
    fuel_type: Optional[str] = None
    average_consumption_l_per_100km: Optional[str] = None
    tank_l: Optional[int] = None
    
    @field_validator('average_consumption_l_per_100km', mode='before')
    @classmethod
    def convert_consumption(cls, v):
        if v is None:
            return None
        if isinstance(v, (int, float)):
            return str(v)
        return v
    
    @field_validator('tank_l', mode='before')
    @classmethod
    def convert_tank_l(cls, v):
        if v is None:
            return None
        if isinstance(v, int):
            return v
        if isinstance(v, str):
            v_lower = v.lower().strip()
            if v_lower in ['неизвестно', 'unknown', 'н/д', 'n/a', 'нет данных', '']:
                return None
            try:
                return int(v)
            except (ValueError, TypeError):
                return None
        return None


class Safety(BaseModel):
    airbags: Optional[int] = None
    abs: Optional[bool] = None
    esp: Optional[str] = None
    traction_control: Optional[str] = None
    side_impact_protection: Optional[bool] = None
    
    @field_validator('airbags', mode='before')
    @classmethod
    def convert_airbags(cls, v):
        if v is None:
            return None
        if isinstance(v, int):
            return v
        if isinstance(v, str):
            v_lower = v.lower().strip()
            if v_lower in ['неизвестно', 'unknown', 'н/д', 'n/a', 'нет данных', '']:
                return None
            # Пытаемся извлечь число из строки
            import re
            numbers = re.findall(r'\d+', v)
            if numbers:
                return int(numbers[0])
            # Если нет чисел, но есть описание типа "Front, Side, Curtain"
            if any(word in v_lower for word in ['front', 'side', 'curtain', 'knee', 'rear']):
                count = v_lower.count(',') + 1
                return max(2, count)
            return None
        return v
    
    @field_validator('abs', 'side_impact_protection', mode='before')
    @classmethod
    def convert_bool(cls, v):
        if v is None:
            return None
        if isinstance(v, bool):
            return v
        if isinstance(v, str):
            v_lower = v.lower().strip()
            if v_lower in ['неизвестно', 'unknown', 'н/д', 'n/a', 'нет данных', '']:
                return None
            if v_lower in ['true', 'да', 'yes', '1', 'есть', 'standard']:
                return True
            if v_lower in ['false', 'нет', 'no', '0', 'нет', 'not available']:
                return False
            return None
        return None
    
    @field_validator('esp', 'traction_control', mode='before')
    @classmethod
    def convert_bool_to_string(cls, v):
        if v is None:
            return None
        if isinstance(v, bool):
            return "Standard" if v else "Not available"
        if isinstance(v, str):
            v_lower = v.lower().strip()
            if v_lower in ['неизвестно', 'unknown', 'н/д', 'n/a', 'нет данных', '']:
                return None
            if v_lower in ['true', 'да', 'yes', '1', 'есть', 'standard']:
                return "Standard"
            if v_lower in ['false', 'нет', 'no', '0', 'нет', 'not available']:
                return "Not available"
        return v


class VINSearchResponse(BaseModel):
    vin: str
    basic_info: Optional[BasicInfo] = None
    engine: Optional[Engine] = None
    transmission: Optional[Transmission] = None
    dimensions: Optional[Dimensions] = None
    fuel: Optional[Fuel] = None
    safety: Optional[Safety] = None
    possible_trim_levels: Optional[List[str]] = None
    notes: Optional[str] = None
    full_data: Optional[Dict[str, Any]] = None  # Полные данные из API
    in_database: bool = False  # Есть ли в базе
    # Ссылки из db.vin (vehicleHistory, stolenCheck, vinDecoder)
    vehicle_history_url: Optional[str] = None
    stolen_check_url: Optional[str] = None
    vin_decoder_url: Optional[str] = None


class AddCarByVINRequest(BaseModel):
    vin: str = Field(..., min_length=17, max_length=17, description="VIN код (17 символов)")


