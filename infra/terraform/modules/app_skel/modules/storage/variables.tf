# Storage Module Variables

variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "environment" {
  description = "Environment (dev, stage, prod)"
  type        = string
}

variable "cluster_type" {
  description = "Type of cluster (local, aws, digitalocean)"
  type        = string
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace for the application"
  type        = string
}

variable "storage_config" {
  description = "Storage configuration"
  type        = any
}

variable "storage_buckets" {
  description = "List of storage buckets to create"
  type = list(object({
    name   = string
    config = object({
      versioning_enabled   = bool
      lifecycle_enabled    = bool
      lifecycle_expiration = number
      cors_enabled         = bool
      public_read          = bool
    })
  }))
  default = []
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

# DigitalOcean-specific variables
variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "nyc1"
}
