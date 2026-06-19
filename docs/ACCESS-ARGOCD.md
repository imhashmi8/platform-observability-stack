# Accessing the ArgoCD UI over an ALB

This exposes the ArgoCD UI on an internet-facing ALB locked to a single source
IP, over HTTP. It is demo-grade access (no TLS). For real use, add a domain and
an ACM certificate and switch the listener to HTTPS.

Two pieces are involved:

1. The AWS Load Balancer Controller, deployed by ArgoCD as the
   `aws-load-balancer-controller` Application into `kube-system`, using the IRSA
   role from Phase 1.
2. An Ingress for `argocd-server` that the controller turns into an ALB.

## 1. Confirm the IRSA role ARN

The controller values reference the Phase 1 role. Check it matches:

```bash
terraform -chdir=terraform/environments/staging output -raw aws_lb_controller_irsa_role_arn
```

If it differs from the ARN in `aws-lb-controller/values.yaml`, update the file.

## 2. Deploy the controller

The controller is GitOps-managed, so commit and push, then ArgoCD installs it.

```bash
git add aws-lb-controller argocd/apps/aws-load-balancer-controller.yaml argocd/projects/platform.yaml
git commit -m "feat: install AWS Load Balancer Controller"
git push

# wait until it is running
kubectl -n kube-system rollout status deploy/aws-load-balancer-controller
```

## 3. Create the Ingress with your IP

The Ingress is applied by hand (not auto-synced) so your IP is not committed to
git. Substitute your public IP into the allowlist and apply:

```bash
MYIP=$(curl -s ifconfig.me)
sed "s#REPLACE_WITH_YOUR_IP#${MYIP}#" argocd/ingress/argocd-server.yaml | kubectl apply -f -
```

## 4. Get the ALB address and open it

The controller takes a minute or two to provision the ALB and register targets.

```bash
kubectl -n argocd get ingress argocd-server -w
# when the ADDRESS column shows an *.elb.amazonaws.com name, open it:
#   http://<that-address>
```

Log in as `admin` with the password from:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

## Reaching it from the jumpserver

The ALB allowlist must contain whatever IP the traffic actually comes from. If
you browse from the jumpserver, use the jumpserver's public egress IP for
`MYIP`. If you browse from your laptop, use the laptop's. Add more than one with
a comma separated `inbound-cidrs` if needed.

## Notes

- HTTP only. Anyone within the allowed IP range can read the admin login over
  the wire. Tighten to a single /32 and move to HTTPS before any real exposure.
- Costs: a running ALB is billed per hour plus LCU. Delete the Ingress
  (`kubectl -n argocd delete ingress argocd-server`) when you are done to drop
  the ALB.
- The same controller now serves every other Ingress in the cluster, for example
  the frontend Ingress in `helm/frontend` once you enable it.
