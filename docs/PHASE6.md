# Phase 6: SLI and SLO

Turns the raw RED metrics from Phase 3 into service level objectives. Two SLIs are
defined as Prometheus recording rules, the SLO targets are recorded as constant
series, and a Grafana dashboard shows current SLIs against those targets.

## SLIs and SLOs

| SLI | Definition | SLO target |
|-----|-----------|------------|
| Availability | successful requests / total requests | 99.9 percent |
| Latency | requests served faster than 500ms / total requests | 95 percent under 500ms |

Health and metrics endpoints (`/healthz`, `/readyz`, `/metrics`) are excluded
because they are not user facing traffic.

## What lives where

| Path | Purpose |
|------|---------|
| `slo/recording-rules.yaml` | PrometheusRule with the SLI recording rules and SLO target series |
| `grafana/dashboards/slo-backend.yaml` | SLO dashboard as a sidecar ConfigMap |
| `argocd/apps/slo.yaml` | ArgoCD Application that applies everything in `slo/` |
| `argocd/apps/grafana-dashboards.yaml` | ArgoCD Application that applies everything in `grafana/dashboards/` |

## Why recording rules

The SLIs are precomputed as recording rules rather than queried inline. Three
reasons:

1. The dashboard, the error budget in Phase 7, and the burn rate alerts in Phase 8
   all read the exact same series, so the numbers can never disagree.
2. The ratios are cheap to read once recorded, which keeps dashboards and alert
   evaluation fast.
3. The SLO targets live in one place as `slo:availability:target` and
   `slo:latency:target`, so changing a target is a one line edit.

Recorded series:

```
sli:availability:ratio_rate5m     sli:availability:ratio_rate30m
sli:latency:ratio_rate5m          sli:latency:ratio_rate30m
slo:availability:target           slo:latency:target
```

Prometheus discovers the rules automatically because Phase 3 set
`ruleSelectorNilUsesHelmValues` to false, so no extra wiring is needed.

## Deploy

```bash
git add slo grafana/dashboards argocd
git commit -m "phase 6: SLI and SLO"
git push

kubectl -n argocd get applications
# rules show up under Prometheus, Status, Rules
# dashboard shows up in Grafana as "Backend SLO"
```

## View it

Generate some backend traffic (see Phase 2), then open Grafana and find the
**Backend SLO** dashboard. It shows the availability and latency SLIs as stat
panels coloured against their targets, the error rate, availability over time
with the target line, p95 latency against the 500ms threshold, and request rate
by status.

You can also check the raw SLIs in Prometheus:

```promql
sli:availability:ratio_rate5m
sli:latency:ratio_rate5m
```

## Next

Phase 7 uses these same SLIs to compute the error budget (how much unreliability
the 99.9 percent target allows over a window, and how much is left). Phase 8 adds
multi window burn rate alerts on top.
