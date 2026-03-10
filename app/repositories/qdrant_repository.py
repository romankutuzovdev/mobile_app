"""
Репозиторий для работы с Qdrant через qdrant-client.
"""
from typing import List, Optional, Dict, Any
from uuid import UUID
import uuid
import logging
import sys

from qdrant_client import AsyncQdrantClient
from qdrant_client.models import (
    PointStruct,
    VectorParams,
    Distance,
    Filter,
    FieldCondition,
    MatchValue,
    MatchAny,
    FilterSelector,
)

from app.config import settings

logger = logging.getLogger(__name__)


class QdrantRepository:
    """Репозиторий для работы с Qdrant векторной базой через qdrant-client"""

    COLLECTION_NAME = "manual_chunks"
    VECTOR_SIZE = 1536

    def __init__(self):
        client_kwargs: dict = {"url": settings.QDRANT_URL}
        if settings.QDRANT_API_KEY:
            client_kwargs["api_key"] = settings.QDRANT_API_KEY
        self._client = AsyncQdrantClient(**client_kwargs)
        self._collection_initialized = False

    async def _ensure_collection(self):
        if self._collection_initialized:
            return
        try:
            if not await self._client.collection_exists(self.COLLECTION_NAME):
                sys.stderr.write(f"[DEBUG] Qdrant: коллекция '{self.COLLECTION_NAME}' не найдена, создаю...\n")
                sys.stderr.flush()
                await self._client.create_collection(
                    collection_name=self.COLLECTION_NAME,
                    vectors_config=VectorParams(
                        size=self.VECTOR_SIZE,
                        distance=Distance.COSINE,
                    ),
                )
                sys.stderr.write("[DEBUG] Qdrant: коллекция создана\n")
                sys.stderr.flush()
            else:
                sys.stderr.write(f"[DEBUG] Qdrant: коллекция '{self.COLLECTION_NAME}' существует\n")
                sys.stderr.flush()
        except Exception as e:
            sys.stderr.write(f"[DEBUG] Qdrant _ensure_collection: {e}\n")
            sys.stderr.flush()
        self._collection_initialized = True

    async def add_chunk(
        self,
        embedding: List[float],
        manual_id: UUID,
        brand: str,
        model: str,
        year: int,
        page: Optional[int] = None,
        title: str = "",
        content: str = "",
        car_id: Optional[int] = None,
    ) -> str:
        await self._ensure_collection()
        embedding_id = str(uuid.uuid4())
        payload: Dict[str, Any] = {
            "manual_id": str(manual_id),
            "brand": brand.strip().lower(),
            "model": model.strip().lower(),
            "year": year,
            "page": page,
            "title": title,
            "content": content[:500],
        }
        if car_id is not None:
            payload["car_id"] = car_id

        point = PointStruct(
            id=embedding_id,
            vector=embedding,
            payload=payload,
        )
        await self._client.upsert(
            collection_name=self.COLLECTION_NAME,
            points=[point],
        )
        logger.debug("Qdrant upsert: id=%s manual_id=%s brand=%s model=%s", embedding_id, manual_id, brand, model)
        return embedding_id

    def _build_filter(
        self,
        car_id: Optional[int] = None,
        brand: Optional[str] = None,
        model: Optional[str] = None,
        year: Optional[int] = None,
        manual_ids: Optional[List[str]] = None,
    ) -> Optional[Filter]:
        conditions = []
        if car_id is not None:
            conditions.append(
                FieldCondition(key="car_id", match=MatchValue(value=car_id))
            )
        elif manual_ids:
            conditions.append(
                FieldCondition(key="manual_id", match=MatchAny(any=manual_ids))
            )
        elif brand is not None and year is not None:
            conditions.append(
                FieldCondition(key="brand", match=MatchValue(value=brand.strip().lower()))
            )
            conditions.append(
                FieldCondition(key="year", match=MatchValue(value=year))
            )
        if not conditions:
            return None
        return Filter(must=conditions)

    async def search_chunks(
        self,
        query_embedding: List[float],
        car_id: Optional[int] = None,
        brand: Optional[str] = None,
        model: Optional[str] = None,
        year: Optional[int] = None,
        manual_ids: Optional[List[str]] = None,
        limit: int = 5,
    ) -> List[Dict[str, Any]]:
        await self._ensure_collection()
        search_kwargs = {
            "collection_name": self.COLLECTION_NAME,
            "query": query_embedding,
            "limit": limit,
            "with_payload": True,
        }
        filt = self._build_filter(
            car_id=car_id, brand=brand, model=model, year=year, manual_ids=manual_ids
        )
        if filt:
            search_kwargs["query_filter"] = filt

        response = await self._client.query_points(**search_kwargs)
        hits = response.points if hasattr(response, "points") else []

        results = []
        for hit in hits:
            payload = hit.payload or {}
            results.append({
                "id": str(hit.id) if hit.id else None,
                "score": hit.score,
                "manual_id": payload.get("manual_id"),
                "car_id": payload.get("car_id"),
                "page": payload.get("page"),
                "title": payload.get("title"),
                "content": payload.get("content"),
            })

        logger.info("Qdrant поиск вернул %d результатов", len(results))
        if results:
            logger.info(
                "   Первый: id=%s score=%s title=%s",
                results[0]["id"],
                results[0]["score"],
                results[0]["title"],
            )
        return results

    async def delete_by_manual_id(self, manual_id: UUID) -> int:
        await self._ensure_collection()
        manual_id_str = str(manual_id)
        await self._client.delete(
            collection_name=self.COLLECTION_NAME,
            points_selector=FilterSelector(
                filter=Filter(
                    must=[
                        FieldCondition(
                            key="manual_id",
                            match=MatchValue(value=manual_id_str),
                        )
                    ]
                )
            ),
        )
        return 1  # qdrant-client delete не возвращает количество удалённых
