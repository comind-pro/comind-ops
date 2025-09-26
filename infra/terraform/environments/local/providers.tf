terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
  }
}

# Providers
provider "docker" {}

provider "aws" {
  region = var.aws_region
  
  # Skip all AWS provider configuration when using local profile
  skip_credentials_validation = var.cluster_type == "local"
  skip_metadata_api_check    = var.cluster_type == "local"
  skip_region_validation     = var.cluster_type == "local"
  skip_requesting_account_id  = var.cluster_type == "local"
  
  # Use mock credentials for local development to avoid AWS calls
  # In production, use environment variables or AWS profiles
  access_key = var.cluster_type == "local" ? "mock" : null
  secret_key = var.cluster_type == "local" ? "mock" : null
}

# Note: Kubernetes and Helm providers are not used in local environment
# All Kubernetes resources are managed via kubectl and helm CLI commands
