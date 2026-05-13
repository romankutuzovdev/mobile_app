"""add catalog_trim_id to chat_messages for Car API catalog GPT threads

Revision ID: f8a9b0c1d2e3
Revises: e5f6a7b8c9d0
Create Date: 2026-05-13

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "f8a9b0c1d2e3"
down_revision: Union[str, None] = "e5f6a7b8c9d0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "chat_messages",
        sa.Column("catalog_trim_id", sa.Integer(), nullable=True),
    )
    op.create_index(
        "ix_chat_messages_catalog_trim_id",
        "chat_messages",
        ["catalog_trim_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_chat_messages_catalog_trim_id", table_name="chat_messages")
    op.drop_column("chat_messages", "catalog_trim_id")
