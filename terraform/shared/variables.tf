variable "region" {
  description = "AWS region for the shared resources. Must match where the clusters run so nodes can pull images locally."
  type        = string
  default     = "ap-south-1"
}

variable "project" {
  description = "Project prefix. Each ECR repo is named <project>-<service>."
  type        = string
  default     = "platform-obs"
}

variable "services" {
  description = "One ECR repository is created per service in this list."
  type        = list(string)
  default     = ["backend", "frontend"]
}

variable "untagged_expiry_days" {
  description = "Delete untagged images after this many days to keep the registry tidy."
  type        = number
  default     = 14
}
