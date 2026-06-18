# -----------------------------------------------------------------------------
# IRSA (IAM Roles for Service Accounts)
#
# Each role below is scoped to ONE Kubernetes service account via the cluster's
# OIDC provider — pods assume a role without any node-level AWS credentials.
# These back the controllers the later observability phases install via Helm.
# -----------------------------------------------------------------------------

# EBS CSI driver — provisions the PersistentVolumes used by Prometheus/Loki/Tempo.
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name             = "${local.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.tags
}

# AWS Load Balancer Controller — turns Kubernetes Ingress into ALBs so Grafana
# (Phase 3+) is reachable from outside the cluster.
module "aws_lb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name                              = "${local.cluster_name}-aws-lb-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.tags
}

# external-dns — syncs Ingress/Service hostnames into the Route53 zone below.
# Only created when a domain is configured.
module "external_dns_irsa" {
  count = local.enable_dns ? 1 : 0

  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name                     = "${local.cluster_name}-external-dns"
  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = [local.hosted_zone_arn]

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-dns:external-dns"]
    }
  }

  tags = local.tags
}
