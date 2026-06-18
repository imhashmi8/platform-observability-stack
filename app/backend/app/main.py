"""FastAPI entrypoint for the sample backend.

Wires together:
  - structured-ish JSON-friendly logging (consumed by Loki/Promtail in Phase 4)
  - Prometheus metrics middleware + /metrics endpoint (Phase 3)
  - OpenTelemetry hooks (Phase 5)
  - a tiny items API backed by Postgres, plus health/readiness probes
"""
import logging
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request, Response
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest
from pydantic import BaseModel

from . import db
from .config import get_settings
from .metrics import (
    ITEMS_CREATED,
    REQUEST_COUNT,
    REQUEST_LATENCY,
    REQUESTS_IN_PROGRESS,
)
from .tracing import setup_tracing

settings = get_settings()

logging.basicConfig(
    level=settings.log_level.upper(),
    format='{"ts":"%(asctime)s","level":"%(levelname)s","logger":"%(name)s","msg":"%(message)s"}',
)
log = logging.getLogger("app")


@asynccontextmanager
async def lifespan(_: FastAPI):
    db.open_pool()
    db.init_schema()
    log.info("startup complete env=%s", settings.environment)
    yield
    db.close_pool()
    log.info("shutdown complete")


app = FastAPI(title=settings.app_name, lifespan=lifespan)
setup_tracing(app)


@app.middleware("http")
async def prometheus_middleware(request: Request, call_next):
    """Record RED metrics for every request using the matched route template."""
    REQUESTS_IN_PROGRESS.inc()
    start = time.perf_counter()
    status = 500
    try:
        response = await call_next(request)
        status = response.status_code
        return response
    finally:
        # `route.path` is the template (/items/{item_id}); fall back to the raw
        # path only for unmatched routes (404s), which are naturally bounded.
        route = request.scope.get("route")
        path = getattr(route, "path", request.url.path)
        elapsed = time.perf_counter() - start
        REQUEST_LATENCY.labels(request.method, path).observe(elapsed)
        REQUEST_COUNT.labels(request.method, path, str(status)).inc()
        REQUESTS_IN_PROGRESS.dec()


# -----------------------------------------------------------------------------
# Observability endpoints
# -----------------------------------------------------------------------------
@app.get("/metrics")
def metrics() -> Response:
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/healthz")
def healthz() -> dict:
    """Liveness — process is up. Cheap, never touches the DB."""
    return {"status": "ok"}


@app.get("/readyz")
def readyz() -> dict:
    """Readiness — can we actually serve traffic (DB reachable)?"""
    try:
        db.ping()
    except Exception as exc:  # noqa: BLE001 - surface any DB failure as not-ready
        log.warning("readiness check failed: %s", exc)
        raise HTTPException(status_code=503, detail="database unavailable")
    return {"status": "ready"}


# -----------------------------------------------------------------------------
# Demo API — frontend talks to these; later phases trace/measure them.
# -----------------------------------------------------------------------------
class ItemIn(BaseModel):
    name: str


class Item(BaseModel):
    id: int
    name: str


@app.get("/api/items", response_model=list[Item])
def list_items() -> list[Item]:
    with db.pool().connection() as conn:
        rows = conn.execute("SELECT id, name FROM items ORDER BY id DESC LIMIT 100").fetchall()
    return [Item(id=r[0], name=r[1]) for r in rows]


@app.post("/api/items", response_model=Item, status_code=201)
def create_item(item: ItemIn) -> Item:
    with db.pool().connection() as conn:
        row = conn.execute(
            "INSERT INTO items (name) VALUES (%s) RETURNING id, name",
            (item.name,),
        ).fetchone()
    ITEMS_CREATED.inc()
    log.info("created item id=%s", row[0])
    return Item(id=row[0], name=row[1])


@app.get("/api/info")
def info() -> dict:
    """Surface a bit of runtime context for the frontend to display."""
    return {"app": settings.app_name, "environment": settings.environment}
