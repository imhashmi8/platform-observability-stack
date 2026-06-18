provider "aws" {
  region = local.region

  default_tags {
    tags = {
      Project     = "platform-obs"
      Environment = "staging"
      ManagedBy   = "terraform"
      Stack       = "platform-observability-stack"
    }
  }
}

# kubernetes/helm authenticate against the cluster this environment creates, using
# a short-lived exec token (no static creds in state). Used by the later phases'
# Helm releases; harmless to declare before then.
provider "kubernetes" {
  host                   = module.platform.cluster_endpoint
  cluster_ca_certificate = base64decode(module.platform.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.platform.cluster_name, "--region", local.region]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.platform.cluster_endpoint
    cluster_ca_certificate = base64decode(module.platform.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.platform.cluster_name, "--region", local.region]
    }
  }
}
