"""add car_brands table

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f6
Create Date: 2026-03-03

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = 'b2c3d4e5f6a7'
down_revision: Union[str, None] = 'a1b2c3d4e5f6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


POPULAR_BRANDS = [
    "Alfa Romeo", "Audi", "BMW", "BYD", "Chevrolet", "Chrysler",
    "Citroen", "Dodge", "Fiat", "Ford", "Geely", "Honda",
    "Hyundai", "Kia", "Lada (ВАЗ)", "Land Rover", "Lexus",
    "Mazda", "Mercedes-Benz", "Mitsubishi", "Nissan", "Opel",
    "Peugeot", "Renault", "Skoda", "Subaru", "Tesla",
    "Toyota", "Volkswagen", "Volvo",
]


def upgrade() -> None:
    op.create_table(
        'car_brands',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(100), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('name')
    )
    op.create_index(op.f('ix_car_brands_id'), 'car_brands', ['id'], unique=False)

    # Seed популярных марок
    conn = op.get_bind()
    for i, name in enumerate(POPULAR_BRANDS, 1):
        conn.execute(sa.text("INSERT INTO car_brands (id, name) VALUES (:id, :name)"), {"id": i, "name": name})


def downgrade() -> None:
    op.drop_index(op.f('ix_car_brands_id'), table_name='car_brands')
    op.drop_table('car_brands')
