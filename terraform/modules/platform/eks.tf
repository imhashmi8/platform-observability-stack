module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.8"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  cluster_endpoint_private_access      = true

  # Creates the IAM OIDC provider used by IRSA (see irsa.tf). Default true on v20,
  # set explicitly so the intent is obvious.
  enable_irsa = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Core add-ons managed by EKS. coredns waits until nodes exist.
  cluster_addons = {
    coredns = {
      most_recent = true
      configuration_values = jsonencode({
        tolerations = []
      })
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent    = true
      before_compute = true
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
  }

  # Amazon Linux 2023. The older AL2 EKS AMIs are only published up to Kubernetes
  # 1.32, so AL2023 is required from 1.33 onward.
  eks_managed_node_group_defaults = {
    ami_type = "AL2023_x86_64_STANDARD"
  }

  eks_managed_node_groups = {
    general = {
      instance_types = var.node_instance_types
      capacity_type  = var.node_capacity_type

      # When single_az_node_group is set, restrict the node group to the first
      # private subnet (one AZ). EBS volumes are AZ-locked, so keeping every node
      # in one AZ stops stateful pods from being stranded when SPOT capacity moves
      # nodes between AZs. The cluster itself still spans all AZs. Leave it off for
      # production, where you want nodes spread for availability.
      subnet_ids = var.single_az_node_group ? slice(module.vpc.private_subnets, 0, 1) : module.vpc.private_subnets

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      labels = {
        role = "general"
      }

      # 50Gi gp3 root volume — Prometheus/Loki/Tempo are disk-hungry.
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      tags = local.tags
    }
  }

  # Lets the identity running `terraform apply` administer the cluster via the
  # new EKS access-entry API (replaces the old aws-auth configmap dance).
  enable_cluster_creator_admin_permissions = true

  tags = local.tags
}
