# Phase 5: Distributed Tracing

Adds the traces pillar with Tempo and an OpenTelemetry Collector, and turns on
the tracing that was stubbed into the backend back in Phase 2. A single request
to the backend now produces a trace whose spans show where the time went: the
HTTP handler and each database query underneath it.

```
 backend (FastAPI + psycopg, OTLP SDK)
        |  OTLP gRPC
        v
 OpenTelemetry Collector  (receive, batch, forward)
        |  OTLP gRPC
        v
 Tempo (single binary + filesystem PV)
        |
        v
 Grafana  (search traces, jump to logs in Loki)
```

## What lives where

| Path | Purpose |
|------|---------|
| `tempo/tempo-values.yaml` | Tempo chart values, single binary with a filesystem PV |
| `otel/collector-values.yaml` | Collector values, OTLP in and Tempo out |
| `app/backend/app/tracing.py` | Configures the tracer provider and OTLP exporter |
| `helm/backend/values.yaml` | `otel.endpoint` now points at the collector |
| `grafana/datasources/tempo.yaml` | Tempo data source with a trace to logs link |
| `argocd/apps/tempo.yaml`, `argocd/apps/otel-collector.yaml` | ArgoCD Applications |

Tempo and the collector run in a new `tracing` namespace.

## How the application is instrumented

In Phase 2 the backend only attached the FastAPI and psycopg instrumentation,
which on its own does not export anything. This phase completes it: when
`OTEL_EXPORTER_OTLP_ENDPOINT` is set, `tracing.py` builds a real tracer provider
with a resource (`service.name`), a BatchSpanProcessor, and an OTLP gRPC exporter.
The Helm values set that env var to the collector address, so no image rebuild is
needed beyond shipping the updated `tracing.py`.

Spans flow as application to collector to Tempo, all over OTLP gRPC. The collector
sits in the middle on purpose. It gives one place to batch, sample, or add more
exporters later without changing the application.

## How traces and logs connect

The Tempo data source defines a trace to logs link to Loki. From a span in
Grafana you can open the matching logs scoped to the same time window. The link
maps the span's `service.name` onto the Loki `app` label that Promtail sets, so
it lands on that service's logs. If your Promtail label scheme differs, adjust
the tag mapping in `grafana/datasources/tempo.yaml`.

## Deploy

```bash
# rebuild and push the backend image so the tracing.py change ships, then bump
# the tag in helm/backend/values.yaml
docker build -t $REGISTRY/platform-obs-backend:$TAG app/backend
docker push $REGISTRY/platform-obs-backend:$TAG

git add tempo otel app helm grafana argocd
git commit -m "phase 5: tracing"
git push

kubectl -n argocd get applications
kubectl -n tracing get pods
```

## See a trace

Generate a request against the backend (see Phase 2 for the port-forward), then in
Grafana open Explore, pick the Tempo data source, and run a TraceQL search:

```traceql
{ resource.service.name = "backend" }
```

Open a trace and you should see the request handler span with a child span for
the SQL query, each with its own duration. That breakdown of frontend to backend
to database timing is the payoff of this phase. Use the trace to logs button on a
span to jump straight to the backend's logs for that request's time window.

## Production notes

Tempo runs here in single binary mode on a filesystem volume, and the
grafana/tempo chart is deprecated in favour of tempo-distributed. For production
you would move to tempo-distributed backed by an S3 bucket (IRSA from Phase 1).

Browser side tracing for the React frontend is not included. The trace currently
starts at the backend. Adding frontend spans would mean instrumenting the SPA with
the OpenTelemetry web SDK and allowing CORS to the collector, which can be a later
enhancement if you want the very first hop in the trace.
