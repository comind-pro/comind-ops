# Platform services for development environment
# This deploys shared platform services like ElasticMQ, Registry, and Backup jobs

# Deploy ElasticMQ (SQS-compatible queue service)
resource "helm_release" "elasticmq" {
  name      = "elasticmq"
  chart     = "${path.root}/../../../k8s/platform/elasticmq"
  namespace = "platform-dev"

  values = [
    file("${path.root}/../../../k8s/platform/elasticmq/values/dev.yaml")
  ]

  depends_on = [kubernetes_namespace.platform_dev]
}

# Deploy Docker Registry
resource "kubernetes_manifest" "docker_registry" {
  manifest = yamldecode(file("${path.root}/../../../k8s/platform/registry/registry.yaml"))
}

# Deploy Registry Cleanup CronJob
resource "kubernetes_manifest" "registry_cleanup" {
  manifest = yamldecode(file("${path.root}/../../../k8s/platform/registry/registry-cleanup.yaml"))

  depends_on = [kubernetes_manifest.docker_registry]
}

# Deploy Backup CronJobs
resource "kubernetes_manifest" "postgres_backup" {
  manifest = yamldecode(file("${path.root}/../../../k8s/platform/backups/postgres-cronjob.yaml"))
}

resource "kubernetes_manifest" "minio_backup" {
  manifest = yamldecode(file("${path.root}/../../../k8s/platform/backups/minio-cronjob.yaml"))
}

# Create platform namespace if it doesn't exist
resource "kubernetes_namespace" "platform_dev" {
  metadata {
    name = "platform-dev"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "platform"
    }
  }
}

# Local values
locals {
  platform_services = [
    "elasticmq",
    "docker-registry",
    "backup-postgres",
    "backup-minio"
  ]

  common_labels = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "comind-ops"
  }
}
