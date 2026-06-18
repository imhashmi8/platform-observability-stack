"""OpenTelemetry tracing setup — instrumented now, exporting in Phase 5.

If OTEL_EXPORTER_OTLP_ENDPOINT is unset (the default before the Tempo / OTel
Collector phase), this is a no-op and the app runs with zero tracing overhead.
Once Phase 5 sets that env var via the Helm values, spans for every HTTP request
and DB query start flowing to the collector with no code change.
"""
import logging
import os

log = logging.getLogger("app.tracing")


def setup_tracing(app) -> None:
    if not os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT"):
        log.info("OTEL_EXPORTER_OTLP_ENDPOINT unset — tracing disabled (Phase 5 wires this up)")
        return

    # Imported lazily so the app starts even if these extras aren't installed
    # in a minimal local environment.
    from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
    from opentelemetry.instrumentation.psycopg import PsycopgInstrumentor

    FastAPIInstrumentor.instrument_app(app)
    PsycopgInstrumentor().instrument()
    log.info("OpenTelemetry tracing enabled -> %s", os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT"))
