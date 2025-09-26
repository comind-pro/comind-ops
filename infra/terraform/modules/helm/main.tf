# Helm Module - Manages Helm chart installations
terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Install MetalLB
resource "null_resource" "install_metallb" {
  count = var.cluster_type == "local" ? 1 : 0

  provisioner "local-exec" {
    command = var.install_metallb_script
  }
}

# Configure MetalLB
resource "null_resource" "metallb_config" {
  count = var.cluster_type == "local" ? 1 : 0
  depends_on = [null_resource.install_metallb]

  provisioner "local-exec" {
    command = var.metallb_config_script
  }
}

# Install Ingress Nginx
resource "null_resource" "install_ingress_nginx" {
  count = var.cluster_type == "local" ? 1 : 0

  provisioner "local-exec" {
    command = var.install_ingress_nginx_script
  }
}

# Install Sealed Secrets
resource "null_resource" "install_sealed_secrets" {
  count = var.cluster_type == "local" ? 1 : 0

  provisioner "local-exec" {
    command = var.install_sealed_secrets_script
  }
}

# Install ArgoCD
resource "null_resource" "install_argocd" {
  count = var.cluster_type == "local" ? 1 : 0

  provisioner "local-exec" {
    command = var.install_argocd_script
  }
}

# Wait for ArgoCD
resource "null_resource" "wait_for_argocd" {
  count = var.cluster_type == "local" ? 1 : 0
  depends_on = [null_resource.install_argocd]

  provisioner "local-exec" {
    command = var.wait_for_argocd_script
  }
}
