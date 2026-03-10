"""Add brand, model, year to manuals for global catalog

Revision ID: e5f6a7b8c9d0
Revises: d4e5f6a7b8c9
Create Date: 2026-03-03

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


revision: str = 'e5f6a7b8c9d0'
down_revision: Union[str, None] = 'd4e5f6a7b8c9'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('manuals', sa.Column('brand', sa.String(100), nullable=True))
    op.add_column('manuals', sa.Column('model', sa.String(150), nullable=True))
    op.add_column('manuals', sa.Column('year', sa.Integer(), nullable=True))

    # Заполняем из cars для существующих мануалов
    conn = op.get_bind()
    conn.execute(sa.text("""
        UPDATE manuals m
        SET brand = c.brand, model = c.model, year = c.year
        FROM cars c
        WHERE m.car_id = c.id AND m.brand IS NULL
    """))
    # Для orphaned ставим дефолты
    conn.execute(sa.text("""
        UPDATE manuals SET brand = 'Unknown', model = 'Manual', year = 2000
        WHERE brand IS NULL
    """))

    op.alter_column('manuals', 'brand', nullable=False)
    op.alter_column('manuals', 'model', nullable=False)
    op.alter_column('manuals', 'year', nullable=False)
    op.create_index('ix_manuals_brand', 'manuals', ['brand'])
    op.create_index('ix_manuals_model', 'manuals', ['model'])
    op.create_index('ix_manuals_year', 'manuals', ['year'])


def downgrade() -> None:
    op.drop_index('ix_manuals_year', 'manuals')
    op.drop_index('ix_manuals_model', 'manuals')
    op.drop_index('ix_manuals_brand', 'manuals')
    op.drop_column('manuals', 'year')
    op.drop_column('manuals', 'model')
    op.drop_column('manuals', 'brand')
