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

variable "metallb_ip_range" {
  description = "IP range for MetalLB load balancer"
  type        = string
  default     = "172.20.0.100-172.20.0.200"
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

# Multi-environment configuration
variable "multi_environment" {
  description = "Enable multiple environments in single cluster"
  type        = bool
  default     = false
}

variable "namespace_prefix" {
  description = "Namespace prefix for environments"
  type        = string
  default     = "platform"
}

variable "domain_suffix" {
  description = "Domain suffix for local environments"
  type        = string
  default     = "127.0.0.1.nip.io"
}

# Environment-specific configurations
variable "environments" {
  description = "List of environments to deploy (comma-separated string or list)"
  type        = any
  default     = ["dev"]
  
  validation {
    condition = can(tolist(var.environments)) || can(split(",", var.environments))
    error_message = "Environments must be a list of strings or a comma-separated string."
  }
}

variable "environment_configs" {
  description = "Environment-specific configurations"
  type = map(object({
    namespace = string
    domain    = string
    replicas  = number
    resources = object({
      limits = object({
        cpu    = string
        memory = string
      })
      requests = object({
        cpu    = string
        memory = string
      })
    })
  }))
  default = {
    dev = {
      namespace = "platform-dev"
      domain    = "dev.127.0.0.1.nip.io"
      replicas  = 1
      resources = {
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }
    }
    stage = {
      namespace = "platform-stage"
      domain    = "stage.127.0.0.1.nip.io"
      replicas  = 2
      resources = {
        limits = {
          cpu    = "1000m"
          memory = "1Gi"
        }
        requests = {
          cpu    = "200m"
          memory = "256Mi"
        }
      }
    }
    qa = {
      namespace = "platform-qa"
      domain    = "qa.127.0.0.1.nip.io"
      replicas  = 2
      resources = {
        limits = {
          cpu    = "1000m"
          memory = "1Gi"
        }
        requests = {
          cpu    = "200m"
          memory = "256Mi"
        }
      }
    }
    prod = {
      namespace = "platform-prod"
      domain    = "prod.127.0.0.1.nip.io"
      replicas  = 3
      resources = {
        limits = {
          cpu    = "2000m"
          memory = "2Gi"
        }
        requests = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }
    }
  }
}
