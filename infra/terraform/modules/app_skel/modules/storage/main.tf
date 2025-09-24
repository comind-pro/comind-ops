# Storage Module - S3/MinIO bucket provisioning for local and cloud environments

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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }
}

# Generate MinIO credentials for local deployment
resource "random_password" "minio_access_key" {
  count   = var.cluster_type == "local" ? 1 : 0
  length  = 20
  special = false
  upper   = true
  lower   = true
  numeric = true
}

resource "random_password" "minio_secret_key" {
  count   = var.cluster_type == "local" ? 1 : 0
  length  = 40
  special = false
  upper   = true
  lower   = true
  numeric = true
}

# Local MinIO deployment (k3d)
resource "helm_release" "minio" {
  count = var.cluster_type == "local" ? 1 : 0

  name       = "${var.app_name}-minio"
  repository = "https://charts.min.io/"
  chart      = "minio"
  version    = "5.0.14"
  namespace  = var.kubernetes_namespace

  values = [
    yamlencode({
      # Authentication
      rootUser     = random_password.minio_access_key[0].result
      rootPassword = random_password.minio_secret_key[0].result

      # Storage
      persistence = {
        enabled = true
        size    = var.storage_config.local_storage_size
      }

      # Resources
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

      # High availability
      replicas = var.storage_config.local_replica_count

      # Console (web UI)
      consoleService = {
        type = "ClusterIP"
      }

      # API service
      service = {
        type = "ClusterIP"
        port = 9000
      }

      # Security
      securityContext = {
        enabled    = true
        runAsUser  = 1000
        runAsGroup = 1000
        fsGroup    = 1000
      }

      # Network policy
      networkPolicy = {
        enabled       = true
        allowExternal = false
      }

      # Metrics
      metrics = {
        serviceMonitor = {
          enabled = true
        }
      }
    })
  ]
}

# AWS S3 buckets
resource "aws_s3_bucket" "app_buckets" {
  count = var.cluster_type == "aws" ? length(var.storage_buckets) : 0

  bucket = var.storage_buckets[count.index].name
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "app_buckets" {
  count = var.cluster_type == "aws" ? length(var.storage_buckets) : 0

  bucket = aws_s3_bucket.app_buckets[count.index].id
  versioning_configuration {
    status = var.storage_buckets[count.index].config.versioning_enabled ? "Enabled" : "Disabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "app_buckets" {
  count = var.cluster_type == "aws" && var.storage_buckets[0].config.lifecycle_enabled ? length(var.storage_buckets) : 0

  bucket = aws_s3_bucket.app_buckets[count.index].id

  rule {
    id     = "lifecycle_rule"
    status = "Enabled"

    expiration {
      days = var.storage_buckets[count.index].config.lifecycle_expiration
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "app_buckets" {
  count = var.cluster_type == "aws" && var.storage_buckets[0].config.cors_enabled ? length(var.storage_buckets) : 0

  bucket = aws_s3_bucket.app_buckets[count.index].id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_public_access_block" "app_buckets" {
  count = var.cluster_type == "aws" ? length(var.storage_buckets) : 0

  bucket = aws_s3_bucket.app_buckets[count.index].id

  block_public_acls       = !var.storage_buckets[count.index].config.public_read
  block_public_policy     = !var.storage_buckets[count.index].config.public_read
  ignore_public_acls      = !var.storage_buckets[count.index].config.public_read
  restrict_public_buckets = !var.storage_buckets[count.index].config.public_read
}

# DigitalOcean Spaces
resource "digitalocean_spaces_bucket" "app_buckets" {
  count = var.cluster_type == "digitalocean" ? length(var.storage_buckets) : 0

  name   = var.storage_buckets[count.index].name
  region = var.region

  versioning {
    enabled = var.storage_buckets[count.index].config.versioning_enabled
  }

  lifecycle_rule {
    id      = "lifecycle_rule"
    enabled = var.storage_buckets[count.index].config.lifecycle_enabled

    expiration {
      days = var.storage_buckets[count.index].config.lifecycle_expiration
    }
  }

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }
}

# Bucket initialization job (creates buckets in MinIO)
resource "kubernetes_job" "bucket_init" {
  count = var.cluster_type == "local" ? 1 : 0

  metadata {
    name      = "${var.app_name}-bucket-init"
    namespace = var.kubernetes_namespace
    labels = {
      "app.kubernetes.io/name"       = var.app_name
      "app.kubernetes.io/component"  = "storage-init"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = var.app_name
          "app.kubernetes.io/component" = "storage-init"
        }
      }

      spec {
        restart_policy = "OnFailure"

        container {
          name  = "bucket-init"
          image = "minio/mc:latest"

          command = ["/bin/sh", "-c"]
          args = [
            <<-EOT
            echo "Initializing storage buckets for ${var.app_name}..."
            
            # Wait for MinIO to be ready
            until mc alias set local $MINIO_ENDPOINT $MINIO_ACCESS_KEY $MINIO_SECRET_KEY; do
              echo "Waiting for MinIO to be ready..."
              sleep 5
            done
            
            # Create buckets
            %{for bucket in var.storage_buckets}
            echo "Creating bucket: ${bucket.name}"
            mc mb local/${bucket.name} --ignore-existing
            
            # Set bucket policy if public read is enabled
            %{if bucket.config.public_read}
            mc policy set download local/${bucket.name}
            %{endif}
            
            # Enable versioning if requested
            %{if bucket.config.versioning_enabled}
            mc version enable local/${bucket.name}
            %{endif}
            %{endfor}
            
            echo "Storage initialization completed successfully"
            EOT
          ]

          env {
            name  = "MINIO_ENDPOINT"
            value = "http://${var.app_name}-minio.${var.kubernetes_namespace}.svc.cluster.local:9000"
          }
          env {
            name  = "MINIO_ACCESS_KEY"
            value = random_password.minio_access_key[0].result
          }
          env {
            name  = "MINIO_SECRET_KEY"
            value = random_password.minio_secret_key[0].result
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

  depends_on = [helm_release.minio]
}

# IAM user for S3 access (AWS only)
resource "aws_iam_user" "s3_user" {
  count = var.cluster_type == "aws" ? 1 : 0
  name  = "${var.app_name}-${var.environment}-s3-user"
  tags  = var.tags
}

resource "aws_iam_access_key" "s3_user" {
  count = var.cluster_type == "aws" ? 1 : 0
  user  = aws_iam_user.s3_user[0].name
}

resource "aws_iam_user_policy" "s3_policy" {
  count = var.cluster_type == "aws" ? 1 : 0
  name  = "${var.app_name}-${var.environment}-s3-policy"
  user  = aws_iam_user.s3_user[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObjectVersion",
          "s3:ListBucket"
        ]
        Resource = [
          for bucket in aws_s3_bucket.app_buckets : [
            bucket.arn,
            "${bucket.arn}/*"
          ]
        ]
      }
    ]
  })
}

# Local variables
locals {
  storage_endpoint = var.cluster_type == "local" ? (
    "${var.app_name}-minio.${var.kubernetes_namespace}.svc.cluster.local:9000"
    ) : var.cluster_type == "aws" ? (
    "s3.amazonaws.com"
    ) : var.cluster_type == "digitalocean" ? (
    "${var.region}.digitaloceanspaces.com"
  ) : ""

  access_key = var.cluster_type == "local" ? (
    length(random_password.minio_access_key) > 0 ? random_password.minio_access_key[0].result : ""
    ) : var.cluster_type == "aws" ? (
    length(aws_iam_access_key.s3_user) > 0 ? aws_iam_access_key.s3_user[0].id : ""
  ) : ""

  secret_key = var.cluster_type == "local" ? (
    length(random_password.minio_secret_key) > 0 ? random_password.minio_secret_key[0].result : ""
    ) : var.cluster_type == "aws" ? (
    length(aws_iam_access_key.s3_user) > 0 ? aws_iam_access_key.s3_user[0].secret : ""
  ) : ""
}
