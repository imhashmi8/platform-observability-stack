output "registry" {
  description = "ECR registry host. Pass to docker login."
  value       = local.registry
}

output "repository_urls" {
  description = "Map of service to full ECR repository URL. Use these as image.repository in the Helm values."
  value       = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}

output "docker_login" {
  description = "Ready to run command to authenticate Docker to this registry."
  value       = "aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${local.registry}"
}
