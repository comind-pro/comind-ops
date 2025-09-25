terraform {
  required_version = ">= 1.0"
  required_providers {
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

# Configure providers to use k3d cluster
# Use empty configuration during initial bootstrap - resources will be created via local-exec
provider "kubernetes" {
  config_path    = null
  config_context = null
}

provider "helm" {
  kubernetes {
    config_path    = null
    config_context = null
  }
}
