"""OpenTelemetry tracing setup.

If OTEL_EXPORTER_OTLP_ENDPOINT is unset, this is a no-op and the app runs with
zero tracing overhead. When the Helm values set it (Phase 5 points it at the
OpenTelemetry Collector), this configures a real tracer provider with an OTLP
exporter and instruments FastAPI and psycopg, so every HTTP request produces a
trace with a nested span for each database query.
"""
import logging
import os

log = logging.getLogger("app.tracing")


def setup_tracing(app) -> None:
    endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
    if not endpoint:
        log.info("OTEL_EXPORTER_OTLP_ENDPOINT unset, tracing disabled")
        return

    # Imported lazily so the app starts even if these extras are not installed in
    # a minimal local environment.
    from opentelemetry import trace
    from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
    from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
    from opentelemetry.instrumentation.psycopg import PsycopgInstrumentor
    from opentelemetry.sdk.resources import Resource
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import BatchSpanProcessor

    service_name = os.getenv("OTEL_SERVICE_NAME", "backend")
    provider = TracerProvider(resource=Resource.create({"service.name": service_name}))

    # insecure=True because the collector listens on plaintext gRPC inside the
    # cluster. BatchSpanProcessor ships spans in the background off the hot path.
    provider.add_span_processor(
        BatchSpanProcessor(OTLPSpanExporter(endpoint=endpoint, insecure=True))
    )
    trace.set_tracer_provider(provider)

    FastAPIInstrumentor.instrument_app(app)
    PsycopgInstrumentor().instrument()
    log.info("OpenTelemetry tracing enabled, exporting to %s as %s", endpoint, service_name)
