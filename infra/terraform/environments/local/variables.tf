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

# AWS-specific variables (for compatibility with main.tf)
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-west-2"
}

variable "eks_cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.28"
}

variable "eks_node_instance_type" {
  description = "Instance type for EKS worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "eks_node_desired_size" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 2
}

variable "eks_node_max_size" {
  description = "Maximum number of EKS worker nodes"
  type        = number
  default     = 4
}

variable "eks_node_min_size" {
  description = "Minimum number of EKS worker nodes"
  type        = number
  default     = 1
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}
