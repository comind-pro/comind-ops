# Data sources for cluster information
data "external" "cluster_info" {
  program = ["${path.module}/../../scripts/get-cluster-info.sh"]
}

data "external" "external_services_check" {
  program = ["${path.module}/../../scripts/check-external-services.sh"]
}

# Data source for ArgoCD password
data "external" "argocd_password" {
  count = var.cluster_type == "local" ? 1 : 0
  program = ["${path.module}/../../scripts/get-argocd-password.sh"]
  depends_on = [null_resource.install_argocd]
}
