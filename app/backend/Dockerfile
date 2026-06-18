# syntax=docker/dockerfile:1
# Multi-stage build: deps in a builder layer, slim runtime, non-root user.
FROM python:3.12-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app
COPY requirements.txt .
RUN python -m venv /opt/venv \
    && /opt/venv/bin/pip install --upgrade pip \
    && /opt/venv/bin/pip install -r requirements.txt


FROM python:3.12-slim AS runtime

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Run as an unprivileged user (matches the chart's securityContext).
RUN useradd --create-home --uid 10001 appuser
WORKDIR /app

COPY --from=builder /opt/venv /opt/venv
COPY app ./app

USER appuser
EXPOSE 8000

# Single worker per pod — scale horizontally via the Deployment/HPA, not workers,
# so each replica's metrics map cleanly to one Prometheus target.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
