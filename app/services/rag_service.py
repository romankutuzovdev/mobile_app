from typing import Optional, List, Dict, Any
from uuid import UUID
from sqlalchemy.ext.asyncio import AsyncSession
from app.repositories.qdrant_repository import QdrantRepository
from app.repositories.manual_repository import ManualRepository
from app.services.embedding_service import EmbeddingService
from app.config import settings
import logging

logger = logging.getLogger(__name__)


class RAGService:
    """Сервис для RAG (Retrieval-Augmented Generation)"""

    SYSTEM_PROMPT = """Ты отвечаешь на вопросы ТОЛЬКО на основе предоставленного контекста из мануала автомобиля.

ЗАПРЕЩЕНО:
- Добавлять общие знания «из головы» (например: «в автомобилях обычно педали располагаются...», «педаль газа отвечает за скорость»).
- Дополнять ответ информацией, которой нет в контексте.
- Писать общие фразы об устройстве автомобиля, если их нет в контексте.

РАЗРЕШЕНО:
- Использовать только фразы, предложения и факты, которые есть в контексте. Перефразировать и кратко обобщать их можно.
- Если в контексте есть упоминания педалей, органов управления, схем — использовать только эту информацию.
- Отвечать на русском; если контекст на другом языке — перевести цитируемую информацию на русский.

Если в контексте есть подходящая информация (даже частично) — ответь, опираясь только на неё; можно кратко процитировать или пересказать.
Если в контексте действительно нет ничего по теме вопроса — напиши только: «В предоставленном мануале нет информации для ответа на этот вопрос.» Не добавляй общих сведений из головы."""

    @staticmethod
    def _safe_preview(text: str, max_len: int = 2500) -> str:
        """Превью текста, безопасное для JSON (только валидный UTF-8)."""
        if not text:
            return ""
        s = (text[:max_len] + ("..." if len(text) > max_len else ""))
        return s.encode("utf-8", errors="replace").decode("utf-8")

    @staticmethod
    async def ask_question(
        question: str,
        car_id: Optional[int] = None,
        manual_id: Optional[UUID] = None,
        brand: Optional[str] = None,
        model: Optional[str] = None,
        year: Optional[int] = None,
        db: Optional[AsyncSession] = None
    ) -> Dict[str, Any]:
        """Поиск ответа на вопрос с использованием RAG"""
        try:
            return await RAGService._ask_question_impl(
                question, car_id, manual_id, brand, model, year, db
            )
        except Exception as e:
            logger.exception(f"Ошибка RAG: {e}")
            return {
                "answer": f"Ошибка при поиске ответа: {str(e)}",
                "sources": [],
                "context_preview": None
            }

    @staticmethod
    async def _ask_question_impl(
        question: str,
        car_id: Optional[int],
        manual_id: Optional[UUID],
        brand: Optional[str],
        model: Optional[str],
        year: Optional[int],
        db: Optional[AsyncSession]
    ) -> Dict[str, Any]:
        logger.info(f"🔍 Начинаю поиск ответа на вопрос: {question[:50]}...")
        if manual_id:
            logger.info(f"   Фильтр по мануалу: {manual_id}")
        
        # car_id → brand/model/year для поиска в глобальном каталоге
        qdrant_car_id = car_id
        qdrant_manual_ids = None
        qdrant_brand, qdrant_model, qdrant_year = brand, model, year
        
        if db and car_id and not manual_id:
            from app.models.car import Car
            from sqlalchemy import select
            result = await db.execute(select(Car).where(Car.id == car_id))
            car = result.scalar_one_or_none()
            if car:
                manuals = await ManualRepository.get_manuals_by_brand_model_year(
                    db, car.brand, car.model, car.year
                )
                if manuals:
                    qdrant_car_id = None
                    qdrant_manual_ids = [str(m.id) for m in manuals]
                    qdrant_brand, qdrant_model, qdrant_year = car.brand, car.model, car.year
                else:
                    qdrant_brand, qdrant_model, qdrant_year = car.brand, car.model, car.year
                    qdrant_car_id = None
            else:
                qdrant_car_id = car_id
        elif brand and model and year and not manual_id and db:
            manuals = await ManualRepository.get_manuals_by_brand_model_year(
                db, brand, model, year
            )
            if manuals:
                qdrant_manual_ids = [str(m.id) for m in manuals]
                qdrant_brand, qdrant_model, qdrant_year = brand, model, year
        
        embedding_service = EmbeddingService()
        question_embedding = await embedding_service.get_embedding(question)
        logger.info(f"✅ Получен embedding для вопроса (размерность: {len(question_embedding)})")

        qdrant_repo = QdrantRepository()
        search_limit = 400 if manual_id else 25
        relevant_chunks = await qdrant_repo.search_chunks(
            query_embedding=question_embedding,
            car_id=qdrant_car_id,
            manual_ids=qdrant_manual_ids,
            brand=qdrant_brand,
            model=qdrant_model,
            year=qdrant_year,
            limit=search_limit
        )
        
        logger.info(f"📊 Найдено чанков в Qdrant: {len(relevant_chunks)}")
        if relevant_chunks:
            logger.info(f"   Первый чанк: score={relevant_chunks[0].get('score', 'N/A')}, title={relevant_chunks[0].get('title', 'N/A')}")

        # Фильтр по manual_id (в Python, т.к. в Qdrant нет индекса по manual_id)
        if manual_id and relevant_chunks:
            manual_id_str = str(manual_id) if not isinstance(manual_id, str) else manual_id
            relevant_chunks = [c for c in relevant_chunks if c.get("manual_id") == manual_id_str]
            logger.info(f"   После фильтра по manual_id: {len(relevant_chunks)} чанков")
            if not relevant_chunks:
                return {
                    "answer": f"В указанном мануале не найдено релевантных фрагментов для ответа на вопрос. Попробуйте другой мануал или переформулируйте вопрос.",
                    "sources": [],
                    "context_preview": None
                }
            # Оставляем не более 25 чанков для контекста
            relevant_chunks = relevant_chunks[:25]

        # Фильтруем только совсем нерелевантные (низкий порог: OCR/разный формулировки дают score 0.2+)
        MIN_SCORE = 0.15
        chunks_before_score_filter: List[Dict[str, Any]] = list(relevant_chunks) if relevant_chunks else []
        if relevant_chunks:
            filtered_chunks = [
                chunk for chunk in relevant_chunks 
                if chunk.get('score') is not None and chunk.get('score', 0) >= MIN_SCORE
            ]
            if filtered_chunks:
                relevant_chunks = filtered_chunks
                logger.info(f"✅ После фильтрации по score >= {MIN_SCORE}: {len(relevant_chunks)} чанков")
            else:
                logger.warning(f"⚠️  Все чанки имеют score < {MIN_SCORE}, используем все найденные")
        # Если чанков мало (1–2) — берём топ-12 по score из всех найденных, чтобы дать модели больший контекст
        if relevant_chunks and len(relevant_chunks) <= 2 and chunks_before_score_filter:
            sorted_by_score = sorted(
                chunks_before_score_filter,
                key=lambda c: c.get('score') or 0,
                reverse=True
            )
            relevant_chunks = sorted_by_score[:12]
            logger.info(f"📎 Чанков было мало ({len(relevant_chunks)}), добавлены до топ-12 по score: {len(relevant_chunks)} чанков")

        if not relevant_chunks:
            logger.warning("⚠️  Не найдено релевантных чанков в Qdrant")
            if qdrant_car_id or qdrant_manual_ids or qdrant_brand:
                logger.info("🔄 Пробую поиск без фильтра...")
                relevant_chunks = await qdrant_repo.search_chunks(
                    query_embedding=question_embedding,
                    limit=25
                )
                logger.info(f"📊 Найдено чанков без фильтра: {len(relevant_chunks)}")
                
                # Фильтруем снова
                if relevant_chunks:
                    filtered_chunks = [
                        chunk for chunk in relevant_chunks 
                        if chunk.get('score') is not None and chunk.get('score', 0) >= MIN_SCORE
                    ]
                    if filtered_chunks:
                        relevant_chunks = filtered_chunks
            
            if not relevant_chunks:
                return {
                    "answer": "В базе мануалов не найдено информации для ответа на ваш вопрос. Убедитесь, что мануал был загружен и обработан.",
                    "sources": [],
                    "context_preview": None
                }

        # Получаем полный контент чанков из БД (в Qdrant хранится только превью)
        context_parts = []
        sources = []
        found_chunks_count = 0
        
        if db:
            from sqlalchemy import select
            from app.models.manual import ManualChunk
            
            for chunk_info in relevant_chunks:
                embedding_id = str(chunk_info["id"])  # Qdrant возвращает строку
                # Получаем полный контент из БД
                result = await db.execute(
                    select(ManualChunk).where(ManualChunk.embedding_id == embedding_id)
                )
                db_chunk = result.scalar_one_or_none()
                
                if db_chunk:
                    # Проверяем, что контент не пустой
                    if db_chunk.content and len(db_chunk.content.strip()) > 0:
                        context_parts.append(db_chunk.content)
                        found_chunks_count += 1
                        sources.append({
                            "manual_id": chunk_info["manual_id"],
                            "car_id": chunk_info["car_id"],
                            "page": db_chunk.page,
                            "title": chunk_info["title"],
                            "score": float(chunk_info["score"]) if chunk_info["score"] else 0.0
                        })
                        logger.info(f"✅ Найден чанк в БД: embedding_id={embedding_id}, content_length={len(db_chunk.content)}, title={chunk_info.get('title', 'N/A')}")
                        logger.info(f"   Контент чанка (первые 300 символов): {db_chunk.content[:300]}...")
                    else:
                        logger.warning(f"⚠️  Чанк найден, но контент пустой: embedding_id={embedding_id}")
                else:
                    logger.warning(f"⚠️  Чанк не найден в БД: embedding_id={embedding_id}")
        else:
            # Если БД не передана, используем превью из Qdrant
            for chunk in relevant_chunks:
                if chunk.get("content"):
                    context_parts.append(chunk["content"])
                    found_chunks_count += 1
                    sources.append({
                        "manual_id": chunk["manual_id"],
                        "car_id": chunk["car_id"],
                        "page": chunk["page"],
                        "title": chunk["title"],
                        "score": chunk["score"]
                    })

        logger.info(f"📝 Используется {found_chunks_count} чанков для формирования контекста")
        
        if not context_parts:
            logger.error("❌ Не удалось получить контент чанков из БД")
            return {
                "answer": "В базе мануалов не найдено информации для ответа на ваш вопрос. Возможно, мануал еще обрабатывается или произошла ошибка при загрузке.",
                "sources": [],
                "context_preview": None
            }

        context = "\n\n---\n\n".join(context_parts)
        logger.info(f"📄 Общий размер контекста: {len(context)} символов")
        logger.info(f"📝 Первые 1000 символов контекста: {context[:1000]}...")
        logger.info(f"📝 Последние 500 символов контекста: ...{context[-500:]}")
        
        # Проверяем, что контекст не пустой
        if len(context.strip()) < 50:
            logger.error(f"❌ Контекст слишком короткий ({len(context)} символов)! Возможно, чанки пустые.")
            return {
                "answer": "В базе мануалов не найдено информации для ответа на ваш вопрос. Возможно, мануал еще обрабатывается или произошла ошибка при загрузке.",
                "sources": sources,
                "context_preview": RAGService._safe_preview(context) if context else None
            }

        # Формируем промпт для OpenAI
        user_prompt = f"""Контекст из мануала (используй только его, не добавляй свои знания):

{context}

Вопрос: {question}

Ответь только на основе контекста выше. Если в контексте есть хоть что-то по теме вопроса — дай краткий ответ по нему. Если в контексте совсем нет информации по вопросу — напиши только: «В предоставленном мануале нет информации для ответа на этот вопрос.»

ОТВЕТ:"""

        # Отправляем запрос в OpenAI
        try:
            from openai import AsyncOpenAI
            import httpx
            client_kwargs = {"api_key": settings.OPENAI_API_KEY}
            if getattr(settings, "OPENAI_PROXY", None) and str(settings.OPENAI_PROXY).strip():
                client_kwargs["http_client"] = httpx.AsyncClient(proxy=settings.OPENAI_PROXY)
            client = AsyncOpenAI(**client_kwargs)
            
            # Определяем параметры в зависимости от модели
            completion_params = {}
            
            # Для новых моделей (o1, o3, gpt-5) используем max_completion_tokens
            if "o1" in settings.OPENAI_MODEL.lower() or "o3" in settings.OPENAI_MODEL.lower() or "gpt-5" in settings.OPENAI_MODEL.lower():
                completion_params["max_completion_tokens"] = 1000
                # Эти модели не поддерживают temperature, используем только default (1)
                # Не добавляем temperature для этих моделей
            else:
                # Для остальных моделей (gpt-4o-mini, gpt-4o, gpt-3.5) используем max_tokens и temperature
                completion_params["max_tokens"] = 1000
                completion_params["temperature"] = 0.3
            
            logger.info(f"🤖 Отправляю запрос в OpenAI (модель: {settings.OPENAI_MODEL})")
            logger.info(f"   Размер промпта: {len(user_prompt)} символов")
            
            response = await client.chat.completions.create(
                model=settings.OPENAI_MODEL,
                messages=[
                    {"role": "system", "content": RAGService.SYSTEM_PROMPT},
                    {"role": "user", "content": user_prompt}
                ],
                **completion_params
            )
            
            answer = response.choices[0].message.content
            logger.info(f"✅ Получен ответ от OpenAI (длина: {len(answer) if answer else 0} символов)")
            if answer:
                logger.info(f"   Первые 200 символов ответа: {answer[:200]}...")
            if answer:
                answer = answer.strip()
            else:
                answer = "Не удалось сгенерировать ответ."
            
            # Превью контекста для вывода в консоль (безопасный UTF-8)
            context_preview = RAGService._safe_preview(context)

            return {
                "answer": answer,
                "sources": sources,
                "context_preview": context_preview
            }
        except Exception as e:
            logger.error(f"Ошибка при генерации ответа: {e}")
            raise
