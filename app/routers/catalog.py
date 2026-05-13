"""Прокси к Car API для каталога авто (год / марка / поиск комплектаций)."""
from __future__ import annotations

import json
import logging
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.auth.utils import get_current_user
from app.models.user import User
from app.services.carapi_client import carapi_get

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/years")
async def catalog_years(
    page: int = Query(1, ge=1),
    limit: int = Query(100, ge=1, le=1000),
    current_user: User = Depends(get_current_user),
):
    return await carapi_get("years/v2", {"page": page, "limit": limit})


@router.get("/makes")
async def catalog_makes(
    year: int = Query(..., description="Модельный год"),
    page: int = Query(1, ge=1),
    limit: int = Query(500, ge=1, le=1000),
    current_user: User = Depends(get_current_user),
):
    return await carapi_get("makes/v2", {"year": year, "page": page, "limit": limit})


@router.get("/models")
async def catalog_models(
    year: int = Query(...),
    make_id: int = Query(...),
    page: int = Query(1, ge=1),
    limit: int = Query(500, ge=1, le=1000),
    current_user: User = Depends(get_current_user),
):
    return await carapi_get(
        "models/v2",
        {"year": year, "make_id": make_id, "page": page, "limit": limit},
    )


@router.get("/trims")
async def catalog_trims(
    q: Optional[str] = Query(None, description="Поиск: «camry» или «toyota camry»"),
    year: Optional[int] = Query(None, description="Фильтр по году"),
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=100),
    current_user: User = Depends(get_current_user),
):
    params: Dict[str, Any] = {"page": page, "limit": limit}
    filters: List[Dict[str, Any]] = []
    if year is not None:
        filters.append({"field": "year", "op": "=", "val": year})
    if q and q.strip():
        parts = [p for p in q.strip().split() if p]
        if len(parts) >= 2:
            filters.append({"field": "make", "op": "like", "val": f"%{parts[0]}%"})
            filters.append({"field": "model", "op": "like", "val": f"%{parts[-1]}%"})
        else:
            filters.append({"field": "model", "op": "like", "val": f"%{parts[0]}%"})
    if filters:
        params["json"] = json.dumps(filters, separators=(",", ":"))
    return await carapi_get("trims/v2", params)


@router.get("/trims/{trim_id}")
async def catalog_trim_detail(
    trim_id: int,
    current_user: User = Depends(get_current_user),
):
    data: Any = await carapi_get(f"trims/v2/{trim_id}", None)
    if not isinstance(data, dict) or data.get("id") is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Комплектация не найдена")
    return data
