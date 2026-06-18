#!/usr/bin/env bash
# Bootstrap ArgoCD onto the Phase 1 EKS cluster and hand it the app-of-apps root.
# Idempotent: safe to re-run. Requires kubectl pointed at the cluster (see
# `terraform output configure_kubectl`) and helm installed.
set -euo pipefail

ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-7.3.11}" # argo-cd Helm chart (app v2.11.x)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo ">> Installing ArgoCD (chart ${ARGOCD_CHART_VERSION}) into ${ARGOCD_NAMESPACE}"
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo >/dev/null
helm upgrade --install argocd argo/argo-cd \
  --namespace "${ARGOCD_NAMESPACE}" --create-namespace \
  --version "${ARGOCD_CHART_VERSION}" \
  --set configs.params."server\.insecure"=true \
  --wait

echo ">> Registering the platform AppProject"
kubectl apply -f "${REPO_ROOT}/argocd/projects/platform.yaml"

echo ">> Applying the app-of-apps root Application"
kubectl apply -f "${REPO_ROOT}/argocd/bootstrap/root-app.yaml"

echo
echo ">> Done. Initial admin password:"
kubectl -n "${ARGOCD_NAMESPACE}" get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
echo ">> Port-forward the UI with:"
echo "   kubectl -n ${ARGOCD_NAMESPACE} port-forward svc/argocd-server 8080:443"
