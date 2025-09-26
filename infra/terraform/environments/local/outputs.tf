# Outputs for local environment

output "cluster_name" {
  description = "Name of the k3d cluster"
  value       = var.cluster_name
}

output "cluster_context" {
  description = "Kubernetes context name"
  value       = "k3d-${var.cluster_name}"
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = "https://0.0.0.0:${var.cluster_port}"
}

output "ingress_endpoints" {
  description = "Ingress controller endpoints"
  value = {
    http  = "http://127.0.0.1:${var.ingress_http_port}"
    https = "https://127.0.0.1:${var.ingress_https_port}"
  }
}

output "argocd_endpoint" {
  description = "ArgoCD web UI endpoint"
  value       = "http://argocd-${var.environment}.127.0.0.1.nip.io:${var.ingress_http_port}"
}

output "argocd_credentials" {
  description = "ArgoCD admin credentials"
  value = {
    username = "admin"
    password = "Use 'kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d' to get password"
  }
  sensitive  = true
  depends_on = [helm_release.argocd]
}

output "registry_endpoint" {
  description = "Local docker registry endpoint"
  value       = "localhost:${var.registry_port}"
}

output "namespaces_created" {
  description = "List of namespaces created by Terraform"
  value       = ["platform-dev", "argocd", "sealed-secrets", "metallb-system", "ingress-nginx"]
}

output "external_services_status" {
  description = "Status of external services (PostgreSQL, MinIO)"
  value = {
    postgres_status = data.external.external_services_check.result["postgres_status"]
    postgres_health = data.external.external_services_check.result["postgres_health"]
    minio_status    = data.external.external_services_check.result["minio_status"]
    minio_health    = data.external.external_services_check.result["minio_health"]
    services_ready  = data.external.external_services_check.result["services_ready"]
  }
}

output "environment_type" {
  description = "Environment type"
  value       = "local"
}
