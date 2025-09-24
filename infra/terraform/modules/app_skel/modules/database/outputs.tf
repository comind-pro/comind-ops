# Database Module Outputs

output "database_id" {
  description = "Database instance identifier"
  value = var.cluster_type == "local" ? (
    length(helm_release.postgresql) > 0 ? helm_release.postgresql[0].name : ""
    ) : var.cluster_type == "aws" ? (
    length(aws_db_instance.postgresql) > 0 ? aws_db_instance.postgresql[0].id : ""
    ) : var.cluster_type == "digitalocean" ? (
    length(digitalocean_database_cluster.postgresql) > 0 ? digitalocean_database_cluster.postgresql[0].id : ""
  ) : ""
}

output "endpoint" {
  description = "Database endpoint"
  value       = local.database_host
}

output "port" {
  description = "Database port"
  value       = local.database_port
}

output "database_name" {
  description = "Database name"
  value       = var.database_name
}

output "username" {
  description = "Database username"
  value       = var.database_username
  sensitive   = true
}

output "password" {
  description = "Database password"
  value       = var.database_password
  sensitive   = true
}

output "connection_string" {
  description = "Database connection string"
  value       = "postgresql://${var.database_username}:${var.database_password}@${local.database_host}:${local.database_port}/${var.database_name}"
  sensitive   = true
}

output "readonly_endpoint" {
  description = "Read-only database endpoint (if available)"
  value = var.cluster_type == "aws" && var.database_config.multi_az ? (
    length(aws_db_instance.postgresql) > 0 ? aws_db_instance.postgresql[0].endpoint : ""
    ) : var.cluster_type == "digitalocean" ? (
    length(digitalocean_database_cluster.postgresql) > 0 ? digitalocean_database_cluster.postgresql[0].host : ""
  ) : local.database_host
}

# Additional metadata
output "engine" {
  description = "Database engine"
  value       = var.database_config.engine
}

output "engine_version" {
  description = "Database engine version"
  value       = var.database_config.version
}

output "multi_az" {
  description = "Whether the database is multi-AZ"
  value       = var.database_config.multi_az
}

output "backup_retention_period" {
  description = "Backup retention period in days"
  value       = var.database_config.backup_retention_period
}

output "monitoring_enabled" {
  description = "Whether monitoring is enabled"
  value       = true
}
