# App Skeleton Module Outputs

# Namespace information
output "namespace" {
  description = "Kubernetes namespace for the application"
  value       = kubernetes_namespace.app.metadata[0].name
}

output "namespace_labels" {
  description = "Labels applied to the namespace"
  value       = kubernetes_namespace.app.metadata[0].labels
}

# Database outputs - using platform-wide PostgreSQL service
output "database" {
  description = "Database configuration and connection details"
  value = {
    enabled          = false
    message          = "Using platform-wide PostgreSQL service deployed via ArgoCD"
    platform_service = "postgresql-dev.platform-dev.svc.cluster.local:5432"
  }
  sensitive = false
}

# Storage outputs - using platform-wide MinIO service
output "storage" {
  description = "Storage configuration and bucket details"
  value = {
    enabled          = false
    message          = "Using platform-wide MinIO service deployed via ArgoCD"
    platform_service = "minio-dev.platform-dev.svc.cluster.local:9000"
    console_service  = "minio-dev-console.platform-dev.svc.cluster.local:9001"
  }
  sensitive = false
}

# Queue outputs
output "queue" {
  description = "Queue configuration and endpoint details"
  value = var.queue.enabled ? {
    enabled    = true
    endpoint   = module.queue[0].endpoint
    queue_urls = module.queue[0].queue_urls
    queues     = [for q in var.queue.queues : q.name]
    } : {
    enabled    = false
    endpoint   = null
    queue_urls = []
    queues     = []
  }
}

# Cache outputs - using platform-wide Redis service
output "cache" {
  description = "Cache configuration and connection details"
  value = {
    enabled          = false
    message          = "Using platform-wide Redis service deployed via ArgoCD"
    platform_service = "redis-dev-master.platform-dev.svc.cluster.local:6379"
  }
  sensitive = false
}

# Networking outputs
output "networking" {
  description = "Networking configuration"
  value = {
    ingress_enabled = var.networking.ingress_enabled
    hostname        = module.networking.ingress_hostname
    domain          = var.cluster_type == "local" ? var.networking.local_domain : var.networking.domain_name
    ingress_class   = var.cluster_type == "local" ? var.networking.local_ingress_class : "alb"
  }
}

# Monitoring outputs
output "monitoring" {
  description = "Monitoring configuration"
  value = var.monitoring.enabled ? {
    enabled              = true
    prometheus_enabled   = var.monitoring.prometheus_enabled
    service_monitor_name = module.monitoring[0].service_monitor_name
    grafana_enabled      = var.monitoring.grafana_enabled
    alerting_enabled     = var.monitoring.alerting_enabled
    } : {
    enabled = false
  }
}

# Security outputs
output "security" {
  description = "Security configuration"
  value = {
    service_account_name = module.security.service_account_name
    rbac_enabled         = var.security.create_rbac
    network_policies     = var.security.namespace_isolation
    namespace_isolation  = var.security.namespace_isolation
  }
}

# Backup outputs
output "backup" {
  description = "Backup configuration"
  value = var.backup.enabled ? {
    enabled                 = true
    schedule                = module.backup[0].backup_schedule
    retention_days          = var.backup.retention_days
    database_backup_enabled = var.backup.database_backup_enabled
    storage_backup_enabled  = var.backup.storage_backup_enabled
    } : {
    enabled = false
  }
}

# Application metadata
output "app_metadata" {
  description = "Application metadata and configuration"
  value = {
    app_name     = var.app_name
    environment  = var.environment
    team         = var.team
    cluster_type = var.cluster_type
    namespace    = local.kubernetes_namespace
    tags         = local.common_tags
  }
}

# Resource quotas
output "resource_quotas" {
  description = "Resource quotas applied to the namespace"
  value = {
    cpu_requests    = kubernetes_resource_quota.app.spec[0].hard["requests.cpu"]
    memory_requests = kubernetes_resource_quota.app.spec[0].hard["requests.memory"]
    cpu_limits      = kubernetes_resource_quota.app.spec[0].hard["limits.cpu"]
    memory_limits   = kubernetes_resource_quota.app.spec[0].hard["limits.memory"]
    max_pods        = kubernetes_resource_quota.app.spec[0].hard["pods"]
  }
}

# Configuration secrets (for application consumption)
output "config_secret_name" {
  description = "Name of the Kubernetes secret containing application configuration"
  value       = kubernetes_secret.app_config.metadata[0].name
}

output "secrets_secret_name" {
  description = "Name of the Kubernetes secret containing application secrets"
  value       = kubernetes_secret.app_secrets.metadata[0].name
}

# Connection strings and endpoints (for local development and testing)
output "service_endpoints" {
  description = "Service endpoints for connecting to provisioned resources"
  value = {
    database_url = "postgresql://${local.database_username}:postgres@postgresql-dev.platform-dev.svc.cluster.local:5432/${local.database_name}"
    storage_url  = "http://minio-dev.platform-dev.svc.cluster.local:9000"
    queue_url    = var.queue.enabled ? module.queue[0].endpoint : ""
    cache_url    = "redis-dev-master.platform-dev.svc.cluster.local:6379"
    app_url      = var.networking.ingress_enabled ? "http://${module.networking.ingress_hostname}" : ""
  }
  sensitive = true
}

# Summary of enabled features
output "enabled_features" {
  description = "Summary of enabled features for this application"
  value = {
    database    = var.database.enabled
    storage     = var.storage.enabled
    queue       = var.queue.enabled
    cache       = var.cache.enabled
    monitoring  = var.monitoring.enabled
    backup      = var.backup.enabled
    autoscaling = var.advanced.enable_autoscaling
    multi_az    = var.advanced.multi_az_deployment
  }
}

# Cost estimation metadata
output "cost_estimation" {
  description = "Metadata for cost estimation"
  value = {
    environment       = var.environment
    database_instance = var.database.enabled ? var.database.instance_class : "none"
    cache_instance    = var.cache.enabled ? var.cache.node_type : "none"
    storage_size      = var.storage.enabled ? "${length(var.storage.buckets)} buckets" : "none"
    backup_enabled    = var.backup.enabled
    multi_az          = var.advanced.multi_az_deployment
  }
}
