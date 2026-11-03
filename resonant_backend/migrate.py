"""Apply versioned SQL migrations to the isolated `resonant` schema."""

from pathlib import Path
import re

from database import get_connection


MIGRATIONS_DIR = Path(__file__).parent / "migrations"


def run_migrations(connection_factory=get_connection, migrations_dir=MIGRATIONS_DIR):
    applied_now = []
    with connection_factory() as connection:
        connection.execute(
            "SELECT pg_advisory_xact_lock(hashtext('resonant_schema_migrations'))"
        )
        connection.execute("CREATE SCHEMA IF NOT EXISTS resonant")
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS resonant.schema_migrations (
                version INTEGER PRIMARY KEY,
                filename TEXT NOT NULL,
                applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
            )
            """
        )
        rows = connection.execute(
            "SELECT version FROM resonant.schema_migrations"
        ).fetchall()
        applied = {row["version"] for row in rows}

        for path in sorted(Path(migrations_dir).glob("[0-9]*_*.sql")):
            match = re.match(r"^(\d+)_", path.name)
            if not match:
                continue
            version = int(match.group(1))
            if version in applied:
                continue

            sql = path.read_text(encoding="utf-8")
            # Current migrations contain plain DDL only (no procedural blocks).
            # Execute each statement in the surrounding connection transaction.
            for statement in sql.split(";"):
                if statement.strip():
                    connection.execute(statement)
            connection.execute(
                """
                INSERT INTO resonant.schema_migrations (version, filename)
                VALUES (%s, %s)
                """,
                (version, path.name),
            )
            applied_now.append(version)
    return applied_now


if __name__ == "__main__":
    print(f"Applied migrations: {run_migrations()}")
