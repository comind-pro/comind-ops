output "service_monitor_name" {
  value = var.monitoring_config.prometheus_enabled ? "${var.app_name}-metrics" : ""
}
