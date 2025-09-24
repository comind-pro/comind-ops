output "service_account_name" {
  value = var.security_config.create_service_account ? kubernetes_service_account.app[0].metadata[0].name : ""
}
