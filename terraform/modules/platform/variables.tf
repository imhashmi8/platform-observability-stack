variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-south-1"
}

variable "project" {
  description = "Project name, used as a prefix and tag across all resources."
  type        = string
  default     = "platform-obs"
}

variable "environment" {
  description = "Deployment environment (dev | staging | prod)."
  type        = string
  default     = "dev"
}

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to spread subnets across (min 2 for EKS HA)."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2
    error_message = "EKS requires subnets in at least 2 Availability Zones."
  }
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway (cheap, for dev) instead of one per AZ (HA, for prod)."
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# EKS
# -----------------------------------------------------------------------------
variable "cluster_version" {
  description = "Kubernetes control-plane version."
  type        = string
  default     = "1.34"
}

variable "cluster_endpoint_public_access" {
  description = "Expose the API server endpoint publicly. Lock to your IP via cluster_endpoint_public_access_cidrs."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint. DEFAULT IS OPEN — restrict to your /32 for anything real."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_instance_types" {
  description = "Instance types for the managed node group."
  type        = list(string)
  default     = ["t3.large"]
}

variable "node_capacity_type" {
  description = "ON_DEMAND or SPOT. SPOT is far cheaper for non-prod observability workloads."
  type        = string
  default     = "SPOT"
}

variable "single_az_node_group" {
  description = "Pin the managed node group to a single AZ (the first private subnet) to avoid EBS volume AZ-affinity problems under SPOT churn. Leave false for production HA."
  type        = bool
  default     = false
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 5
}

variable "node_desired_size" {
  type    = number
  default = 3
}

# -----------------------------------------------------------------------------
# DNS
# -----------------------------------------------------------------------------
variable "domain_name" {
  description = "Public hosted-zone domain (e.g. obs.example.com). Leave empty to skip Route53 + external-dns IRSA."
  type        = string
  default     = ""
}

variable "create_route53_zone" {
  description = "Create a new public hosted zone for domain_name. Set false if the zone already exists."
  type        = bool
  default     = true
}
