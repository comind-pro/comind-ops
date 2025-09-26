# App Skeleton Module Main Configuration
# Provisions application-specific infrastructure across different environments

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
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
  }
}

# Local variables for computed values
locals {
  # Common tags
  common_tags = merge(var.tags, {
    Application = var.app_name
    Environment = var.environment
    Team        = var.team
    ManagedBy   = "terraform"
    Module      = "app_skel"
  })

  # Resource naming
  resource_prefix = "${var.app_name}-${var.environment}"

  # Kubernetes namespace
  kubernetes_namespace = "${var.app_name}-${var.environment}"

  # Determine if we're running locally
  is_local = var.cluster_type == "local"

  # Environment-specific configurations
  environment_config = {
    dev = {
      instance_size = "small"
      replica_count = 1
      enable_backup = false
      multi_az      = false
    }
    stage = {
      instance_size = "medium"
      replica_count = 2
      enable_backup = true
      multi_az      = true
    }
    prod = {
      instance_size = "large"
      replica_count = 3
      enable_backup = true
      multi_az      = true
    }
  }

  current_env_config = local.environment_config[var.environment]

  # Database configuration
  database_name     = replace(var.app_name, "-", "_")
  database_username = "${local.database_name}_user"

  # Storage bucket names
  storage_buckets = var.storage.enabled ? [
    for bucket in var.storage.buckets : {
      name   = "${local.resource_prefix}-${bucket.name}"
      config = bucket
    }
  ] : []

  # Queue names  
  queue_names = var.queue.enabled ? [
    for queue in var.queue.queues : {
      name   = "${local.resource_prefix}-${queue.name}"
      config = queue
    }
  ] : []
}

# Random password for database
resource "random_password" "database_password" {
  count   = var.database.enabled ? 1 : 0
  length  = 32
  special = true
}

# Kubernetes namespace
resource "kubernetes_namespace" "app" {
  metadata {
    name = local.kubernetes_namespace
    labels = {
      "app.kubernetes.io/name"       = var.app_name
      "app.kubernetes.io/instance"   = var.environment
      "app.kubernetes.io/managed-by" = "terraform"
      "comind-ops.io/team"           = var.team
      "comind-ops.io/environment"    = var.environment
    }
    annotations = {
      "comind-ops.io/created-by" = "app_skel_module"
      "comind-ops.io/version"    = "1.0.0"
    }
  }
}

# Include sub-modules based on cluster type and configuration
# Database, Storage, and Cache modules removed - using platform-wide services
# These services are now managed centrally via ArgoCD GitOps

module "queue" {
  source = "./modules/queue"
  count  = var.queue.enabled ? 1 : 0

  app_name             = var.app_name
  environment          = var.environment
  cluster_type         = var.cluster_type
  kubernetes_namespace = kubernetes_namespace.app.metadata[0].name

  queue_config = var.queue
  queue_names  = local.queue_names

  tags = local.common_tags
}

# Cache module removed - using platform-wide Redis service

module "networking" {
  source = "./modules/networking"

  app_name             = var.app_name
  environment          = var.environment
  cluster_type         = var.cluster_type
  kubernetes_namespace = kubernetes_namespace.app.metadata[0].name

  networking_config = var.networking

  tags = local.common_tags
}

module "monitoring" {
  source = "./modules/monitoring"
  count  = var.monitoring.enabled ? 1 : 0

  app_name             = var.app_name
  environment          = var.environment
  cluster_type         = var.cluster_type
  kubernetes_namespace = kubernetes_namespace.app.metadata[0].name

  monitoring_config = var.monitoring

  tags = local.common_tags
}

module "security" {
  source = "./modules/security"

  app_name             = var.app_name
  environment          = var.environment
  cluster_type         = var.cluster_type
  kubernetes_namespace = kubernetes_namespace.app.metadata[0].name

  security_config = var.security

  tags = local.common_tags
}

module "backup" {
  source = "./modules/backup"
  count  = var.backup.enabled ? 1 : 0

  app_name             = var.app_name
  environment          = var.environment
  cluster_type         = var.cluster_type
  kubernetes_namespace = kubernetes_namespace.app.metadata[0].name

  backup_config = var.backup

  # Pass resources that need backup - using platform-wide services
  database_id     = "" # Platform-wide PostgreSQL service
  storage_buckets = [] # Platform-wide MinIO service

  tags = local.common_tags
}

# Application configuration secret
resource "kubernetes_secret" "app_config" {
  metadata {
    name      = "${var.app_name}-config"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = var.app_name
      "app.kubernetes.io/component"  = "config"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    # Database configuration - using platform-wide PostgreSQL service
    "database.enabled"  = "true"
    "database.host"     = "postgresql-dev.platform-dev.svc.cluster.local"
    "database.port"     = "5432"
    "database.name"     = local.database_name
    "database.username" = local.database_username

    # Storage configuration - using platform-wide MinIO service
    "storage.enabled"  = "true"
    "storage.endpoint" = "minio-dev.platform-dev.svc.cluster.local:9000"
    "storage.buckets"  = join(",", [for b in local.storage_buckets : b.name])

    # Queue configuration
    "queue.enabled"  = var.queue.enabled ? "true" : "false"
    "queue.endpoint" = var.queue.enabled ? module.queue[0].endpoint : ""
    "queue.queues"   = var.queue.enabled ? join(",", [for q in local.queue_names : q.name]) : ""

    # Cache configuration - using platform-wide Redis service
    "cache.enabled"  = "true"
    "cache.endpoint" = "redis-dev-master.platform-dev.svc.cluster.local"
    "cache.port"     = "6379"

    # Application metadata
    "app.name"        = var.app_name
    "app.environment" = var.environment
    "app.team"        = var.team
    "app.namespace"   = local.kubernetes_namespace
  }
}

# Application secrets
resource "kubernetes_secret" "app_secrets" {
  metadata {
    name      = "${var.app_name}-secrets"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = var.app_name
      "app.kubernetes.io/component"  = "secrets"
      "app.kubernetes.io/managed-by" = "terraform"
    }
    annotations = {
      "sealedsecrets.bitnami.com/managed" = "false"
      "terraform.io/note"                 = "This secret contains infrastructure-generated secrets. Application-specific secrets should use sealed-secrets."
    }
  }

  data = {
    # Database secrets - using platform-wide PostgreSQL service
    "DATABASE_PASSWORD" = base64encode("postgres") # Default password for platform service
    "DATABASE_URL"      = base64encode("postgresql://${local.database_username}:postgres@postgresql-dev.platform-dev.svc.cluster.local:5432/${local.database_name}")

    # Storage secrets - using platform-wide MinIO service
    "STORAGE_ACCESS_KEY" = base64encode("minioadmin") # Default access key for platform service
    "STORAGE_SECRET_KEY" = base64encode("minioadmin") # Default secret key for platform service

    # Cache secrets - using platform-wide Redis service (no auth for local)
    "CACHE_AUTH_TOKEN" = ""
  }
}

# Resource quotas for the namespace
resource "kubernetes_resource_quota" "app" {
  metadata {
    name      = "${var.app_name}-quota"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"           = var.environment == "prod" ? "4" : var.environment == "stage" ? "2" : "1"
      "requests.memory"        = var.environment == "prod" ? "8Gi" : var.environment == "stage" ? "4Gi" : "2Gi"
      "limits.cpu"             = var.environment == "prod" ? "8" : var.environment == "stage" ? "4" : "2"
      "limits.memory"          = var.environment == "prod" ? "16Gi" : var.environment == "stage" ? "8Gi" : "4Gi"
      "pods"                   = var.environment == "prod" ? "50" : var.environment == "stage" ? "30" : "10"
      "services"               = "10"
      "secrets"                = "20"
      "configmaps"             = "20"
      "persistentvolumeclaims" = var.environment == "prod" ? "10" : "5"
    }
  }
}

# Network policy for the application
resource "kubernetes_network_policy" "app" {
  count = var.security.namespace_isolation ? 1 : 0

  metadata {
    name      = "${var.app_name}-netpol"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    pod_selector {}

    policy_types = ["Ingress", "Egress"]

    # Allow ingress from ingress controller
    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = "ingress-nginx"
          }
        }
      }
    }

    # Allow ingress from same namespace
    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = local.kubernetes_namespace
          }
        }
      }
    }

    # Allow egress to platform services
    egress {
      to {
        namespace_selector {
          match_labels = {
            name = "platform-${var.environment}"
          }
        }
      }
    }

    # Allow egress to internet (DNS, external APIs)
    egress {
      ports {
        protocol = "UDP"
        port     = "53"
      }
    }

    egress {
      ports {
        protocol = "TCP"
        port     = "443"
      }
    }
  }
}
