# Variables for local environment

variable "cluster_type" {
  description = "Type of cluster (local, aws, ci)"
  type        = string
  default     = "local"
}

variable "cluster_name" {
  description = "Name of the k3d cluster"
  type        = string
  default     = "comind-ops-dev"
}

variable "cluster_port" {
  description = "Port to expose the cluster API"
  type        = number
  default     = 6443
}

variable "ingress_http_port" {
  description = "HTTP port for ingress"
  type        = number
  default     = 8080
}

variable "ingress_https_port" {
  description = "HTTPS port for ingress"
  type        = number
  default     = 8443
}

variable "registry_port" {
  description = "Port for local docker registry (not used in k3d setup)"
  type        = number
  default     = 5000
}

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
  default     = "dev"
}
