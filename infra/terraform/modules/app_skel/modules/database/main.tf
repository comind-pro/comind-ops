# Database Module - PostgreSQL provisioning for local and cloud environments

terraform {
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
  }
}

# Local PostgreSQL deployment (k3d)
resource "helm_release" "postgresql" {
  count = var.cluster_type == "local" ? 1 : 0

  name       = "${var.app_name}-postgresql"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  version    = "12.12.10"
  namespace  = var.kubernetes_namespace

  values = [
    yamlencode({
      global = {
        postgresql = {
          auth = {
            postgresPassword = var.database_password
            username         = var.database_username
            password         = var.database_password
            database         = var.database_name
          }
        }
      }

      architecture = var.database_config.local_replica_count > 1 ? "replication" : "standalone"

      primary = {
        persistence = {
          enabled = true
          size    = var.database_config.local_storage_size
        }
        resources = {
          requests = {
            memory = var.environment == "prod" ? "512Mi" : var.environment == "stage" ? "256Mi" : "128Mi"
            cpu    = var.environment == "prod" ? "500m" : var.environment == "stage" ? "250m" : "100m"
          }
          limits = {
            memory = var.environment == "prod" ? "1Gi" : var.environment == "stage" ? "512Mi" : "256Mi"
            cpu    = var.environment == "prod" ? "1000m" : var.environment == "stage" ? "500m" : "200m"
          }
        }
      }

      readReplicas = {
        replicaCount = var.database_config.local_replica_count > 1 ? var.database_config.local_replica_count - 1 : 0
      }

      metrics = {
        enabled = true
        serviceMonitor = {
          enabled = true
        }
      }

      networkPolicy = {
        enabled       = true
        allowExternal = false
      }
    })
  ]

  # depends_on = [] # Namespace created by parent module
}

# AWS RDS PostgreSQL instance
resource "aws_db_instance" "postgresql" {
  count = var.cluster_type == "aws" ? 1 : 0

  identifier = "${var.app_name}-${var.environment}-postgresql"

  # Engine configuration
  engine         = var.database_config.engine
  engine_version = var.database_config.version
  instance_class = var.database_config.instance_class

  # Storage configuration
  allocated_storage     = var.database_config.allocated_storage
  max_allocated_storage = var.database_config.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = var.database_config.storage_encrypted

  # Database configuration
  db_name  = var.database_name
  username = var.database_username
  password = var.database_password
  port     = 5432

  # Logging configuration
  enabled_cloudwatch_logs_exports = ["postgresql"]

  # Network configuration
  vpc_security_group_ids = var.security_group_ids
  db_subnet_group_name   = var.db_subnet_group_name
  publicly_accessible    = var.database_config.publicly_accessible

  # Backup configuration
  backup_retention_period = var.database_config.backup_retention_period
  backup_window           = var.database_config.backup_window
  maintenance_window      = var.database_config.maintenance_window

  # High availability
  multi_az = var.database_config.multi_az

  # Monitoring
  monitoring_interval = var.database_config.monitoring_interval
  monitoring_role_arn = var.monitoring_role_arn

  performance_insights_enabled          = var.environment == "prod"
  performance_insights_retention_period = var.environment == "prod" ? 7 : null

  # Security
  deletion_protection = var.database_config.deletion_protection
  skip_final_snapshot = var.database_config.skip_final_snapshot

  # Tags
  tags = var.tags
}

# DigitalOcean Database Cluster
resource "digitalocean_database_cluster" "postgresql" {
  count = var.cluster_type == "digitalocean" ? 1 : 0

  name       = "${var.app_name}-${var.environment}-postgresql"
  engine     = "pg"
  version    = var.database_config.version
  size       = var.database_config.instance_class # Maps to DO sizes
  region     = var.region
  node_count = var.database_config.multi_az ? 3 : 1

  tags = [for k, v in var.tags : "${k}:${v}"]
}

resource "digitalocean_database_db" "app_database" {
  count      = var.cluster_type == "digitalocean" ? 1 : 0
  cluster_id = digitalocean_database_cluster.postgresql[0].id
  name       = var.database_name
}

resource "digitalocean_database_user" "app_user" {
  count      = var.cluster_type == "digitalocean" ? 1 : 0
  cluster_id = digitalocean_database_cluster.postgresql[0].id
  name       = var.database_username
}

# Database initialization job (for all environments)
resource "kubernetes_job" "database_init" {
  metadata {
    name      = "${var.app_name}-db-init"
    namespace = var.kubernetes_namespace
    labels = {
      "app.kubernetes.io/name"       = var.app_name
      "app.kubernetes.io/component"  = "database-init"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = var.app_name
          "app.kubernetes.io/component" = "database-init"
        }
      }

      spec {
        restart_policy = "OnFailure"

        container {
          name  = "db-init"
          image = "postgres:15-alpine"

          command = ["/bin/sh", "-c"]
          args = [
            <<-EOT
            echo "Initializing database for ${var.app_name}..."
            
            # Wait for database to be ready
            until pg_isready -h $DATABASE_HOST -p $DATABASE_PORT -U $DATABASE_USERNAME; do
              echo "Waiting for database to be ready..."
              sleep 5
            done
            
            # Create database if it doesn't exist
            psql -h $DATABASE_HOST -p $DATABASE_PORT -U $DATABASE_USERNAME -tc "SELECT 1 FROM pg_database WHERE datname = '$DATABASE_NAME'" | grep -q 1 || \
            psql -h $DATABASE_HOST -p $DATABASE_PORT -U $DATABASE_USERNAME -c "CREATE DATABASE $DATABASE_NAME"
            
            # Create basic schema
            psql $DATABASE_URL -c "
            CREATE SCHEMA IF NOT EXISTS app;
            CREATE TABLE IF NOT EXISTS app.health_check (
              id SERIAL PRIMARY KEY,
              status VARCHAR(50) NOT NULL,
              timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
            INSERT INTO app.health_check (status) VALUES ('initialized');
            "
            
            echo "Database initialization completed successfully"
            EOT
          ]

          env {
            name  = "DATABASE_HOST"
            value = local.database_host
          }
          env {
            name  = "DATABASE_PORT"
            value = "5432"
          }
          env {
            name  = "DATABASE_NAME"
            value = var.database_name
          }
          env {
            name  = "DATABASE_USERNAME"
            value = var.database_username
          }
          env {
            name  = "PGPASSWORD"
            value = var.database_password
          }
          env {
            name  = "DATABASE_URL"
            value = "postgresql://${var.database_username}:${var.database_password}@${local.database_host}:5432/${var.database_name}"
          }

          resources {
            requests = {
              memory = "64Mi"
              cpu    = "50m"
            }
            limits = {
              memory = "128Mi"
              cpu    = "100m"
            }
          }
        }
      }
    }

    backoff_limit              = 3
    ttl_seconds_after_finished = 3600
  }

  depends_on = [
    helm_release.postgresql,
    aws_db_instance.postgresql,
    digitalocean_database_cluster.postgresql
  ]
}

# Local variables
locals {
  database_host = var.cluster_type == "local" ? "${var.app_name}-postgresql.${var.kubernetes_namespace}.svc.cluster.local" : (
    var.cluster_type == "aws" ? aws_db_instance.postgresql[0].endpoint : (
      var.cluster_type == "digitalocean" ? digitalocean_database_cluster.postgresql[0].host : ""
    )
  )

  database_port = var.cluster_type == "local" ? 5432 : (
    var.cluster_type == "aws" ? aws_db_instance.postgresql[0].port : (
      var.cluster_type == "digitalocean" ? digitalocean_database_cluster.postgresql[0].port : 5432
    )
  )
}
