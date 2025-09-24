# Outputs for core infrastructure

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
  value       = "http://argocd.${var.environment}.127.0.0.1.nip.io:${var.ingress_http_port}"
}

output "argocd_credentials" {
  description = "ArgoCD admin credentials"
  value = {
    username = "admin"
    password = data.external.argocd_password.result.password
  }
  sensitive = true
}

output "registry_endpoint" {
  description = "Local docker registry endpoint"
  value       = "localhost:${var.registry_port}"
}

output "namespaces_created" {
  description = "List of namespaces created"
  value       = keys(kubernetes_namespace.platform_namespaces)
}
