# Re-export the module outputs so `terraform output -raw <name>` works at the
# environment level (used by the docs' kubectl/ArgoCD bootstrap commands).
output "region" {
  value = module.platform.region
}

output "cluster_name" {
  value = module.platform.cluster_name
}

output "cluster_endpoint" {
  value = module.platform.cluster_endpoint
}

output "oidc_provider_arn" {
  value = module.platform.oidc_provider_arn
}

output "vpc_id" {
  value = module.platform.vpc_id
}

output "ebs_csi_irsa_role_arn" {
  value = module.platform.ebs_csi_irsa_role_arn
}

output "aws_lb_controller_irsa_role_arn" {
  value = module.platform.aws_lb_controller_irsa_role_arn
}

output "external_dns_irsa_role_arn" {
  value = module.platform.external_dns_irsa_role_arn
}

output "route53_name_servers" {
  description = "Delegate your domain to these NS records (only when a new zone is created)."
  value       = module.platform.route53_name_servers
}

output "configure_kubectl" {
  value = module.platform.configure_kubectl
}
