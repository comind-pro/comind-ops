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

# Database outputs
output "database" {
  description = "Database configuration and connection details"
  value = var.database.enabled ? {
    enabled           = true
    endpoint          = module.database[0].endpoint
    port              = module.database[0].port
    database_name     = module.database[0].database_name
    username          = module.database[0].username
    connection_string = module.database[0].connection_string
    readonly_endpoint = module.database[0].readonly_endpoint
    engine            = module.database[0].engine
    engine_version    = module.database[0].engine_version
    multi_az          = module.database[0].multi_az
    backup_retention  = module.database[0].backup_retention_period
  } : {
    enabled = false
  }
  sensitive = true
}

# Storage outputs
output "storage" {
  description = "Storage configuration and bucket details"
  value = var.storage.enabled ? {
    enabled       = true
    endpoint      = module.storage[0].endpoint
    access_key    = module.storage[0].access_key
    secret_key    = module.storage[0].secret_key
    bucket_names  = module.storage[0].bucket_names
    bucket_urls   = module.storage[0].bucket_urls
    console_url   = module.storage[0].console_url
    region        = module.storage[0].region
    service_name  = module.storage[0].service_name
    service_port  = module.storage[0].service_port
    secure        = module.storage[0].secure_connection
  } : {
    enabled = false
  }
  sensitive = true
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
    enabled = false
  }
}

# Cache outputs
output "cache" {
  description = "Cache configuration and connection details"
  value = var.cache.enabled ? {
    enabled    = true
    endpoint   = module.cache[0].endpoint
    port       = module.cache[0].port
    auth_token = module.cache[0].auth_token
  } : {
    enabled = false
  }
  sensitive = true
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
    service_account_name  = module.security.service_account_name
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
    schedule               = module.backup[0].backup_schedule
    retention_days         = var.backup.retention_days
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
    database_url = var.database.enabled ? "postgresql://${module.database[0].username}:${module.database[0].password}@${module.database[0].endpoint}:${module.database[0].port}/${module.database[0].database_name}" : ""
    storage_url  = var.storage.enabled ? "http://${module.storage[0].endpoint}" : ""
    queue_url    = var.queue.enabled ? "http://${module.queue[0].endpoint}" : ""
    cache_url    = var.cache.enabled ? "${module.cache[0].endpoint}:${module.cache[0].port}" : ""
    app_url      = var.networking.ingress_enabled ? "http://${module.networking.ingress_hostname}" : ""
  }
  sensitive = true
}

# Summary of enabled features
output "enabled_features" {
  description = "Summary of enabled features for this application"
  value = {
    database   = var.database.enabled
    storage    = var.storage.enabled
    queue      = var.queue.enabled
    cache      = var.cache.enabled
    monitoring = var.monitoring.enabled
    backup     = var.backup.enabled
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
