# App Skeleton Module Variables
# Flexible infrastructure provisioning for applications

# Basic application configuration
variable "app_name" {
  description = "Name of the application"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.app_name))
    error_message = "App name must be lowercase, start with a letter, and contain only letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment (dev, stage, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "Environment must be one of: dev, stage, prod."
  }
}

variable "team" {
  description = "Team responsible for the application"
  type        = string
  default     = "platform"
}

variable "cluster_type" {
  description = "Type of cluster (local, aws, digitalocean)"
  type        = string
  default     = "local"
  validation {
    condition     = contains(["local", "aws", "digitalocean"], var.cluster_type)
    error_message = "Cluster type must be one of: local, aws, digitalocean."
  }
}

# Database configuration
variable "database" {
  description = "Database configuration"
  type = object({
    enabled                 = bool
    engine                  = optional(string, "postgresql")
    version                 = optional(string, "15")
    instance_class          = optional(string, "db.t3.micro")
    allocated_storage       = optional(number, 20)
    max_allocated_storage   = optional(number, 100)
    backup_retention_period = optional(number, 7)
    backup_window           = optional(string, "03:00-04:00")
    maintenance_window      = optional(string, "Mon:04:00-Mon:05:00")
    multi_az                = optional(bool, false)
    publicly_accessible     = optional(bool, false)
    storage_encrypted       = optional(bool, true)
    deletion_protection     = optional(bool, false)
    skip_final_snapshot     = optional(bool, true)
    # Local k3d configuration
    local_storage_size  = optional(string, "10Gi")
    local_replica_count = optional(number, 1)
    # External service configuration for local development
    external_host = optional(string, "localhost")
    external_port = optional(number, 5432)
  })
  default = {
    enabled = false
  }
}

# Storage configuration
variable "storage" {
  description = "Storage configuration"
  type = object({
    enabled = bool
    buckets = optional(list(object({
      name                 = string
      versioning_enabled   = optional(bool, true)
      lifecycle_enabled    = optional(bool, true)
      lifecycle_expiration = optional(number, 365)
      cors_enabled         = optional(bool, false)
      public_read          = optional(bool, false)
    })), [])
    # Local MinIO configuration
    local_storage_size  = optional(string, "20Gi")
    local_replica_count = optional(number, 1)
  })
  default = {
    enabled = false
  }
}

# Queue configuration
variable "queue" {
  description = "Message queue configuration"
  type = object({
    enabled = bool
    queues = optional(list(object({
      name                       = string
      delay_seconds              = optional(number, 0)
      max_message_size           = optional(number, 262144)
      message_retention_seconds  = optional(number, 345600)
      receive_wait_time_seconds  = optional(number, 0)
      visibility_timeout_seconds = optional(number, 30)
      # Dead letter queue configuration
      dlq_enabled           = optional(bool, true)
      dlq_max_receive_count = optional(number, 3)
    })), [])
  })
  default = {
    enabled = false
  }
}

# Cache configuration
variable "cache" {
  description = "Cache configuration (Redis/ElastiCache)"
  type = object({
    enabled            = bool
    node_type          = optional(string, "cache.t3.micro")
    num_cache_nodes    = optional(number, 1)
    port               = optional(number, 6379)
    parameter_group    = optional(string, "default.redis7")
    subnet_group_name  = optional(string, "")
    security_group_ids = optional(list(string), [])
    # Local configuration
    local_storage_size  = optional(string, "1Gi")
    local_replica_count = optional(number, 1)
  })
  default = {
    enabled = false
  }
}

# Networking configuration
variable "networking" {
  description = "Networking configuration"
  type = object({
    vpc_id             = optional(string, "")
    subnet_ids         = optional(list(string), [])
    availability_zones = optional(list(string), [])
    ingress_enabled    = optional(bool, true)
    load_balancer_type = optional(string, "application") # application, network
    certificate_arn    = optional(string, "")
    domain_name        = optional(string, "")
    subdomain          = optional(string, "")
    # Local configuration
    local_domain        = optional(string, "127.0.0.1.nip.io")
    local_ingress_class = optional(string, "nginx")
  })
  default = {}
}

# Monitoring configuration
variable "monitoring" {
  description = "Monitoring configuration"
  type = object({
    enabled            = bool
    prometheus_enabled = optional(bool, true)
    grafana_enabled    = optional(bool, true)
    alerting_enabled   = optional(bool, true)
    log_retention_days = optional(number, 30)
    # CloudWatch configuration
    cloudwatch_enabled   = optional(bool, false)
    cloudwatch_log_group = optional(string, "")
  })
  default = {
    enabled = false
  }
}

# Security configuration
variable "security" {
  description = "Security configuration"
  type = object({
    # IAM configuration
    create_iam_role = optional(bool, true)
    iam_role_name   = optional(string, "")
    iam_policies    = optional(list(string), [])
    # Network security
    security_group_ids     = optional(list(string), [])
    create_security_groups = optional(bool, true)
    # Kubernetes RBAC
    create_service_account = optional(bool, true)
    create_rbac            = optional(bool, true)
    namespace_isolation    = optional(bool, true)
  })
  default = {}
}

# Backup configuration
variable "backup" {
  description = "Backup configuration"
  type = object({
    enabled             = bool
    backup_schedule     = optional(string, "0 2 * * *") # Daily at 2 AM
    retention_days      = optional(number, 7)
    cross_region_backup = optional(bool, false)
    backup_vault        = optional(string, "")
    # Database backup
    database_backup_enabled = optional(bool, true)
    # Storage backup
    storage_backup_enabled = optional(bool, true)
  })
  default = {
    enabled = false
  }
}

# Resource tagging
variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

# Advanced configuration
variable "advanced" {
  description = "Advanced configuration options"
  type = object({
    # Scaling configuration
    enable_autoscaling     = optional(bool, false)
    min_capacity           = optional(number, 1)
    max_capacity           = optional(number, 10)
    target_cpu_utilization = optional(number, 70)

    # High availability
    multi_az_deployment       = optional(bool, false)
    cross_zone_load_balancing = optional(bool, true)

    # Performance
    enable_performance_insights    = optional(bool, false)
    performance_insights_retention = optional(number, 7)

    # Disaster recovery
    enable_cross_region_replication = optional(bool, false)
    replication_region              = optional(string, "")
  })
  default = {}
}

# Local development overrides
variable "local_overrides" {
  description = "Local development specific overrides"
  type = object({
    use_host_storage         = optional(bool, false)
    host_storage_path        = optional(string, "/tmp/app-data")
    disable_ssl              = optional(bool, true)
    enable_debug_mode        = optional(bool, true)
    resource_limits_disabled = optional(bool, true)
  })
  default = {}
}
