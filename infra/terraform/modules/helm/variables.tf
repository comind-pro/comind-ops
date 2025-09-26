variable "cluster_type" {
  description = "Type of cluster (local, aws)"
  type        = string
}

variable "install_metallb_script" {
  description = "Script to install MetalLB"
  type        = string
}

variable "metallb_config_script" {
  description = "Script to configure MetalLB"
  type        = string
}

variable "install_ingress_nginx_script" {
  description = "Script to install Ingress Nginx"
  type        = string
}

variable "install_sealed_secrets_script" {
  description = "Script to install Sealed Secrets"
  type        = string
}

variable "install_argocd_script" {
  description = "Script to install ArgoCD"
  type        = string
}

variable "wait_for_argocd_script" {
  description = "Script to wait for ArgoCD"
  type        = string
}
