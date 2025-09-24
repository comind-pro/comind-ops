# Monitoring Module - ServiceMonitor and dashboards

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# ServiceMonitor for Prometheus
resource "kubernetes_manifest" "service_monitor" {
  count = var.monitoring_config.prometheus_enabled ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "${var.app_name}-metrics"
      namespace = var.kubernetes_namespace
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = var.app_name
        }
      }
      endpoints = [{
        port     = "metrics"
        interval = "30s"
      }]
    }
  }
}
