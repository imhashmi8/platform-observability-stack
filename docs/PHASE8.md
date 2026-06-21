# Phase 8: Burn-rate alerts to Slack

Turns the Phase 7 error budgets into pages. Instead of alerting on a raw error
rate (noisy, no link to the SLO), this alerts on **burn rate**: how fast the
budget is being spent relative to the SLO window.

## Multi window, multi burn rate

Each alert requires BOTH a long and a short window to be over the threshold. The
long window proves the burn is sustained; the short window lets the alert clear
quickly once the problem stops. This is the Google SRE workbook pattern.

| Alert severity | Long / short | Burn rate | Budget spent before firing | Routing |
|----------------|--------------|-----------|----------------------------|---------|
| critical | 1h / 5m | 14.4 | 2 percent | page (`#alerts-critical`) |
| critical | 6h / 30m | 6 | 5 percent | page (`#alerts-critical`) |
| warning | 1d / 2h | 3 | 10 percent | ticket (`#alerts-warning`) |
| warning | 3d / 6h | 1 | 10 percent | ticket (`#alerts-warning`) |

Availability gets all four; latency gets the two fast-burn alerts. Two extra
warnings fire when a budget drops below 10 percent remaining.

Thresholds are `burn_rate * scalar(slo:<sli>:error_budget)`, so the budget value
lives in exactly one place (Phase 7) and the alerts reference it.

## What lives where

| Path | Purpose |
|------|---------|
| `alerts/burn-rate-rules.yaml` | PrometheusRule: per-window error ratios + burn rate alerts |
| `argocd/apps/alerts.yaml` | ArgoCD Application that applies everything in `alerts/` |
| `prometheus/values.yaml` | Alertmanager routes and Slack receivers |

## The Slack webhook is a secret

The webhook URL is never committed. Alertmanager reads it from a mounted Secret
via `slack_api_url_file`. Create an incoming webhook in Slack, then:

```bash
kubectl -n monitoring create secret generic alertmanager-slack \
  --from-literal=webhook='https://hooks.slack.com/services/XXX/YYY/ZZZ'
```

`alertmanagerSpec.secrets: [alertmanager-slack]` mounts it at
`/etc/alertmanager/secrets/alertmanager-slack/webhook`. Both receivers read that
file. Create the two channels (`#alerts-critical`, `#alerts-warning`) or change
the channel names in `prometheus/values.yaml`.

## Deploy

```bash
# 1. Create the Slack webhook secret (above) first
# 2. Ship the rules and Alertmanager config
git add alerts prometheus/values.yaml argocd docs
git commit -m "phase 8: burn rate alerts to Slack"
git push

kubectl -n argocd patch app kube-prometheus-stack --type merge -p '{"operation":{"sync":{}}}'
kubectl -n argocd patch app alerts --type merge -p '{"operation":{"sync":{}}}'
```

The Watchdog alert (always firing by design) is routed to a null receiver so it
does not spam Slack. A critical burn for an SLO inhibits the warning burns for the
same SLO.

## Verify

```bash
# Alerts should appear in Prometheus, Status, Rules and in Alertmanager
kubectl -n monitoring get prometheusrule slo-backend-burn-rate
```

In the Prometheus UI (`/prometheus`) check the rules loaded under Status, Rules.
To force a page, drive a burst of 5xx from the backend (or scale it to zero so
requests fail) and watch `#alerts-critical` after the fast-burn `for: 2m` window.

## Next

Phase 9 (bonus) injects failure with LitmusChaos to confirm the app recovers and
these alerts behave as intended.
