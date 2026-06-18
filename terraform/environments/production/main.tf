# -----------------------------------------------------------------------------
# Production environment.
#
# Same platform module as staging, composed for high availability and
# reliability: 3 AZs, one NAT gateway per AZ, on-demand capacity, and a larger
# node group. Diffing this file against staging/main.tf shows exactly what
# "production-grade" changes.
# -----------------------------------------------------------------------------
locals {
  region = "ap-south-1"
}

module "platform" {
  source = "../../modules/platform"

  region      = local.region
  project     = "platform-obs"
  environment = "production"

  # --- Networking: HA. One NAT per AZ removes the single point of failure. ---
  vpc_cidr           = "10.20.0.0/16"
  az_count           = 3
  single_nat_gateway = false

  # --- EKS: on-demand for predictable capacity, larger + more nodes ---
  cluster_version     = "1.34"
  node_instance_types = ["m5.large"]
  node_capacity_type  = "ON_DEMAND"
  node_min_size       = 3
  node_max_size       = 8
  node_desired_size   = 3

  # Do NOT leave the API endpoint open in production. Replace with your office /
  # VPN / CI egress CIDRs before applying.
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = ["203.0.113.0/24"] # <-- REPLACE ME

  # --- DNS: production almost certainly has a real domain ---
  domain_name         = "" # e.g. "obs.example.com"
  create_route53_zone = true
}
