"""Prometheus instrumentation.

Exposes the RED-method signals the Phase 3 dashboards and Phase 6 SLOs are built
on: Request rate, Errors, Duration. The `/metrics` endpoint (registered in
main.py) is scraped by Prometheus via the ServiceMonitor in helm/backend.

Metrics are *defined* here and *recorded* by the middleware in main.py, which is
the only place that has both the matched route template and the final status.
"""
from prometheus_client import Counter, Gauge, Histogram

# Total HTTP requests, split by the labels every RED query needs.
# `path` is always the route TEMPLATE (e.g. /items/{item_id}) — using the raw URL
# would blow up label cardinality and OOM Prometheus.
REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests processed.",
    ["method", "path", "status"],
)

# Request latency. Buckets straddle the 500ms Phase 6 latency SLO threshold so
# histogram_quantile() and SLO burn-rate queries stay accurate around it.
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds.",
    ["method", "path"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 0.75, 1.0, 2.5, 5.0),
)

# In-flight requests — useful for spotting saturation / pile-ups.
REQUESTS_IN_PROGRESS = Gauge(
    "http_requests_in_progress",
    "HTTP requests currently being served.",
)

# A business-level metric to demonstrate "custom app metrics" beyond raw HTTP.
ITEMS_CREATED = Counter(
    "items_created_total",
    "Total items created via the API.",
)
