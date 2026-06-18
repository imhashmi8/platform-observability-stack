# Shared, account level resources. Right now this is the ECR registry that holds
# the application images. It is applied once and is independent of any single
# environment, so staging and production pull the same images.

data "aws_caller_identity" "current" {}

locals {
  # backend -> platform-obs-backend, frontend -> platform-obs-frontend
  repositories = { for s in var.services : s => "${var.project}-${s}" }

  registry = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
}

resource "aws_ecr_repository" "this" {
  for_each = local.repositories

  name = each.value

  # MUTABLE so a tag like 0.1.0 can be re-pushed during development. Switch to
  # IMMUTABLE once you adopt unique tags per build for stricter provenance.
  image_tag_mutability = "MUTABLE"

  # Allow `terraform destroy` to remove the repo even if images remain.
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after ${var.untagged_expiry_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_expiry_days
        }
        action = { type = "expire" }
      }
    ]
  })
}
