# platform-observability-stack

A from-scratch, GitOps-managed observability platform on AWS EKS. It covers
metrics, logs, traces, SLOs, error budgets, burn-rate alerting, and chaos
engineering, built around a real sample application.

```
                         Application (frontend → backend → postgres)
                                          │
                 ┌────────────────────────┼────────────────────────┐
                 │                         │                         │
              Metrics                    Logs                     Traces
            Prometheus                   Loki                     Tempo
                 │                         │                         │
                 └────────────────────────┼────────────────────────┘
                                        Grafana
                                           │
                                      SLO Dashboard
                                           │
                                      Alertmanager
                                           │
                                    Slack / Email
```

## Phases

| # | Phase | Status | Where |
|---|-------|--------|-------|
| 1 | Platform foundation: EKS via Terraform (VPC, EKS, node groups, IRSA, Route53), reusable module + staging/production envs | ✅ done | `terraform/` |
| 2 | Sample app + GitOps (Helm + ArgoCD app-of-apps) | ✅ done | `app/`, `helm/`, `argocd/`, see [docs/PHASE2.md](docs/PHASE2.md) |
| 3 | Metrics: Prometheus, kube-state-metrics, node-exporter, custom app metrics | ✅ done | `prometheus/`, `argocd/apps/` see [docs/PHASE3.md](docs/PHASE3.md) |
| 4 | Logging: Loki + Promtail | ⬜ todo | `loki/` |
| 5 | Distributed tracing: Tempo + OpenTelemetry Collector | ⬜ todo | `tempo/`, `otel/` |
| 6 | SLI / SLO dashboards | ⬜ todo | `slo/` |
| 7 | Error budgets | ⬜ todo | `slo/` |
| 8 | Burn-rate alerts: Alertmanager to Slack | ⬜ todo | `alerts/` |
| 9 | Chaos engineering: LitmusChaos (bonus) | ⬜ todo | `chaos/` |

## Quick start

```bash
# 1. Provision the platform (Phase 1). Pick an environment
cd terraform/environments/staging   # or environments/production
terraform init && terraform apply
aws eks update-kubeconfig --region "$(terraform output -raw region)" \
  --name "$(terraform output -raw cluster_name)"

# 2. Deploy the app via GitOps (Phase 2)
#    (push your fork, replace OWNER placeholders, build/push images first;
#     full steps in docs/PHASE2.md)
./argocd/bootstrap/bootstrap.sh
```

## Repository structure

```
terraform/
  modules/platform/        Reusable Phase 1 module: VPC, EKS, node groups, IRSA, Route53
  environments/staging/    Composition: SPOT, single NAT, 2 AZ (cost-optimised)
  environments/production/ Composition: ON_DEMAND, NAT per-AZ, 3 AZ (HA)
app/         Sample application source (FastAPI backend, React frontend)
helm/        Helm charts: postgres, backend, frontend
argocd/      GitOps: AppProject, app-of-apps root, child Applications
prometheus/  loki/  tempo/  otel/  grafana/  alerts/  slo/  chaos/   (later phases)
docs/        Per-phase documentation
```

> Each environment keeps its **own remote state** (distinct S3 key, see each
> env's `backend.tf.example`); they share only the reusable module. `staging` is
> intentionally dev-grade; `production` defaults to HA but ships with the API
> endpoint CIDR as a `203.0.113.0/24` placeholder, so **replace it** before applying.
