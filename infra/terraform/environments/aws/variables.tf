# Variables for AWS environment

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "comind-ops-dev"
}

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
  default     = "dev"
}

# AWS-specific variables
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

variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}

# Repository configuration
variable "repo_url" {
  description = "Repository URL (supports both private and public)"
  type        = string
  default     = "https://github.com/comind-pro/comind-ops"
}

variable "repo_type" {
  description = "Repository type: 'public' or 'private'"
  type        = string
  default     = "public"
  validation {
    condition     = contains(["public", "private"], var.repo_type)
    error_message = "Repository type must be 'public' or 'private'."
  }
}

# GitHub credentials for private repository access
variable "github_username" {
  description = "GitHub username for private repository access"
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_token" {
  description = "GitHub personal access token for private repository access"
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_ssh_private_key" {
  description = "GitHub SSH private key for repository access"
  type        = string
  default     = ""
  sensitive   = true
}
