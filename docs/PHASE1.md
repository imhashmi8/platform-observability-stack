# Terraform: Phase 1 platform foundation

Reusable module + per-environment compositions.

```
modules/platform/        # one source of truth: VPC, EKS, node groups, IRSA, Route53
environments/
  staging/               # SPOT · single NAT · 2 AZ · t3.large   (cost-optimised)
  production/            # ON_DEMAND · NAT/AZ · 3 AZ · m5.large   (HA)
```

The environments are thin: each is a `module "platform"` call plus its own
providers, backend (state), and output re-exports. All infrastructure lives in
the module. Diff `environments/staging/main.tf` against `production/main.tf` to
see exactly what changes between tiers.

## Usage

```bash
cd environments/staging          # or production
terraform init
terraform plan
terraform apply
```

State is **per environment**. Copy `backend.tf.example` to `backend.tf` in each
env (the S3 `key` differs) and `terraform init -migrate-state`. Staging and
production never share a state file.

## Adding another environment (e.g. `dev`)

1. `cp -r environments/staging environments/dev`
2. In `dev/main.tf`: set `environment = "dev"`, a non-overlapping `vpc_cidr`, and
   sizing.
3. In `dev/providers.tf`: set the `Environment` default tag to `dev`.
4. In `dev/backend.tf.example`: change the state `key` to `.../dev/terraform.tfstate`.

## Module inputs

See [`modules/platform/variables.tf`](modules/platform/variables.tf) for the full,
documented list (region, networking, EKS sizing, capacity type, DNS). Outputs
(cluster name/endpoint, IRSA role ARNs, Route53 name servers, a ready-made
`aws eks update-kubeconfig` command) are in
[`modules/platform/outputs.tf`](modules/platform/outputs.tf).
