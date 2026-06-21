# Phase 7: Error budgets

Builds on the Phase 6 SLIs and SLO targets to answer a single question: how much
unreliability does each SLO still allow this month?

## The idea

An SLO of 99.9 percent availability says 0.1 percent of requests are allowed to
fail. Over a rolling 30 day window that 0.1 percent is the **error budget**. The
latency SLO of 95 percent under 500ms gives a 5 percent budget. As errors (or slow
requests) accrue, the budget is spent; when it runs out the SLO is breached.

| SLI | SLO target | Error budget |
|-----|-----------|--------------|
| Availability | 99.9 percent | 0.1 percent of requests |
| Latency | 95 percent under 500ms | 5 percent of requests |

## What lives where

| Path | Purpose |
|------|---------|
| `slo/error-budget-rules.yaml` | PrometheusRule: budgets, 30d SLIs, consumed and remaining ratios |
| `grafana/dashboards/slo-error-budget.yaml` | Error budget dashboard as a sidecar ConfigMap |
| `prometheus/values.yaml` | retention bumped to 30d so the window has data |

## Recorded series

```
slo:availability:error_budget                 slo:latency:error_budget
sli:availability:ratio_rate30d                sli:latency:ratio_rate30d
slo:availability:error_budget_consumed_ratio  slo:latency:error_budget_consumed_ratio
slo:availability:error_budget_remaining_ratio slo:latency:error_budget_remaining_ratio
```

The consumed ratio is `(1 - SLI) / error_budget`: 0 means nothing spent, 1 means
the budget is exactly exhausted, above 1 means the SLO is breached. Remaining is
`1 - consumed`. The group evaluates every 5 minutes because a 30 day budget does
not move fast and the 30 day range queries are not cheap to run every 30 seconds.

## Why retention had to change

The budget rules `rate(...[30d])`, so Prometheus needs 30 days of samples on disk.
Phase 3 set retention to 15d, so `prometheus/values.yaml` now sets `retention: 30d`
(the `retentionSize: 18GB` cap still applies, whichever is hit first wins). The
remaining and consumed series only become meaningful once 30 days of data exist;
before that they reflect the data on hand.

## Deploy

```bash
git add slo grafana/dashboards prometheus/values.yaml argocd docs
git commit -m "phase 7: error budgets"
git push

# Prometheus re-syncs with the new retention and rules
kubectl -n argocd patch app kube-prometheus-stack --type merge -p '{"operation":{"sync":{}}}'
kubectl -n argocd patch app slo --type merge -p '{"operation":{"sync":{}}}'
```

## View it

Open Grafana, find the **Backend Error Budget** dashboard: two gauges for budget
remaining (availability and latency), two stats for budget consumed, and time
series for budget remaining and the 30d SLI against target. Check the raw series
in Prometheus too:

```promql
slo:availability:error_budget_remaining_ratio
slo:availability:error_budget_consumed_ratio
```

## Next

Phase 8 puts multi window burn rate alerts on top of these budgets and routes
them to Slack by severity.
