# Phase 2: Sample Application + GitOps

A three-tier sample app (React → FastAPI → Postgres), packaged as Helm charts and
delivered to the Phase 1 EKS cluster by ArgoCD using the **app-of-apps** pattern.

```
            ┌───────────┐      /api      ┌──────────┐      SQL      ┌──────────┐
  user ───▶ │ frontend  │ ─────────────▶ │ backend  │ ────────────▶│ postgres │
            │ (nginx)   │                │ (FastAPI)│              │ (StatefulSet)
            └───────────┘                └──────────┘              └──────────┘
                                              │ /metrics  /healthz  /readyz
                                              ▼
                                   (Prometheus scrapes in Phase 3)
```

## Layout

| Path | What |
|------|------|
| `app/backend/` | FastAPI source + Dockerfile. RED metrics, items API, health/readiness, OTel hooks. |
| `app/frontend/` | React (Vite) SPA + nginx Dockerfile that proxies `/api` to the backend. |
| `helm/postgres/` | Single-instance Postgres StatefulSet + credentials Secret. |
| `helm/backend/` | Backend Deployment, Service, HPA, ServiceMonitor (gated for Phase 3). |
| `helm/frontend/` | Frontend Deployment, Service, optional ALB Ingress. |
| `argocd/projects/` | `platform` AppProject (scopes repos + namespaces). |
| `argocd/bootstrap/` | Root app-of-apps Application + `bootstrap.sh`. |
| `argocd/apps/` | One child Application per chart, ordered with sync-waves. |

## Why this matters (the recruiter line)

> I built a GitOps-managed platform: every workload is a Helm chart, ArgoCD
> continuously reconciles the cluster to git, and the app emits the RED metrics,
> health probes, and trace hooks the observability stack is built on.

## Prerequisites

- Phase 1 applied (`terraform apply` in `terraform/environments/<env>`) and kubectl configured:
  ```bash
  cd terraform/environments/staging   # or production
  aws eks update-kubeconfig --region "$(terraform output -raw region)" \
    --name "$(terraform output -raw cluster_name)"
  ```
- A container registry you can push to (ECR, GHCR, Docker Hub).
- `helm`, `kubectl`, `docker` installed.

## 1. Create the registry and push the images

The ECR repositories are managed by Terraform in `terraform/shared` (applied once,
separate from the per environment clusters). The Helm values already point
`image.repository` at these repos.

```bash
# Create the ECR repos (once)
cd terraform/shared
terraform init && terraform apply
eval "$(terraform output -raw docker_login)"   # authenticate Docker to ECR
REGISTRY="$(terraform output -raw registry)"
cd ../..

export TAG=0.1.0

# Build for linux/amd64 (the nodes are x86_64; required when building on Apple Silicon)
docker buildx build --platform linux/amd64 -t $REGISTRY/platform-obs-backend:$TAG  --push app/backend
docker buildx build --platform linux/amd64 -t $REGISTRY/platform-obs-frontend:$TAG --push app/frontend
```

> EKS nodes can pull from ECR in the same account with no image pull secret, because
> the managed node group role already has `AmazonEC2ContainerRegistryReadOnly`.

## 2. Point the manifests at YOUR git repo

Every ArgoCD `Application` and the `AppProject` reference
`https://github.com/OWNER/platform-observability-stack.git`. Replace `OWNER` with
your fork across `argocd/**` and commit/push, since ArgoCD reads charts from git, not
from your laptop.

```bash
grep -rl 'OWNER' argocd helm   # find every placeholder to replace
```

## 3. Set a real DB password

`helm/postgres/values.yaml` ships `auth.password: changeme-dev-only`. For anything
beyond a throwaway cluster, inject it out-of-band (sealed-secrets / SOPS / an
externally-created `postgres-credentials` Secret) rather than committing it.

## 4. Bootstrap ArgoCD + the app

```bash
./argocd/bootstrap/bootstrap.sh
```

This installs ArgoCD (Helm), registers the `platform` project, and applies the
root app-of-apps. ArgoCD then syncs, in order:

1. **wave 0**: postgres (creates the DB + `postgres-credentials` Secret)
2. **wave 1**: backend
3. **wave 2**: frontend

Watch it converge:

```bash
kubectl -n argocd get applications -w
kubectl -n sample-app get pods
```

## 5. Reach the app

Without an Ingress (default), port-forward:

```bash
kubectl -n sample-app port-forward svc/frontend 8088:80
# open http://localhost:8088, add items, they persist in Postgres
```

To expose it publicly, set `ingress.enabled=true` (and `ingress.host`) in
`helm/frontend/values.yaml` once Phase 1's AWS Load Balancer Controller and
external-dns are running.

## Verify the observability surface (feeds later phases)

```bash
kubectl -n sample-app port-forward svc/backend 8000:8000
curl localhost:8000/healthz   # liveness
curl localhost:8000/readyz    # readiness (checks Postgres)
curl localhost:8000/metrics   # Prometheus exposition, http_requests_total, etc.
```

## Local dev (no cluster)

```bash
# backend
cd app/backend && pip install -r requirements.txt
DB_HOST=localhost uvicorn app.main:app --reload   # needs a local postgres

# frontend (proxies /api to localhost:8000)
cd app/frontend && npm install && npm run dev
```

## What's deliberately left for later phases

- **ServiceMonitor** is gated behind `metrics.serviceMonitor.enabled` until Phase 3
  installs the Prometheus Operator CRDs.
- **OTel export** is a no-op until Phase 5 sets `otel.endpoint` to the collector.
- Postgres is single-instance/dev-grade, so swap for an operator or RDS for prod.
