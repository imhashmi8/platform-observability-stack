provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
      Stack     = "platform-observability-stack"
      Scope     = "shared"
    }
  }
}
