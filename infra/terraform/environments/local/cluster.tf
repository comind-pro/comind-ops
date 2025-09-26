# ====================================================
# LOCAL INFRASTRUCTURE (K3D CLUSTER)
# ====================================================

# K3d cluster creation using Docker provider
resource "docker_network" "k3d_network" {
  count = var.cluster_type == "local" ? 1 : 0
  name  = "k3d-comind-ops-network"

  ipam_config {
    subnet = "172.18.0.0/16"
  }
}

# Create k3d cluster using local-exec (no official k3d provider available)
resource "null_resource" "k3d_cluster" {
  count = var.cluster_type == "local" ? 1 : 0

  triggers = {
    cluster_name = var.cluster_name
    environment  = var.environment
    cluster_port = var.cluster_port
    http_port    = var.ingress_http_port
    https_port   = var.ingress_https_port
  }

  provisioner "local-exec" {
    command = templatefile("${path.module}/../../scripts/create-k3d-cluster.sh", {
      CLUSTER_NAME       = var.cluster_name
      ENVIRONMENT        = var.environment
      CLUSTER_TYPE       = var.cluster_type
      CLUSTER_PORT       = var.cluster_port
      INGRESS_HTTP_PORT  = var.ingress_http_port
      INGRESS_HTTPS_PORT = var.ingress_https_port
    })
  }

  provisioner "local-exec" {
    when    = destroy
    command = "k3d cluster delete ${self.triggers.cluster_name} || true"
  }

  depends_on = [docker_network.k3d_network]
}

# Set kubeconfig context
resource "null_resource" "kubeconfig_local" {
  count      = var.cluster_type == "local" ? 1 : 0
  depends_on = [null_resource.k3d_cluster]

  provisioner "local-exec" {
    command = "kubectl config use-context k3d-${var.cluster_name}"
  }
}
