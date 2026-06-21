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
| 4 | Logging: Loki + Promtail | ✅ done | `loki/`, `grafana/datasources/` see [docs/PHASE4.md](docs/PHASE4.md) |
| 5 | Distributed tracing: Tempo + OpenTelemetry Collector | ✅ done | `tempo/`, `otel/` see [docs/PHASE5.md](docs/PHASE5.md) |
| 6 | SLI / SLO dashboards | ✅ done | `slo/`, `grafana/dashboards/` see [docs/PHASE6.md](docs/PHASE6.md) |
| 7 | Error budgets | ✅ done | `slo/`, `grafana/dashboards/` see [docs/PHASE7.md](docs/PHASE7.md) |
| 8 | Burn-rate alerts: Alertmanager to Slack | ✅ done | `alerts/`, `prometheus/` see [docs/PHASE8.md](docs/PHASE8.md) |
| 9 | Chaos engineering: LitmusChaos (bonus) | ✅ done | `chaos/` see [docs/PHASE9.md](docs/PHASE9.md) |

## Screenshots

Everything below runs live on the EKS cluster, with all UIs served behind a single
shared ALB (Grafana, Prometheus, Alertmanager, and the sample app on one load balancer).

### Distributed tracing (Tempo)

End to end traces from the sample app, exported over OTLP through the OpenTelemetry
Collector into Tempo. Each request span carries its child database `SELECT` span.

![Tempo trace for a backend request, showing the SELECT child span](docs/screenshots/grafana-tempo-trace-backend.png)

### Logs (Loki)

Application and platform logs shipped by Promtail into Loki, explored by namespace.

![Loki logs grouped by namespace: kube-system and sample-app](docs/screenshots/grafana-logs-drilldown-namespaces.png)
![Loki logs grouped by namespace: argocd and logging](docs/screenshots/grafana-logs-drilldown-argocd-logging.png)

### Metrics (Prometheus + Grafana)

Cluster, node, pod, and workload views from kube-state-metrics and node-exporter.

| | |
|---|---|
| ![Cluster compute: CPU](docs/screenshots/grafana-cluster-compute-cpu.png) | ![Cluster compute: memory](docs/screenshots/grafana-cluster-compute-memory.png) |
| ![Cluster compute: network](docs/screenshots/grafana-cluster-compute-network.png) | ![Pod compute: argocd application controller](docs/screenshots/grafana-pod-compute-argocd-controller.png) |
| ![Node compute: CPU](docs/screenshots/grafana-node-compute-cpu.png) | ![Node compute: memory](docs/screenshots/grafana-node-compute-memory.png) |
| ![Workload compute: sample-app CPU](docs/screenshots/grafana-workload-sample-app-cpu.png) | ![Workload compute: sample-app memory](docs/screenshots/grafana-workload-sample-app-memory.png) |

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
  modules/platform/        Reusable Phase 1 module: VPC, EKS, node groups, IRSA, Route53, default StorageClass
  environments/staging/    Composition: SPOT, single NAT, 2 AZ (cost-optimised)
  environments/production/ Composition: ON_DEMAND, NAT per-AZ, 3 AZ (HA)
  shared/                  Account level resources applied once (ECR registry)
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
