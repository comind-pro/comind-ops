# Security Module - RBAC and service accounts

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# Service Account
resource "kubernetes_service_account" "app" {
  count = var.security_config.create_service_account ? 1 : 0
  
  metadata {
    name      = var.app_name
    namespace = var.kubernetes_namespace
  }
}

# Role for application
resource "kubernetes_role" "app" {
  count = var.security_config.create_rbac ? 1 : 0
  
  metadata {
    name      = var.app_name
    namespace = var.kubernetes_namespace
  }
  
  rule {
    api_groups = [""]
    resources  = ["secrets", "configmaps"]
    verbs      = ["get", "list"]
  }
}

# RoleBinding
resource "kubernetes_role_binding" "app" {
  count = var.security_config.create_rbac ? 1 : 0
  
  metadata {
    name      = var.app_name
    namespace = var.kubernetes_namespace
  }
  
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.app[0].metadata[0].name
  }
  
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.app[0].metadata[0].name
    namespace = var.kubernetes_namespace
  }
}
