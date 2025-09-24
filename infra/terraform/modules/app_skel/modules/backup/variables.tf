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

variable "backup_config" {
  description = "Backup configuration"
  type        = any
}

variable "database_id" {
  description = "Database identifier for backup"
  type        = string
  default     = ""
}

variable "storage_buckets" {
  description = "List of storage buckets to backup"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}