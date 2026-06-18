# Phase 3: Metrics

Deploys the metrics layer with the kube-prometheus-stack Helm chart, delivered
through the same ArgoCD GitOps flow as the sample app. One release brings up the
Prometheus Operator, Prometheus, Alertmanager, Grafana, node-exporter and
kube-state-metrics in the `monitoring` namespace.

```
 node-exporter        kube-state-metrics        backend /metrics
 (CPU, memory,        (deployments, pods,        (request count,
  disk, network)       restarts, replicas)        latency, errors)
        \                    |                          /
         \                   |                         /
                       Prometheus  (scrape + store, 15d)
                             |
                          Grafana
```

## What lives where

| Path | Purpose |
|------|---------|
| `prometheus/values.yaml` | kube-prometheus-stack configuration |
| `argocd/apps/kube-prometheus-stack.yaml` | ArgoCD Application (multi source: chart from the Helm repo, values from this git repo) |
| `helm/backend/templates/servicemonitor.yaml` | ServiceMonitor for the backend, now enabled in `helm/backend/values.yaml` |
| `argocd/projects/platform.yaml` | Updated to allow the `monitoring` namespace and cluster scoped resources |

## How it is wired

The Application uses two sources. The chart comes from the prometheus-community
Helm repo, and the values file comes from this repo through the `$values`
reference. This keeps the configuration in git while still pulling the upstream
chart directly.

It runs at sync wave `-5`, ahead of the sample app (waves 0 to 2). That ordering
guarantees the ServiceMonitor CRD exists before the backend chart tries to create
its ServiceMonitor.

Prometheus is configured to discover every ServiceMonitor, PodMonitor and
PrometheusRule in the cluster regardless of labels or namespace
(`serviceMonitorSelectorNilUsesHelmValues: false` and the matching namespace
selectors). That is why the backend ServiceMonitor in the `sample-app` namespace
is picked up automatically.

## EKS specifics

The managed control plane does not expose kube-controller-manager,
kube-scheduler, etcd or kube-proxy for scraping, so those scrape jobs are turned
off in the values to avoid permanently down targets.

Server side apply is enabled on the Application because the Prometheus CRDs are
too large for the client side apply annotation.

## Deploy

If ArgoCD is already running from Phase 2, just commit and push. The root
app-of-apps picks up the new Application and syncs it. Otherwise run the Phase 2
bootstrap first.

```bash
git add prometheus argocd helm
git commit -m "phase 3: metrics"
git push

kubectl -n argocd get applications
kubectl -n monitoring get pods
```

## Access the UIs

```bash
# Grafana (default user admin, password from prometheus/values.yaml)
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
# open http://localhost:3000

# Prometheus
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
# open http://localhost:9090/targets to confirm the backend target is UP
```

## Verify the signals from the roadmap

Generate some traffic against the backend first (see Phase 2 for port-forward),
then try these in Prometheus or a Grafana panel.

```promql
# Request rate per second by path
sum(rate(http_requests_total[5m])) by (path)

# 95th percentile latency
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

# Error rate (5xx share of all requests)
sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))

# Custom business metric
items_created_total

# CPU and memory per pod (from kube-state-metrics and the kubelet)
sum(rate(container_cpu_usage_seconds_total{namespace="sample-app"}[5m])) by (pod)
sum(container_memory_working_set_bytes{namespace="sample-app"}) by (pod)
```

These same queries feed the SLI and SLO work in Phase 6 and the burn rate alerts
in Phase 8.

## Left for later phases

The bundled Grafana and Alertmanager are reused later. Phase 4 adds the Loki
data source, Phase 5 adds Tempo, Phase 6 adds SLO dashboards and recording rules,
and Phase 8 configures the Alertmanager routes and the Slack receiver.

Set a real Grafana admin password through a secret you manage out of band before
exposing this beyond a demo cluster.
