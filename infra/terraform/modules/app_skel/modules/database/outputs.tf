# Database Module Outputs

# Local (External PostgreSQL via Docker)
output "database_host" {
  description = "Database host endpoint"
  value = var.cluster_type == "local" ? (
    length(kubernetes_service.postgresql_external) > 0 ? "${var.app_name}-postgresql-external.${var.kubernetes_namespace}.svc.cluster.local" : null
    ) : (
    var.cluster_type == "aws" ? (
      length(aws_db_instance.postgresql) > 0 ? aws_db_instance.postgresql[0].endpoint : null
      ) : (
      length(digitalocean_database_cluster.postgresql) > 0 ? digitalocean_database_cluster.postgresql[0].host : null
    )
  )
}

output "database_port" {
  description = "Database port"
  value = var.cluster_type == "local" ? var.database_config.external_port : (
    var.cluster_type == "aws" ? (
      length(aws_db_instance.postgresql) > 0 ? aws_db_instance.postgresql[0].port : null
      ) : (
      length(digitalocean_database_cluster.postgresql) > 0 ? digitalocean_database_cluster.postgresql[0].port : null
    )
  )
}

output "database_name" {
  description = "Database name"
  value       = var.database_name
}

output "database_username" {
  description = "Database username"
  value       = var.database_username
  sensitive   = true
}

output "database_connection_string" {
  description = "Full database connection string"
  value = var.cluster_type == "local" ? (
    "postgresql://${var.database_username}:${var.database_password}@${var.database_config.external_host}:${var.database_config.external_port}/${var.database_name}"
    ) : (
    var.cluster_type == "aws" ? (
      length(aws_db_instance.postgresql) > 0 ?
      "postgresql://${var.database_username}:${var.database_password}@${aws_db_instance.postgresql[0].endpoint}:${aws_db_instance.postgresql[0].port}/${var.database_name}" : null
      ) : (
      length(digitalocean_database_cluster.postgresql) > 0 ?
      "postgresql://${var.database_username}:${var.database_password}@${digitalocean_database_cluster.postgresql[0].host}:${digitalocean_database_cluster.postgresql[0].port}/${var.database_name}" : null
    )
  )
  sensitive = true
}

output "external_service_info" {
  description = "External service information (for local development)"
  value = var.cluster_type == "local" ? {
    service_name  = length(kubernetes_service.postgresql_external) > 0 ? kubernetes_service.postgresql_external[0].metadata[0].name : null
    service_type  = "ExternalName"
    external_host = var.database_config.external_host
    external_port = var.database_config.external_port
    namespace     = var.kubernetes_namespace
  } : null
}

# Additional outputs required by the main module
output "endpoint" {
  description = "Database endpoint (alias for database_host)"
  value = var.cluster_type == "local" ? var.database_config.external_host : (
    var.cluster_type == "aws" ? (
      length(aws_db_instance.postgresql) > 0 ? aws_db_instance.postgresql[0].endpoint : null
      ) : (
      length(digitalocean_database_cluster.postgresql) > 0 ? digitalocean_database_cluster.postgresql[0].host : null
    )
  )
}

output "port" {
  description = "Database port"
  value = var.cluster_type == "local" ? var.database_config.external_port : (
    var.cluster_type == "aws" ? (
      length(aws_db_instance.postgresql) > 0 ? aws_db_instance.postgresql[0].port : null
      ) : (
      length(digitalocean_database_cluster.postgresql) > 0 ? digitalocean_database_cluster.postgresql[0].port : null
    )
  )
}

output "username" {
  description = "Database username"
  value       = var.database_username
  sensitive   = true
}

output "connection_string" {
  description = "Database connection string"
  value = var.cluster_type == "local" ? (
    "postgresql://${var.database_username}:${var.database_password}@${var.database_config.external_host}:${var.database_config.external_port}/${var.database_name}"
    ) : (
    var.cluster_type == "aws" ? (
      length(aws_db_instance.postgresql) > 0 ?
      "postgresql://${var.database_username}:${var.database_password}@${aws_db_instance.postgresql[0].endpoint}:${aws_db_instance.postgresql[0].port}/${var.database_name}" : null
      ) : (
      length(digitalocean_database_cluster.postgresql) > 0 ?
      "postgresql://${var.database_username}:${var.database_password}@${digitalocean_database_cluster.postgresql[0].host}:${digitalocean_database_cluster.postgresql[0].port}/${var.database_name}" : null
    )
  )
  sensitive = true
}

output "readonly_endpoint" {
  description = "Read-only database endpoint"
  value = var.cluster_type == "local" ? var.database_config.external_host : (
    var.cluster_type == "aws" ? (
      length(aws_db_instance.postgresql) > 0 ? aws_db_instance.postgresql[0].endpoint : null
      ) : (
      length(digitalocean_database_cluster.postgresql) > 0 ? digitalocean_database_cluster.postgresql[0].host : null
    )
  )
}

output "engine" {
  description = "Database engine"
  value       = var.database_config.engine
}

output "engine_version" {
  description = "Database engine version"
  value       = var.database_config.version
}

output "multi_az" {
  description = "Multi-AZ configuration"
  value       = var.cluster_type == "aws" ? var.database_config.multi_az : false
}

output "backup_retention_period" {
  description = "Backup retention period"
  value       = var.cluster_type == "aws" ? var.database_config.backup_retention_days : 0
}

output "database_id" {
  description = "Database instance identifier"
  value = var.cluster_type == "local" ? "${var.app_name}-${var.environment}-external" : (
    var.cluster_type == "aws" ? (
      length(aws_db_instance.postgresql) > 0 ? aws_db_instance.postgresql[0].id : null
      ) : (
      length(digitalocean_database_cluster.postgresql) > 0 ? digitalocean_database_cluster.postgresql[0].id : null
    )
  )
}

output "password" {
  description = "Database password"
  value       = var.database_password
  sensitive   = true
}