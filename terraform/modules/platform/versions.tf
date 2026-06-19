# Provider requirements for the module. NO backend and NO provider blocks here —
# state config and provider credentials are the calling environment's job
# (see environments/*/versions.tf and providers.tf). The module only declares
# what it directly references.
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    # Used only for the default StorageClass (see storage.tf). The provider itself
    # is configured by the calling environment against this module's cluster.
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }
}
