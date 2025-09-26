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
  
  # Use empty access key when local to avoid AWS calls
  access_key = var.cluster_type == "local" ? "mock" : null
  secret_key = var.cluster_type == "local" ? "mock" : null
}

# Configure providers to use k3d cluster
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

# ====================================================
# LOCAL INFRASTRUCTURE (K3D CLUSTER)
# ====================================================

# Cluster module
module "cluster" {
  source = "../../modules/cluster"
  
  cluster_type = var.cluster_type
  cluster_name = var.cluster_name
  create_cluster_script = templatefile("${path.module}/../../scripts/create-k3d-cluster.sh", {
    CLUSTER_TYPE = var.cluster_type
    CLUSTER_NAME = var.cluster_name
    CLUSTER_PORT = var.cluster_port
    INGRESS_HTTP_PORT = var.ingress_http_port
    INGRESS_HTTPS_PORT = var.ingress_https_port
  })
}

# Kubernetes module
module "kubernetes" {
  source = "../../modules/kubernetes"
  
  cluster_type = var.cluster_type
  create_namespaces_script = "${path.module}/../../scripts/create-namespaces.sh"
  
  depends_on = [module.cluster]
}

# Helm module
module "helm" {
  source = "../../modules/helm"
  
  cluster_type = var.cluster_type
  install_metallb_script = "${path.module}/../../scripts/install-metallb.sh"
  metallb_config_script = "${path.module}/../../scripts/configure-metallb.sh"
  install_ingress_nginx_script = "${path.module}/../../scripts/install-ingress-nginx.sh"
  install_sealed_secrets_script = "${path.module}/../../scripts/install-sealed-secrets.sh"
  install_argocd_script = templatefile("${path.module}/../../scripts/install-argocd.sh", {
    ENVIRONMENT = var.environment
  })
  wait_for_argocd_script = "${path.module}/../../scripts/wait-for-argocd.sh"
  
  depends_on = [module.kubernetes]
}

# ====================================================
# EXTERNAL SERVICES VALIDATION
# ====================================================

# Data source to check external services
data "external" "external_services_check" {
  program = ["${path.module}/../../scripts/check-external-services.sh"]
}

# External services status output
resource "null_resource" "external_services_status" {
  count = var.cluster_type == "local" ? 1 : 0

  provisioner "local-exec" {
    command = templatefile("${path.module}/../../scripts/external-services-status.sh", {
      POSTGRES_STATUS = data.external.external_services_check.result["postgres_status"]
      MINIO_STATUS = data.external.external_services_check.result["minio_status"]
      POSTGRES_HEALTH = data.external.external_services_check.result["postgres_health"]
      MINIO_HEALTH = data.external.external_services_check.result["minio_health"]
      SERVICES_READY = data.external.external_services_check.result["services_ready"]
    })
  }
}

# ====================================================
# LOCAL ENVIRONMENT - No AWS resources needed
# ====================================================