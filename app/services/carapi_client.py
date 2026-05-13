"""
Клиент к Car API (https://carapi.app/docs): JWT, GET-запросы.
Секреты — только на бэкенде из settings.
"""
from __future__ import annotations

import asyncio
import base64
import json
import logging
import time
from typing import Any, Dict, Optional

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

_lock = asyncio.Lock()
_jwt: Optional[str] = None
_jwt_exp: float = 0.0

CARAPI_TIMEOUT = 120.0


def _jwt_exp_from_token(token: str) -> float:
    try:
        parts = token.split(".")
        if len(parts) < 2:
            return time.time() + 86400.0
        payload_b64 = parts[1]
        padded = payload_b64 + "=" * (4 - len(payload_b64) % 4)
        data = json.loads(base64.urlsafe_b64decode(padded))
        exp = float(data.get("exp") or 0)
        return exp if exp > 0 else time.time() + 86400.0
    except Exception:
        return time.time() + 86400.0


async def get_carapi_token(force_refresh: bool = False) -> Optional[str]:
    """Возвращает JWT или None, если токен/секрет не заданы (демо Car API без подписки)."""
    global _jwt, _jwt_exp
    token_part = (settings.CARAPI_API_TOKEN or "").strip()
    secret_part = (settings.CARAPI_API_SECRET or "").strip()
    if not token_part or not secret_part:
        return None

    now = time.time()
    if not force_refresh and _jwt and _jwt_exp > now + 60:
        return _jwt

    async with _lock:
        now = time.time()
        if not force_refresh and _jwt and _jwt_exp > now + 60:
            return _jwt
        base = settings.CARAPI_BASE_URL.rstrip("/")
        url = f"{base}/auth/login"
        async with httpx.AsyncClient(timeout=CARAPI_TIMEOUT) as client:
            r = await client.post(
                url,
                headers={
                    "accept": "text/plain",
                    "Content-Type": "application/json",
                },
                json={"api_token": token_part, "api_secret": secret_part},
            )
            r.raise_for_status()
            text = (r.text or "").strip().strip('"')
            _jwt = text
            _jwt_exp = _jwt_exp_from_token(text)
        logger.info("Car API JWT получен, exp≈%s", _jwt_exp)
    return _jwt


async def carapi_get(path: str, params: Optional[Dict[str, Any]] = None) -> Any:
    """
    GET относительно CARAPI_BASE_URL.
    path: например 'years/v2', 'trims/v2/123' (без префикса /api — он уже в base URL).
    """
    global _jwt, _jwt_exp
    base = settings.CARAPI_BASE_URL.rstrip("/")
    url = f"{base}/{path.lstrip('/')}"

    for attempt in range(2):
        jwt = await get_carapi_token(force_refresh=(attempt == 1))
        headers: Dict[str, str] = {"accept": "application/json"}
        if jwt:
            headers["Authorization"] = f"Bearer {jwt}"

        async with httpx.AsyncClient(timeout=CARAPI_TIMEOUT) as client:
            r = await client.get(url, params=params or {}, headers=headers)

        if r.status_code == 401 and jwt and attempt == 0:
            async with _lock:
                _jwt = None
                _jwt_exp = 0.0
            continue

        if r.status_code >= 400:
            logger.warning(
                "carapi GET %s params=%s -> %s %s",
                url,
                params,
                r.status_code,
                (r.text or "")[:800],
            )
        r.raise_for_status()
        return r.json()

    raise RuntimeError("carapi_get: unexpected state")
