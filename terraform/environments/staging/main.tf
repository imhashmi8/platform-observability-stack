# -----------------------------------------------------------------------------
# Staging environment.
#
# Thin composition: it just calls the platform module with cost-optimised,
# non-HA settings. Everything that actually creates infrastructure lives in
# ../../modules/platform — this file only encodes "what staging is".
# -----------------------------------------------------------------------------
locals {
  region = "ap-south-1"
}

module "platform" {
  source = "../../modules/platform"

  region      = local.region
  project     = "platform-obs"
  environment = "staging"

  # --- Networking: cheap, single point of failure is acceptable in staging ---
  vpc_cidr           = "10.10.0.0/16"
  az_count           = 2
  single_nat_gateway = true

  # --- EKS: SPOT + smaller footprint to keep the bill down ---
  cluster_version     = "1.34"
  node_instance_types = ["t3.large"]
  node_capacity_type  = "SPOT"
  node_min_size       = 2
  node_max_size       = 4
  node_desired_size   = 2

  # Open API endpoint is fine for a throwaway staging cluster; lock to your /32
  # if it lives longer than a demo.
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

  # --- DNS (optional): set a subdomain to enable Route53 + external-dns IRSA ---
  domain_name         = ""
  create_route53_zone = true
}
