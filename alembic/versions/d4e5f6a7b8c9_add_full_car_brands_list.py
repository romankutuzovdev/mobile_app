"""add full car brands list (~150 brands)

Revision ID: d4e5f6a7b8c9
Revises: c3d4e5f6a7b8
Create Date: 2026-03-03

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = 'd4e5f6a7b8c9'
down_revision: Union[str, None] = 'c3d4e5f6a7b8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# Полный список марок (по скриншоту каталога + распространённые)
FULL_BRANDS_LIST = [
    "ARO", "Abarth", "Acura", "Aeolus", "Aiways", "Alfa Romeo", "Alpine", "Aion",
    "Aston Martin", "Audi", "BAIC", "BAW", "BYD", "Bentley", "Bestune", "Borgward",
    "Brilliance", "Buick", "Cadillac", "Changan", "Chery", "Chevrolet", "Chrysler",
    "Citroen", "Cupra", "Dacia", "Daewoo", "Daihatsu", "Datsun", "Denza", "DFSK",
    "Dodge", "Dongfeng", "DS", "Exeed", "FAW", "Ferrari", "Fiat", "Fisker", "Ford",
    "Foton", "GAC", "GAZ", "Genesis", "Geely", "GMC", "Great Wall", "Haval",
    "Hawtai", "Hongqi", "Honda", "Hyundai", "Infiniti", "Isuzu", "JAC",
    "Jaguar", "Jaecoo", "Jeep", "Jetour", "Jetta", "Jinbei", "JMEV", "Kia", "KGM",
    "Lamborghini", "Lancia", "Land Rover", "Lada (ВАЗ)", "Leapmotor", "Lexus",
    "Li Auto", "Lincoln", "Livan", "Lotus", "Lucid", "Lynk & Co", "MG", "Mahindra",
    "Maserati", "Maxus", "Mazda", "McLaren", "Mercedes-Benz", "Mercedes-Maybach",
    "MHERO", "MINI", "Mitsubishi", "Morgan", "Москвич", "Neta",
    "Nio", "Nissan", "Oldsmobile", "Omoda", "Opel", "Ora", "Oting", "Pagani",
    "Peugeot", "Polestar", "Porsche", "Proton", "RAM", "Renault", "Rivian",
    "Roewe", "Rolls-Royce", "Rox", "SAIPA", "Saturn", "Scion", "SEAT", "SERES",
    "Shineray", "Skoda", "Skywell", "Smart", "SsangYong", "Subaru", "Suzuki",
    "Tank", "Tata", "Tesla", "Togg", "Toyota", "Vauxhall", "Volkswagen", "Volvo",
    "Vortex", "Voyah", "Wartburg", "Wuling", "Xiaomi", "Xpeng", "Zeekr", "ZX",
    # Российские и СНГ (как в каталоге)
    "Богдан", "ГАЗ", "ЕрАЗ", "ЗАЗ", "ИЖ", "ЛуАЗ", "ТагАЗ", "УАЗ", "Эксклюзив",
]


def upgrade() -> None:
    conn = op.get_bind()
    r = conn.execute(sa.text("SELECT COALESCE(MAX(id), 0) FROM car_brands"))
    max_id = r.scalar() or 0
    seen = set()
    for i, name in enumerate(FULL_BRANDS_LIST, max_id + 1):
        if not name or name in seen:
            continue
        seen.add(name)
        conn.execute(
            sa.text(
                "INSERT INTO car_brands (id, name) VALUES (:id, :name) "
                "ON CONFLICT (name) DO NOTHING"
            ),
            {"id": i, "name": name}
        )


def downgrade() -> None:
    conn = op.get_bind()
    for name in FULL_BRANDS_LIST:
        if name:
            try:
                conn.execute(sa.text("DELETE FROM car_brands WHERE name = :name"), {"name": name})
            except Exception:
                pass
