variable "app_name" {
  description = "Application name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cluster_type" {
  description = "Cluster type (local, aws, digitalocean)"
  type        = string
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "monitoring_config" {
  description = "Monitoring configuration"
  type        = any
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}