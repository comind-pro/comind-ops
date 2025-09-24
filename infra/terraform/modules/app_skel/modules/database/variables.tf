# Database Module Variables

variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "environment" {
  description = "Environment (dev, stage, prod)"
  type        = string
}

variable "cluster_type" {
  description = "Type of cluster (local, aws, digitalocean)"
  type        = string
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace for the application"
  type        = string
}

variable "database_config" {
  description = "Database configuration"
  type        = any
}

variable "database_name" {
  description = "Database name"
  type        = string
}

variable "database_username" {
  description = "Database username"
  type        = string
}

variable "database_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

# AWS-specific variables
variable "security_group_ids" {
  description = "Security group IDs for AWS RDS"
  type        = list(string)
  default     = []
}

variable "db_subnet_group_name" {
  description = "DB subnet group name for AWS RDS"
  type        = string
  default     = ""
}

variable "monitoring_role_arn" {
  description = "IAM role ARN for RDS monitoring"
  type        = string
  default     = ""
}

# DigitalOcean-specific variables
variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "nyc1"
}
