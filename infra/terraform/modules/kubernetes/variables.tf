variable "cluster_type" {
  description = "Type of cluster (local, aws)"
  type        = string
}

variable "create_namespaces_script" {
  description = "Script to create namespaces"
  type        = string
}
