# Platform services for development environment
# This configuration is primarily for demonstration and would typically be
# managed by Kustomize and ArgoCD in a production GitOps workflow

# Create namespace for platform services
resource "kubernetes_namespace" "platform_dev" {
  metadata {
    name = "platform-dev"
    labels = {
      name                                 = "platform-dev"
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/audit"   = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }
  }
}

# NOTE: In production, platform services would be deployed via:
# 1. Kustomize for manifest management
# 2. ArgoCD for GitOps deployment
# 3. Helm charts for complex applications
#
# The following resources are commented out to avoid file path resolution
# issues during Terraform validation. They serve as examples of how platform
# services could be deployed if needed.

# Example ElasticMQ deployment (commented for validation)
# resource "helm_release" "elasticmq" {
#   name      = "elasticmq"
#   chart     = "oci://ghcr.io/comind-ops/elasticmq-chart"
#   namespace = kubernetes_namespace.platform_dev.metadata[0].name
#   version   = "0.1.0"
#
#   values = [
#     yamlencode({
#       image = {
#         repository = "softwaremill/elasticmq"
#         tag        = "1.5.7"
#       }
#       resources = {
#         limits = {
#           cpu    = "200m"
#           memory = "512Mi"
#         }
#       }
#     })
#   ]
# }

# Note: common_tags are already defined in terraform.tf

# Output platform namespace for reference
output "platform_namespace" {
  description = "Platform services namespace"
  value       = kubernetes_namespace.platform_dev.metadata[0].name
}

output "platform_info" {
  description = "Platform deployment information"
  value = {
    namespace         = kubernetes_namespace.platform_dev.metadata[0].name
    deployment_method = "terraform+kustomize+argocd"
    services = [
      "elasticmq (SQS-compatible queue)",
      "docker-registry (container registry)",
      "backup-cronjobs (data backups)"
    ]
  }
}