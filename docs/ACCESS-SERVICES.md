# Exposing the platform UIs on one shared ALB

Puts Grafana, Prometheus, Alertmanager, and the frontend app on a **single** ALB
using the AWS Load Balancer Controller IngressGroup feature, routed by path:

```
http://<alb>/grafana       Grafana       (has login)
http://<alb>/prometheus    Prometheus    (no auth)
http://<alb>/alertmanager  Alertmanager  (no auth)
http://<alb>/              frontend app
```

Internet-facing, HTTP only, locked to your IP. Prometheus and Alertmanager have
no authentication, so the IP allowlist is the only thing guarding them.

ArgoCD stays on its own separate ALB (already working); these four share a second
ALB named `platform`.

## Why the values change is needed

Path-based routing means each backend UI must serve under its sub-path, because
the ALB forwards the path as-is (it does not strip the prefix). So
`prometheus/values.yaml` now sets:

- Grafana: `serve_from_sub_path: true` and `root_url` ending in `/grafana`
- Prometheus: `routePrefix: /prometheus`
- Alertmanager: `routePrefix: /alertmanager`

The frontend serves at `/`, so it needs no change.

## Deploy

Order matters: reconfigure the UIs for their sub-paths first, then create the ALB.

```bash
# 1. Commit and push the sub-path config; ArgoCD reconfigures the monitoring UIs
git add prometheus/values.yaml ingress/platform-ingress.yaml docs/ACCESS-SERVICES.md
git commit -m "feat: expose platform UIs on a shared ALB"
git push

# 2. Wait for kube-prometheus-stack to re-sync (Prometheus and Grafana restart)
kubectl -n argocd patch app kube-prometheus-stack --type merge -p '{"operation":{"sync":{}}}'
kubectl -n monitoring rollout status deploy/kube-prometheus-stack-grafana

# 3. Create the shared ALB by applying the Ingresses with your IP
MYIP=$(curl -s ifconfig.me)
sed "s#REPLACE_WITH_YOUR_IP#${MYIP}#" ingress/platform-ingress.yaml | kubectl apply -f -

# 4. Wait for the ALB address (any of the four Ingresses shows the same one)
kubectl -n monitoring get ingress -w
```

## Access

Once the ALB address appears (`platform-xxxx.ap-south-1.elb.amazonaws.com`):

- `http://<alb>/grafana` (admin, password from the grafana secret)
- `http://<alb>/prometheus`
- `http://<alb>/alertmanager`
- `http://<alb>/` (the sample app)

## If a path 503s or targets are unhealthy

Each Ingress sets its own `healthcheck-path`. If a target group shows unhealthy:

- Grafana: `/grafana/api/health`
- Prometheus: `/prometheus/-/healthy`
- Alertmanager: `/alertmanager/-/healthy`
- Frontend: `/healthz`

Confirm the app actually serves that path (for example the routePrefix took
effect) and adjust the annotation if needed.

## Notes

- One ALB for all four keeps cost down versus one ALB per service.
- The IP allowlist must match where your browser traffic originates. If your
  egress is IPv6, the IPv4 `/32` will not match; force IPv4 or add your IPv6 `/128`.
- Tear down with `kubectl delete -f <(sed ... ingress/platform-ingress.yaml)` to
  drop the ALB when you are done.
