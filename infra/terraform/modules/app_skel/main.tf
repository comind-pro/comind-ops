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
module "database" {
  source = "./modules/database"
  count  = var.database.enabled ? 1 : 0

  app_name             = var.app_name
  environment          = var.environment
  cluster_type         = var.cluster_type
  kubernetes_namespace = kubernetes_namespace.app.metadata[0].name

  database_config   = var.database
  database_name     = local.database_name
  database_username = local.database_username
  database_password = random_password.database_password[0].result

  tags = local.common_tags
}

module "storage" {
  source = "./modules/storage"
  count  = var.storage.enabled ? 1 : 0

  app_name             = var.app_name
  environment          = var.environment
  cluster_type         = var.cluster_type
  kubernetes_namespace = kubernetes_namespace.app.metadata[0].name

  storage_config  = var.storage
  storage_buckets = local.storage_buckets

  tags = local.common_tags
}

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

module "cache" {
  source = "./modules/cache"
  count  = var.cache.enabled ? 1 : 0

  app_name             = var.app_name
  environment          = var.environment
  cluster_type         = var.cluster_type
  kubernetes_namespace = kubernetes_namespace.app.metadata[0].name

  cache_config = var.cache

  tags = local.common_tags
}

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

  # Pass resources that need backup
  database_id     = var.database.enabled ? module.database[0].database_id : ""
  storage_buckets = var.storage.enabled ? module.storage[0].bucket_names : []

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
    # Database configuration
    "database.enabled"  = var.database.enabled ? "true" : "false"
    "database.host"     = var.database.enabled ? module.database[0].endpoint : ""
    "database.port"     = var.database.enabled ? tostring(module.database[0].port) : ""
    "database.name"     = var.database.enabled ? local.database_name : ""
    "database.username" = var.database.enabled ? local.database_username : ""

    # Storage configuration
    "storage.enabled"  = var.storage.enabled ? "true" : "false"
    "storage.endpoint" = var.storage.enabled ? module.storage[0].endpoint : ""
    "storage.buckets"  = var.storage.enabled ? join(",", [for b in local.storage_buckets : b.name]) : ""

    # Queue configuration
    "queue.enabled"  = var.queue.enabled ? "true" : "false"
    "queue.endpoint" = var.queue.enabled ? module.queue[0].endpoint : ""
    "queue.queues"   = var.queue.enabled ? join(",", [for q in local.queue_names : q.name]) : ""

    # Cache configuration
    "cache.enabled"  = var.cache.enabled ? "true" : "false"
    "cache.endpoint" = var.cache.enabled ? module.cache[0].endpoint : ""
    "cache.port"     = var.cache.enabled ? tostring(var.cache.port) : ""

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
    # Database secrets
    "DATABASE_PASSWORD" = var.database.enabled ? base64encode(random_password.database_password[0].result) : ""
    "DATABASE_URL"      = var.database.enabled ? base64encode("postgresql://${local.database_username}:${random_password.database_password[0].result}@${module.database[0].endpoint}:${module.database[0].port}/${local.database_name}") : ""

    # Storage secrets
    "STORAGE_ACCESS_KEY" = var.storage.enabled && var.cluster_type == "local" ? base64encode(module.storage[0].access_key) : ""
    "STORAGE_SECRET_KEY" = var.storage.enabled && var.cluster_type == "local" ? base64encode(module.storage[0].secret_key) : ""

    # Cache secrets
    "CACHE_AUTH_TOKEN" = var.cache.enabled && var.cluster_type != "local" ? base64encode(module.cache[0].auth_token) : ""
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
      to {}
      ports {
        protocol = "UDP"
        port     = "53"
      }
    }

    egress {
      to {}
      ports {
        protocol = "TCP"
        port     = "443"
      }
    }
  }
}
