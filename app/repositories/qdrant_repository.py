from typing import List, Optional, Dict, Any
from uuid import UUID
import uuid
import asyncio
from functools import partial
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct, Filter, FieldCondition, MatchValue
from qdrant_client.http import models

from app.config import settings


class QdrantRepository:
    """Репозиторий для работы с Qdrant векторной базой данных"""

    COLLECTION_NAME = "manual_chunks"
    VECTOR_SIZE = 1536  # Размерность embedding для OpenAI text-embedding-3-small

    def __init__(self):
        self.client = QdrantClient(
            url=settings.QDRANT_URL,
            api_key=settings.QDRANT_API_KEY if settings.QDRANT_API_KEY else None
        )
        # Инициализация коллекции будет выполнена при первом использовании
        self._collection_initialized = False

    async def _ensure_collection(self):
        """Создание коллекции, если её нет"""
        if self._collection_initialized:
            return
            
        try:
            loop = asyncio.get_event_loop()
            collections = await loop.run_in_executor(
                None,
                self.client.get_collections
            )
            collection_names = [col.name for col in collections.collections]
            
            if self.COLLECTION_NAME not in collection_names:
                await loop.run_in_executor(
                    None,
                    partial(
                        self.client.create_collection,
                        collection_name=self.COLLECTION_NAME,
                        vectors_config=VectorParams(
                            size=self.VECTOR_SIZE,
                            distance=Distance.COSINE
                        )
                    )
                )
            self._collection_initialized = True
        except Exception:
            # Если коллекция уже существует, игнорируем ошибку
            self._collection_initialized = True


    async def add_chunk(
        self,
        embedding: List[float],
        manual_id: UUID,
        car_id: Optional[int],
        page: Optional[int],
        title: str,
        content: str
    ) -> str:
        """Добавление чанка в Qdrant"""
        await self._ensure_collection()
        
        embedding_id = str(uuid.uuid4())
        
        point = PointStruct(
            id=embedding_id,
            vector=embedding,
            payload={
                "manual_id": str(manual_id),
                "car_id": car_id,
                "page": page,
                "title": title,
                "content": content[:500]  # Первые 500 символов для предпросмотра
            }
        )
        
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(
            None,
            partial(
                self.client.upsert,
                collection_name=self.COLLECTION_NAME,
                points=[point]
            )
        )
        
        return embedding_id

    async def search_chunks(
        self,
        query_embedding: List[float],
        car_id: Optional[int] = None,
        limit: int = 5
    ) -> List[Dict[str, Any]]:
        """Поиск релевантных чанков"""
        await self._ensure_collection()
        
        # Строим фильтр
        filter_conditions = []
        if car_id is not None:
            filter_conditions.append(
                FieldCondition(key="car_id", match=MatchValue(value=car_id))
            )
        
        search_filter = Filter(must=filter_conditions) if filter_conditions else None
        
        # Выполняем поиск через executor
        # Пробуем использовать search, если доступен, иначе query_points
        loop = asyncio.get_event_loop()
        
        # Проверяем, есть ли метод search
        if hasattr(self.client, 'search'):
            # Используем метод search (старый API)
            search_results = await loop.run_in_executor(
                None,
                partial(
                    self.client.search,
                    collection_name=self.COLLECTION_NAME,
                    query_vector=query_embedding,
                    query_filter=search_filter,
                    limit=limit
                )
            )
            # Преобразуем результаты из search
            results = []
            for result in search_results:
                results.append({
                    "id": result.id,
                    "score": result.score,
                    "manual_id": result.payload.get("manual_id") if result.payload else None,
                    "car_id": result.payload.get("car_id") if result.payload else None,
                    "page": result.payload.get("page") if result.payload else None,
                    "title": result.payload.get("title") if result.payload else None,
                    "content": result.payload.get("content") if result.payload else None
                })
        else:
            # Используем query_points (новый универсальный API)
            query_response = await loop.run_in_executor(
                None,
                partial(
                    self.client.query_points,
                    collection_name=self.COLLECTION_NAME,
                    query=query_embedding,
                    query_filter=search_filter,
                    limit=limit
                )
            )
            # Преобразуем результаты из query_points
            results = []
            for point in query_response.points:
                # Проверяем структуру point - может быть ScoredPoint или просто Point
                point_id = point.id if hasattr(point, 'id') else str(point)
                point_score = getattr(point, 'score', None)
                point_payload = getattr(point, 'payload', {}) if hasattr(point, 'payload') else {}
                
                results.append({
                    "id": point_id,
                    "score": point_score,
                    "manual_id": point_payload.get("manual_id") if point_payload else None,
                    "car_id": point_payload.get("car_id") if point_payload else None,
                    "page": point_payload.get("page") if point_payload else None,
                    "title": point_payload.get("title") if point_payload else None,
                    "content": point_payload.get("content") if point_payload else None
                })
        
        import logging
        logger = logging.getLogger(__name__)
        logger.info(f"🔍 Qdrant поиск вернул {len(results)} результатов")
        if results:
            logger.info(f"   Первый результат: id={results[0]['id']}, score={results[0]['score']}, title={results[0]['title']}")
        
        return results

    async def delete_by_manual_id(self, manual_id: UUID) -> int:
        """Удаление всех чанков мануала из Qdrant"""
        await self._ensure_collection()
        
        loop = asyncio.get_event_loop()
        manual_id_str = str(manual_id)
        point_ids = []
        offset = None
        
        # Получаем все точки порциями и фильтруем по manual_id в Python
        # (так как Qdrant требует индекс для фильтрации)
        while True:
            scroll_result = await loop.run_in_executor(
                None,
                partial(
                    self.client.scroll,
                    collection_name=self.COLLECTION_NAME,
                    limit=100,  # Получаем по 100 точек за раз
                    offset=offset,
                    with_payload=True
                )
            )
            
            points, next_offset = scroll_result
            
            if not points:
                break
            
            # Фильтруем точки по manual_id в payload
            for point in points:
                payload = getattr(point, 'payload', {}) if hasattr(point, 'payload') else {}
                if payload and payload.get('manual_id') == manual_id_str:
                    point_ids.append(point.id)
            
            if next_offset is None:
                break
            
            offset = next_offset
        
        # Удаляем найденные точки
        if point_ids:
            await loop.run_in_executor(
                None,
                partial(
                    self.client.delete,
                    collection_name=self.COLLECTION_NAME,
                    points_selector=models.PointIdsList(
                        points=point_ids
                    )
                )
            )
        
        return len(point_ids)
