from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List, Optional
from uuid import UUID

from app.models.manual import Manual, ManualChunk


class ManualRepository:
    """Репозиторий для работы с мануалами"""

    @staticmethod
    async def create_manual(
        db: AsyncSession,
        title: str,
        source_file: str,
        brand: str,
        model: str,
        year: int,
        car_id: Optional[int] = None
    ) -> Manual:
        """Создание мануала в глобальном каталоге"""
        db_manual = Manual(
            title=title,
            source_file=source_file,
            brand=brand,
            model=model,
            year=year,
            car_id=car_id
        )
        db.add(db_manual)
        await db.commit()
        await db.refresh(db_manual)
        return db_manual

    @staticmethod
    async def get_manual_by_id(db: AsyncSession, manual_id: UUID) -> Optional[Manual]:
        """Получение мануала по ID"""
        result = await db.execute(select(Manual).where(Manual.id == manual_id))
        return result.scalar_one_or_none()

    @staticmethod
    async def get_all_manuals(db: AsyncSession) -> List[Manual]:
        """Получение списка всех мануалов"""
        result = await db.execute(select(Manual).order_by(Manual.created_at.desc()))
        return list(result.scalars().all())

    @staticmethod
    async def get_manuals_by_car_id(db: AsyncSession, car_id: int) -> List[Manual]:
        """Получение мануалов по car_id (legacy)"""
        result = await db.execute(
            select(Manual).where(Manual.car_id == car_id).order_by(Manual.created_at.desc())
        )
        return list(result.scalars().all())

    @staticmethod
    async def get_manuals_by_brand_model_year(
        db: AsyncSession, brand: str, model: str, year: int
    ) -> List[Manual]:
        """Мануалы для машины по совпадению brand/model/year. model — точное или вхождение."""
        from sqlalchemy import func, or_
        b, m = brand.strip().lower(), model.strip().lower()
        if not m:
            m = " "
        result = await db.execute(
            select(Manual)
            .where(
                func.lower(Manual.brand) == b,
                Manual.year == year,
                or_(
                    func.lower(Manual.model).contains(m),
                    func.lower(Manual.model) == m
                )
            )
            .order_by(Manual.created_at.desc())
        )
        return list(result.scalars().all())

    @staticmethod
    async def get_all_manuals_global(db: AsyncSession) -> List[Manual]:
        """Все мануалы глобального каталога"""
        result = await db.execute(
            select(Manual).order_by(Manual.brand, Manual.model, Manual.year, Manual.created_at.desc())
        )
        return list(result.scalars().all())

    @staticmethod
    async def get_orphaned_manuals(db: AsyncSession) -> List[Manual]:
        """Мануалы без привязки к авто (car_id = NULL, например после удаления машины)"""
        result = await db.execute(
            select(Manual).where(Manual.car_id.is_(None)).order_by(Manual.created_at.desc())
        )
        return list(result.scalars().all())

    @staticmethod
    async def update_car_id(db: AsyncSession, manual_id: UUID, car_id: int) -> Optional[Manual]:
        """Привязать мануал к автомобилю"""
        manual = await ManualRepository.get_manual_by_id(db, manual_id)
        if not manual:
            return None
        manual.car_id = car_id
        await db.commit()
        await db.refresh(manual)
        return manual

    @staticmethod
    async def delete_manual(db: AsyncSession, manual_id: UUID) -> bool:
        """Удаление мануала"""
        manual = await ManualRepository.get_manual_by_id(db, manual_id)
        if not manual:
            return False

        await db.delete(manual)
        await db.commit()
        return True

    @staticmethod
    async def create_chunk(
        db: AsyncSession,
        manual_id: UUID,
        content: str,
        embedding_id: str,
        page: Optional[int] = None
    ) -> ManualChunk:
        """Создание чанка мануала"""
        db_chunk = ManualChunk(
            manual_id=manual_id,
            content=content,
            embedding_id=embedding_id,
            page=page
        )
        db.add(db_chunk)
        await db.commit()
        await db.refresh(db_chunk)
        return db_chunk

    @staticmethod
    async def get_chunks_by_manual_id(db: AsyncSession, manual_id: UUID) -> List[ManualChunk]:
        """Получение всех чанков мануала"""
        result = await db.execute(
            select(ManualChunk).where(ManualChunk.manual_id == manual_id)
        )
        return list(result.scalars().all())

    @staticmethod
    async def delete_chunks_by_manual_id(db: AsyncSession, manual_id: UUID) -> int:
        """Удаление всех чанков мануала"""
        chunks = await ManualRepository.get_chunks_by_manual_id(db, manual_id)
        count = len(chunks)
        for chunk in chunks:
            await db.delete(chunk)
        await db.commit()
        return count
