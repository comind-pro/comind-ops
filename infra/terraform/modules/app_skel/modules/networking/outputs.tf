output "ingress_hostname" {
  value = var.cluster_type == "local" ? "${var.app_name}.${var.environment}.${var.networking_config.local_domain}" : "${var.networking_config.subdomain}.${var.networking_config.domain_name}"
}
