# Terraform configuration for dev platform environment

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
  
  # Optional: Configure remote state
  # backend "s3" {
  #   bucket = "comind-ops-terraform-state"
  #   key    = "dev/platform/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

# Configure providers for local k3d cluster
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "k3d-comind-ops-dev"
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "k3d-comind-ops-dev"
  }
}

# AWS provider (for cloud deployments)
provider "aws" {
  region = var.aws_region
  
  # Skip credentials for local development
  skip_credentials_validation = var.cluster_type == "local"
  skip_requesting_account_id  = var.cluster_type == "local"
  skip_metadata_api_check     = var.cluster_type == "local"
}

# DigitalOcean provider (for cloud deployments)
provider "digitalocean" {
  # Token should be set via DIGITALOCEAN_TOKEN environment variable
}

# Variables for provider configuration
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "cluster_type" {
  description = "Type of cluster (local, aws, digitalocean)"
  type        = string
  default     = "local"
}

# Local values
locals {
  environment = "dev"
  region      = var.aws_region
  
  common_tags = {
    Environment = local.environment
    Project     = "comind-ops"
    ManagedBy   = "terraform"
    Region      = local.region
  }
}
