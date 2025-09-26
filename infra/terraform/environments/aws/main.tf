terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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
provider "aws" {
  region = var.aws_region
}

# Configure providers to use EKS cluster
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
    }
  }
}

# ====================================================
# SHARED INFRASTRUCTURE
# ====================================================

module "shared" {
  source = "../../modules/shared"
  
  cluster_type = var.cluster_type
  cluster_name = var.cluster_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  tags         = var.tags
}

# ====================================================
# EKS CLUSTER
# ====================================================

module "eks" {
  source = "../../modules/eks"
  
  cluster_name           = var.cluster_name
  kubernetes_version     = var.kubernetes_version
  subnet_ids             = concat(module.shared.public_subnet_ids, module.shared.private_subnet_ids)
  private_subnet_ids     = module.shared.private_subnet_ids
  aws_region            = var.aws_region
  node_group_desired_size = var.node_group_desired_size
  node_group_max_size    = var.node_group_max_size
  node_group_min_size    = var.node_group_min_size
  tags                   = var.tags
  
  depends_on = [module.shared]
}

# ====================================================
# KUBERNETES RESOURCES
# ====================================================

# Create namespaces
resource "null_resource" "create_namespaces" {
  provisioner "local-exec" {
    command = "${path.module}/../../scripts/create-namespaces.sh"
  }
  
  depends_on = [module.eks]
}

# Install ArgoCD
resource "null_resource" "install_argocd" {
  provisioner "local-exec" {
    command = templatefile("${path.module}/../../scripts/install-argocd-aws.sh", {
      ENVIRONMENT = var.environment
    })
  }
  
  depends_on = [null_resource.create_namespaces]
}

# Wait for ArgoCD
resource "null_resource" "wait_for_argocd" {
  provisioner "local-exec" {
    command = "${path.module}/../../scripts/wait-for-argocd.sh"
  }
  
  depends_on = [null_resource.install_argocd]
}