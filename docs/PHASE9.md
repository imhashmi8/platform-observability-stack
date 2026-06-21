# Phase 9: Chaos engineering (bonus)

Injects controlled failure with LitmusChaos to prove the platform behaves the way
the earlier phases claim: the app recovers, the SLO dashboard reacts, and the
burn rate alerts stay quiet for a blast radius inside the error budget.

## The experiment

A `pod-delete` experiment kills 50 percent of the backend pods for 60 seconds.
Because the backend runs 2+ replicas behind a Service with an HPA, Kubernetes
reschedules the killed pods and traffic shifts to the survivors, so user impact
should be small. That is the hypothesis the experiment tests.

## What lives where

| Path | Purpose |
|------|---------|
| `chaos/rbac.yaml` | ServiceAccount + namespaced Role + binding for the experiment |
| `chaos/pod-delete-experiment.yaml` | The pod-delete ChaosExperiment definition (vendored from the ChaosHub) |
| `chaos/chaosengine-backend.yaml` | ChaosEngine that runs pod-delete against the backend |

These are deliberately **not** under `argocd/apps/`: a ChaosEngine triggers a run
the moment it is applied, and GitOps self-heal would re-trigger it endlessly. Run
chaos by hand, on purpose.

## Prerequisite: install the Litmus operator

The experiment needs the LitmusChaos operator and CRDs. Install the operator only
(no ChaosCenter portal, which is heavy for a small cluster):

```bash
kubectl apply -f https://litmuschaos.github.io/litmus/litmus-operator-v3.0.0.yaml
kubectl -n litmus get pods   # wait for chaos-operator-ce to be Running
```

## Run it

```bash
# RBAC + experiment definition (safe to leave applied)
kubectl apply -f chaos/rbac.yaml
kubectl apply -f chaos/pod-delete-experiment.yaml

# Trigger the chaos run
kubectl apply -f chaos/chaosengine-backend.yaml
```

## Observe

While it runs, in three places:

```bash
# Pods getting killed and rescheduled
kubectl -n sample-app get pods -l app.kubernetes.io/name=backend -w

# The verdict (Pass means the app stayed healthy through the chaos)
kubectl -n sample-app get chaosresult backend-pod-delete-pod-delete -o jsonpath='{.status.experimentStatus.verdict}'
```

In Grafana, watch the **Backend SLO** and **Backend Error Budget** dashboards: a
small dip in availability is expected, but it should stay well inside the budget,
so the Phase 8 burn rate alerts should not fire for a healthy app. If they do, the
replica count or readiness probes need tuning, which is exactly what the test is
for.

## Clean up

```bash
kubectl delete -f chaos/chaosengine-backend.yaml
# leave rbac.yaml and the experiment applied for the next run, or remove them too
```

## Wrap up

That closes the loop: signals are collected (Phases 3-5), turned into SLOs and
budgets (Phases 6-7), alerted on by burn rate (Phase 8), and validated by
injecting real failure (Phase 9).
