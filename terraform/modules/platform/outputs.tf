output "region" {
  description = "AWS region the stack is deployed in."
  value       = var.region
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 CA cert for the API server — used to configure the kubernetes/helm providers."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_version" {
  description = "Running Kubernetes control-plane version."
  value       = module.eks.cluster_version
}

output "cluster_security_group_id" {
  description = "Security group attached to the EKS control plane."
  value       = module.eks.cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN — used to wire additional IRSA roles."
  value       = module.eks.oidc_provider_arn
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "public_subnet_ids" {
  value = module.vpc.public_subnets
}

# IRSA role ARNs — feed these into the Helm values for each controller.
output "ebs_csi_irsa_role_arn" {
  value = module.ebs_csi_irsa.iam_role_arn
}

output "aws_lb_controller_irsa_role_arn" {
  value = module.aws_lb_controller_irsa.iam_role_arn
}

output "external_dns_irsa_role_arn" {
  description = "external-dns IRSA role ARN (null when no domain is configured)."
  value       = local.enable_dns ? module.external_dns_irsa[0].iam_role_arn : null
}

output "route53_zone_id" {
  description = "Hosted zone id for the platform domain (null when no domain configured)."
  value       = local.hosted_zone_id
}

output "route53_name_servers" {
  description = "Delegate your domain to these NS records at your registrar (only when a new zone is created)."
  value       = local.hosted_zone_name_servers
}

output "configure_kubectl" {
  description = "Run this to point kubectl at the new cluster."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}
