# Phase 4: Logging

Adds the logs pillar with Loki and Promtail, delivered through the same ArgoCD
GitOps flow. Promtail tails every pod's logs on each node and ships them to Loki,
and Loki is wired into the Grafana from Phase 3 as a data source so logs and
metrics live in one place.

```
 every node:  Promtail (DaemonSet)  tails /var/log/pods, adds k8s labels
                       |
                       v
                  Loki (SingleBinary + filesystem PV)
                       |
                       v
                  Grafana  (Explore, query with LogQL)
```

## What lives where

| Path | Purpose |
|------|---------|
| `loki/loki-values.yaml` | Loki chart values, SingleBinary mode with a filesystem PV |
| `loki/promtail-values.yaml` | Promtail chart values, points the client at the Loki gateway |
| `grafana/datasources/loki.yaml` | ConfigMap that provisions the Loki data source in Grafana |
| `argocd/apps/loki.yaml` | ArgoCD Application for Loki (chart from grafana repo, values from this repo) |
| `argocd/apps/promtail.yaml` | ArgoCD Application for Promtail |
| `argocd/apps/grafana-datasources.yaml` | ArgoCD Application that applies everything in `grafana/datasources/` |

Loki and Promtail run in a new `logging` namespace. The data source ConfigMap
goes to the `monitoring` namespace next to Grafana.

## How it is wired

Loki runs in SingleBinary mode with tsdb on a filesystem volume. That is the
simplest topology that still uses real persistence. SchemaConfig is set
explicitly because the chart requires it, and the memcached caches that the chart
enables by default are turned off because they request several GB of memory each,
which is too heavy for a single binary demo.

Promtail uses the chart's default pod discovery, so it picks up application logs
(for example the sample-app backend) and the logs of any ingress controller pods
with no extra configuration. The only override is the client URL pointing at
`loki-gateway` in the logging namespace.

The Loki data source is provisioned the same way as everything else: a ConfigMap
labelled `grafana_datasource` that the Grafana sidecar from Phase 3 picks up
automatically. No manual UI step and no Grafana restart.

The `grafana-datasources` Application points at the `grafana/datasources`
directory, so Phase 5 can drop a Tempo data source into the same folder and it
gets applied automatically.

## Deploy

If ArgoCD is already running, commit and push and the root app-of-apps syncs the
new Applications.

```bash
git add loki grafana argocd
git commit -m "phase 4: logging"
git push

kubectl -n argocd get applications
kubectl -n logging get pods
```

## Query logs in Grafana

Open Grafana (see Phase 3 for the port-forward), go to Explore, and pick the Loki
data source. Some starting queries with LogQL:

```logql
# All backend logs
{namespace="sample-app", app="backend"}

# Only errors and warnings, matching the roadmap search examples
{namespace="sample-app"} |= "ERROR"
{namespace="sample-app"} |~ "ERROR|WARN"

# Logs for a specific service by name
{namespace="sample-app", app="backend"} |= "payment"

# Request rate of log lines per pod
sum(rate({namespace="sample-app"}[5m])) by (pod)
```

Generate some backend traffic first (see Phase 2) so there are logs to search.

## Kubernetes events

Promtail collects pod logs, which covers application and ingress logs. Cluster
events (the output of `kubectl get events`) are not pod logs, so they are not
captured by this setup. The usual way to get them into Loki is to deploy
kubernetes-event-exporter, which writes events to stdout where Promtail then picks
them up. That can be added as a small follow-on if you want events in Grafana too.

## Production notes

The filesystem backend keeps everything on one PVC, which is fine for a demo but
does not survive the pod's node being lost and does not scale. For production,
switch Loki to SimpleScalable or Distributed mode backed by an S3 bucket, using an
IRSA role from Phase 1 for access. Also set a real retention and sizing policy;
this config keeps 7 days.
