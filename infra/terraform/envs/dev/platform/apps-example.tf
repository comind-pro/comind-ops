# Example usage of the app_skel module for sample applications
# This demonstrates how to provision infrastructure for applications

# Sample App Infrastructure (demonstrates all features)
module "sample_app" {
  source = "../../../modules/app_skel"

  # Basic configuration
  app_name     = "sample-app"
  environment  = "dev"
  team         = "platform"
  cluster_type = "local"

  # Database configuration
  database = {
    enabled             = true
    local_storage_size  = "10Gi"
    local_replica_count = 1
  }

  # Storage configuration
  storage = {
    enabled            = true
    local_storage_size = "20Gi"
    buckets = [
      {
        name               = "uploads"
        versioning_enabled = true
        lifecycle_enabled  = false
        cors_enabled       = true
        public_read        = false
      },
      {
        name                 = "backups"
        versioning_enabled   = true
        lifecycle_enabled    = true
        lifecycle_expiration = 30
        cors_enabled         = false
        public_read          = false
      },
      {
        name                 = "temp"
        versioning_enabled   = false
        lifecycle_enabled    = true
        lifecycle_expiration = 1
        cors_enabled         = true
        public_read          = false
      }
    ]
  }

  # Queue configuration  
  queue = {
    enabled = true
    queues = [
      {
        name                       = "default"
        delay_seconds              = 0
        visibility_timeout_seconds = 30
        dlq_enabled                = true
        dlq_max_receive_count      = 3
      },
      {
        name                       = "notifications"
        delay_seconds              = 0
        visibility_timeout_seconds = 60
        dlq_enabled                = true
        dlq_max_receive_count      = 5
      },
      {
        name                       = "high-priority"
        delay_seconds              = 0
        visibility_timeout_seconds = 10
        dlq_enabled                = false
      }
    ]
  }

  # Cache configuration (disabled for dev)
  cache = {
    enabled = false
  }

  # Networking configuration
  networking = {
    ingress_enabled     = true
    local_domain        = "127.0.0.1.nip.io"
    local_ingress_class = "nginx"
  }

  # Monitoring configuration
  monitoring = {
    enabled            = true
    prometheus_enabled = true
    grafana_enabled    = true
    alerting_enabled   = false # Disabled for dev
  }

  # Security configuration
  security = {
    create_service_account = true
    create_rbac            = true
    namespace_isolation    = true
  }

  # Backup configuration (minimal for dev)
  backup = {
    enabled                 = true
    backup_schedule         = "0 2 * * *" # Daily at 2 AM
    retention_days          = 7
    database_backup_enabled = true
    storage_backup_enabled  = false # Skip for dev
  }

  # Development-friendly settings
  local_overrides = {
    disable_ssl              = true
    enable_debug_mode        = true
    resource_limits_disabled = false
  }

  tags = {
    Environment = "development"
    Project     = "comind-ops"
    Team        = "platform"
    Purpose     = "sample-application"
    CreatedBy   = "terraform-app-skel-module"
  }
}

# Output sample app connection information for easy access
output "sample_app_info" {
  description = "Sample app infrastructure information"
  value = {
    namespace    = module.sample_app.namespace
    app_url      = "http://sample-app.dev.127.0.0.1.nip.io:8080"
    database_url = module.sample_app.service_endpoints.database_url
    storage_url  = module.sample_app.service_endpoints.storage_url
    queue_url    = module.sample_app.service_endpoints.queue_url
  }
  sensitive = true
}

# Example of a simpler application (minimal features)
module "hello_world_app" {
  source = "../../../modules/app_skel"

  app_name     = "hello-world"
  environment  = "dev"
  team         = "frontend"
  cluster_type = "local"

  # Only enable basic features
  database = {
    enabled = false
  }

  storage = {
    enabled = false
  }

  queue = {
    enabled = false
  }

  cache = {
    enabled = false
  }

  networking = {
    ingress_enabled     = true
    local_domain        = "127.0.0.1.nip.io"
    local_ingress_class = "nginx"
  }

  monitoring = {
    enabled = true
  }

  security = {
    create_service_account = true
    create_rbac            = true
    namespace_isolation    = false # More permissive for simple app
  }

  backup = {
    enabled = false
  }

  tags = {
    Environment = "development"
    Project     = "comind-ops"
    Team        = "frontend"
    Purpose     = "hello-world-demo"
    Complexity  = "minimal"
  }
}

# Example of a data-intensive application
module "analytics_app" {
  source = "../../../modules/app_skel"

  app_name     = "analytics"
  environment  = "dev"
  team         = "data"
  cluster_type = "local"

  # Database with larger storage
  database = {
    enabled             = true
    local_storage_size  = "50Gi"
    local_replica_count = 1
  }

  # Multiple storage buckets for data pipeline
  storage = {
    enabled            = true
    local_storage_size = "100Gi"
    buckets = [
      {
        name                 = "raw-data"
        versioning_enabled   = true
        lifecycle_enabled    = true
        lifecycle_expiration = 90
        cors_enabled         = false
        public_read          = false
      },
      {
        name                 = "processed-data"
        versioning_enabled   = true
        lifecycle_enabled    = true
        lifecycle_expiration = 365
        cors_enabled         = false
        public_read          = false
      },
      {
        name                 = "reports"
        versioning_enabled   = false
        lifecycle_enabled    = true
        lifecycle_expiration = 30
        cors_enabled         = true
        public_read          = true
      }
    ]
  }

  # Queue for data processing jobs
  queue = {
    enabled = true
    queues = [
      {
        name                       = "data-ingestion"
        delay_seconds              = 0
        visibility_timeout_seconds = 300     # 5 minutes for long jobs
        message_retention_seconds  = 1209600 # 14 days
        dlq_enabled                = true
        dlq_max_receive_count      = 3
      },
      {
        name                       = "data-processing"
        delay_seconds              = 0
        visibility_timeout_seconds = 600 # 10 minutes
        message_retention_seconds  = 1209600
        dlq_enabled                = true
        dlq_max_receive_count      = 2
      },
      {
        name                       = "report-generation"
        delay_seconds              = 0
        visibility_timeout_seconds = 120
        message_retention_seconds  = 604800 # 7 days
        dlq_enabled                = true
        dlq_max_receive_count      = 5
      }
    ]
  }

  # Cache for query optimization
  cache = {
    enabled             = true
    local_storage_size  = "5Gi"
    local_replica_count = 1
  }

  networking = {
    ingress_enabled     = true
    local_domain        = "127.0.0.1.nip.io"
    local_ingress_class = "nginx"
  }

  monitoring = {
    enabled            = true
    prometheus_enabled = true
    grafana_enabled    = true
    alerting_enabled   = true # Enable alerts for data pipeline
  }

  security = {
    create_service_account = true
    create_rbac            = true
    namespace_isolation    = true
  }

  backup = {
    enabled                 = true
    backup_schedule         = "0 1 * * *" # Daily at 1 AM
    retention_days          = 30
    database_backup_enabled = true
    storage_backup_enabled  = true
  }

  tags = {
    Environment   = "development"
    Project       = "comind-ops"
    Team          = "data"
    Purpose       = "analytics-pipeline"
    DataSensitive = "true"
  }
}

# Output infrastructure information for all apps
output "dev_apps_infrastructure" {
  description = "Development environment application infrastructure"
  value = {
    sample_app = {
      namespace        = module.sample_app.namespace
      enabled_features = module.sample_app.enabled_features
      resource_quotas  = module.sample_app.resource_quotas
    }
    hello_world = {
      namespace        = module.hello_world_app.namespace
      enabled_features = module.hello_world_app.enabled_features
      resource_quotas  = module.hello_world_app.resource_quotas
    }
    analytics = {
      namespace        = module.analytics_app.namespace
      enabled_features = module.analytics_app.enabled_features
      resource_quotas  = module.analytics_app.resource_quotas
    }
  }
}
