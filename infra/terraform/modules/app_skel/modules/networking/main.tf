# Networking Module - Ingress and DNS configuration

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# Kubernetes Ingress
resource "kubernetes_ingress_v1" "app" {
  count = var.networking_config.ingress_enabled ? 1 : 0

  metadata {
    name      = "${var.app_name}-ingress"
    namespace = var.kubernetes_namespace
    annotations = {
      "kubernetes.io/ingress.class"              = var.cluster_type == "local" ? var.networking_config.local_ingress_class : "alb"
      "nginx.ingress.kubernetes.io/ssl-redirect" = var.cluster_type == "local" ? "false" : "true"
    }
  }

  spec {
    rule {
      host = var.cluster_type == "local" ? "${var.app_name}.${var.environment}.${var.networking_config.local_domain}" : "${var.networking_config.subdomain}.${var.networking_config.domain_name}"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = var.app_name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
