# Cluster Module - Manages k3d cluster creation and configuration
terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# K3d cluster creation
resource "null_resource" "k3d_cluster" {
  count = var.cluster_type == "local" ? 1 : 0
  triggers = {
    cluster_name = var.cluster_name
  }

  provisioner "local-exec" {
    command = var.create_cluster_script
  }

  provisioner "local-exec" {
    when    = destroy
    command = "k3d cluster delete ${self.triggers.cluster_name} || true"
  }
}

# Set kubeconfig context for local k3d cluster
resource "null_resource" "kubeconfig_local" {
  count = var.cluster_type == "local" ? 1 : 0
  depends_on = [null_resource.k3d_cluster]

  provisioner "local-exec" {
    command = "kubectl config use-context k3d-${var.cluster_name}"
  }
}
