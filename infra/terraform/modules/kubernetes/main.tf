# Kubernetes Module - Manages Kubernetes namespaces and basic resources
terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Create namespaces
resource "null_resource" "create_namespaces" {
  count = var.cluster_type == "local" ? 1 : 0

  provisioner "local-exec" {
    command = var.create_namespaces_script
  }
}
