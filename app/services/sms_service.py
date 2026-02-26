import httpx
from typing import Optional
import random
import string

from app.config import settings


class SMSCService:
    """Сервис для отправки SMS через SMSC.ru"""

    BASE_URL = "https://smsc.ru/sys/send.php"
    LOGIN = "Marconi123"
    PASSWORD = "ForArtur1337!"

    @staticmethod
    def generate_verification_code(length: int = 6) -> str:
        """Генерация кода подтверждения"""
        return ''.join(random.choices(string.digits, k=length))

    @staticmethod
    async def send_sms(phone: str, message: str) -> dict:
        """
        Отправка SMS через SMSC.ru API
        
        Args:
            phone: Номер телефона в формате 375298004975
            message: Текст сообщения
            
        Returns:
            dict: Результат отправки
        """
        params = {
            "login": SMSCService.LOGIN,
            "psw": SMSCService.PASSWORD,
            "phones": phone,
            "mes": message,
            "fmt": 3  # JSON формат ответа
        }

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(SMSCService.BASE_URL, params=params)
                response.raise_for_status()
                result = response.json()
                
                # Проверка ошибок в ответе
                if isinstance(result, dict) and result.get("error"):
                    error_code = result.get("error_code", "unknown")
                    error_msg = result.get("error", "Unknown error")
                    raise Exception(f"SMSC error {error_code}: {error_msg}")
                
                return {
                    "success": True,
                    "result": result
                }
        except httpx.HTTPError as e:
            return {
                "success": False,
                "error": f"HTTP error: {str(e)}"
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }

    @staticmethod
    async def send_verification_code(phone: str) -> tuple[Optional[str], Optional[str]]:
        """
        Отправка кода подтверждения на телефон
        
        Returns:
            tuple: (verification_code, error_message)
        """
        code = SMSCService.generate_verification_code()
        message = f"Ваш код подтверждения: {code}"
        
        result = await SMSCService.send_sms(phone, message)
        
        if result.get("success"):
            return code, None
        else:
            return None, result.get("error", "Ошибка отправки SMS")

