"""Postgres access via a psycopg3 connection pool.

The pool is opened on app startup and closed on shutdown (see main.py lifespan).
`init_schema()` is idempotent so the app is safe to roll/restart under ArgoCD.
"""
import logging

from psycopg_pool import ConnectionPool

from .config import get_settings

log = logging.getLogger("app.db")

_pool: ConnectionPool | None = None


def open_pool() -> None:
    global _pool
    settings = get_settings()
    _pool = ConnectionPool(
        conninfo=settings.db_conninfo,
        min_size=settings.db_pool_min,
        max_size=settings.db_pool_max,
        open=True,
        name="appdb-pool",
    )
    log.info("opened postgres pool -> %s:%s/%s",
             settings.db_host, settings.db_port, settings.db_name)


def close_pool() -> None:
    if _pool is not None:
        _pool.close()


def pool() -> ConnectionPool:
    if _pool is None:
        raise RuntimeError("connection pool is not open")
    return _pool


def init_schema() -> None:
    """Create the demo table if it doesn't exist. Idempotent."""
    with pool().connection() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS items (
                id         SERIAL PRIMARY KEY,
                name       TEXT NOT NULL,
                created_at TIMESTAMPTZ NOT NULL DEFAULT now()
            )
            """
        )


def ping() -> bool:
    """Cheap connectivity check used by the readiness probe."""
    with pool().connection() as conn:
        conn.execute("SELECT 1")
    return True
