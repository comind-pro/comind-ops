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

variable "queue_config" {
  description = "Queue configuration"
  type        = any
}

variable "queue_names" {
  description = "List of queue configurations"
  type        = list(any)
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}