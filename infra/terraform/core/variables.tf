# Variables for core infrastructure

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
  description = "Port for local docker registry"
  type        = number
  default     = 5000
}

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
  default     = "dev"
}

variable "cluster_type" {
  description = "Type of cluster deployment (local, aws, digitalocean)"
  type        = string
  default     = "local"
  validation {
    condition     = contains(["local", "aws", "digitalocean"], var.cluster_type)
    error_message = "Cluster type must be one of: local, aws, digitalocean."
  }
}
