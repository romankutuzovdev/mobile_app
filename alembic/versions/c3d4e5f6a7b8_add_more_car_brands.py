"""add more car brands

Revision ID: c3d4e5f6a7b8
Revises: b2c3d4e5f6a7
Create Date: 2026-03-03

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = 'c3d4e5f6a7b8'
down_revision: Union[str, None] = 'b2c3d4e5f6a7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

EXTRA_BRANDS = [
    "Acura", "Cadillac", "Dacia", "Daewoo", "Datsun", "DS", "Exeed",
    "Genesis", "GMC", "Great Wall", "Haval", "Hongqi", "Infiniti",
    "Jeep", "Jaguar", "Lada", "Lancia", "Lincoln", "MINI", "Moskvich",
    "Ora", "Porsche", "RAM", "Saab", "SEAT", "Smart", "SsangYong",
    "Suzuki", "Tank", "Togg", "UAZ", "Zeekr",
]


def upgrade() -> None:
    conn = op.get_bind()
    # Get max id
    r = conn.execute(sa.text("SELECT COALESCE(MAX(id), 0) FROM car_brands"))
    max_id = r.scalar() or 0
    for i, name in enumerate(EXTRA_BRANDS, max_id + 1):
        try:
            conn.execute(sa.text("INSERT INTO car_brands (id, name) VALUES (:id, :name)"), {"id": i, "name": name})
        except Exception:
            pass  # Skip if duplicate


def downgrade() -> None:
    conn = op.get_bind()
    for name in EXTRA_BRANDS:
        conn.execute(sa.text("DELETE FROM car_brands WHERE name = :name"), {"name": name})
