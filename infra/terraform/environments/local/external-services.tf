# ====================================================
# EXTERNAL SERVICES VALIDATION
# ====================================================

# Data source to check external services
data "external" "external_services_check" {
  program = ["${path.module}/../../scripts/check-external-services.sh"]
}

# External services status output
resource "null_resource" "external_services_status" {
  count = var.cluster_type == "local" ? 1 : 0

  provisioner "local-exec" {
    command = templatefile("${path.module}/../../scripts/external-services-status.sh", {
      POSTGRES_STATUS = data.external.external_services_check.result["postgres_status"]
      MINIO_STATUS = data.external.external_services_check.result["minio_status"]
      POSTGRES_HEALTH = data.external.external_services_check.result["postgres_health"]
      MINIO_HEALTH = data.external.external_services_check.result["minio_health"]
      SERVICES_READY = data.external.external_services_check.result["services_ready"]
    })
  }
}
