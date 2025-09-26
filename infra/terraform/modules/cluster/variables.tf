variable "cluster_type" {
  description = "Type of cluster (local, aws)"
  type        = string
}

variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
}

variable "create_cluster_script" {
  description = "Script to create the cluster"
  type        = string
}
