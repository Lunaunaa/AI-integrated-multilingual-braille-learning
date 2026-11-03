
import os

import psycopg
from psycopg.rows import dict_row


def get_connection():
    database_url = os.getenv("RESONANT_DATABASE_URL")
    if not database_url:
        raise RuntimeError(
            "RESONANT_DATABASE_URL is not configured."
        )

    return psycopg.connect(
        database_url,
        row_factory=dict_row,
    )


def test_connection():
    with get_connection() as conn:
        row = conn.execute(
            "SELECT current_database() AS database_name"
        ).fetchone()

        return row["database_name"]
