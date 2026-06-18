terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }

  # Shared resources get their own state, separate from every environment.
  # Copy backend.tf.example to backend.tf and run init -migrate-state to use S3.
  # backend "s3" {}
}
