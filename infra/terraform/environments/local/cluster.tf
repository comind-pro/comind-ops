# ====================================================
# LOCAL INFRASTRUCTURE (K3D CLUSTER)
# ====================================================

# K3d cluster creation using Docker provider
resource "docker_network" "k3d_network" {
  count = var.cluster_type == "local" ? 1 : 0
  name = "k3d-comind-ops-network"
  
  ipam_config {
    subnet = "172.18.0.0/16"
  }
}

# Create k3d cluster using local-exec (temporary until k3d provider is available)
resource "null_resource" "k3d_cluster" {
  count = var.cluster_type == "local" ? 1 : 0
  
  triggers = {
    cluster_name = var.cluster_name
    environment  = var.environment
  }

  provisioner "local-exec" {
    command = "${path.module}/../../scripts/create-k3d-cluster.sh ${var.cluster_name} ${var.environment} ${var.cluster_type}"
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
