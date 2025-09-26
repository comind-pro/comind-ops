# ====================================================
# KUBERNETES NAMESPACES
# ====================================================

# Create namespaces using Kubernetes provider
resource "kubernetes_namespace" "platform_dev" {
  count = var.cluster_type == "local" ? 1 : 0
  
  metadata {
    name = "platform-dev"
    labels = {
      "app.kubernetes.io/name" = "platform"
      "app.kubernetes.io/instance" = "dev"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  depends_on = [null_resource.kubeconfig_local]
}

resource "kubernetes_namespace" "argocd" {
  count = var.cluster_type == "local" ? 1 : 0
  
  metadata {
    name = "argocd"
    labels = {
      "app.kubernetes.io/name" = "argocd"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  depends_on = [null_resource.kubeconfig_local]
}

resource "kubernetes_namespace" "sealed_secrets" {
  count = var.cluster_type == "local" ? 1 : 0
  
  metadata {
    name = "sealed-secrets"
    labels = {
      "app.kubernetes.io/name" = "sealed-secrets"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  depends_on = [null_resource.kubeconfig_local]
}

resource "kubernetes_namespace" "metallb_system" {
  count = var.cluster_type == "local" ? 1 : 0
  
  metadata {
    name = "metallb-system"
    labels = {
      "app.kubernetes.io/name" = "metallb"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  depends_on = [null_resource.kubeconfig_local]
}

resource "kubernetes_namespace" "ingress_nginx" {
  count = var.cluster_type == "local" ? 1 : 0
  
  metadata {
    name = "ingress-nginx"
    labels = {
      "app.kubernetes.io/name" = "ingress-nginx"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  depends_on = [null_resource.kubeconfig_local]
}

# ====================================================
# METALLB LOAD BALANCER
# ====================================================

# Install MetalLB using Helm provider
resource "helm_release" "metallb" {
  count = var.cluster_type == "local" ? 1 : 0
  
  name       = "metallb"
  repository = "https://metallb.github.io/metallb"
  chart      = "metallb"
  version    = "0.13.12"
  namespace  = kubernetes_namespace.metallb_system[0].metadata[0].name
  
  depends_on = [kubernetes_namespace.metallb_system]
}

# Configure MetalLB IP pool
resource "kubernetes_manifest" "metallb_ip_pool" {
  count = var.cluster_type == "local" ? 1 : 0
  
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "IPAddressPool"
    metadata = {
      name      = "default-pool"
      namespace = "metallb-system"
    }
    spec = {
      addresses = [var.metallb_ip_range]
    }
  }
  
  depends_on = [helm_release.metallb]
}

resource "kubernetes_manifest" "metallb_l2_advertisement" {
  count = var.cluster_type == "local" ? 1 : 0
  
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "L2Advertisement"
    metadata = {
      name      = "default-l2advertisement"
      namespace = "metallb-system"
    }
    spec = {
      ipAddressPools = ["default-pool"]
    }
  }
  
  depends_on = [kubernetes_manifest.metallb_ip_pool]
}

# ====================================================
# INGRESS NGINX
# ====================================================

# Install Ingress Nginx using Helm provider
resource "helm_release" "ingress_nginx" {
  count = var.cluster_type == "local" ? 1 : 0
  
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.8.3"
  namespace  = kubernetes_namespace.ingress_nginx[0].metadata[0].name
  
  values = [
    yamlencode({
      controller = {
        service = {
          type = "LoadBalancer"
          externalTrafficPolicy = "Local"
        }
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = false
          }
          prometheusRule = {
            enabled = false
          }
        }
        admissionWebhooks = {
          patch = {
            nodeSelector = {
              "kubernetes.io/os" = "linux"
            }
          }
        }
        nodeSelector = {
          "kubernetes.io/os" = "linux"
        }
      }
      defaultBackend = {
        nodeSelector = {
          "kubernetes.io/os" = "linux"
        }
      }
    })
  ]
  
  depends_on = [kubernetes_namespace.ingress_nginx, kubernetes_manifest.metallb_l2_advertisement]
}

# ====================================================
# SEALED SECRETS
# ====================================================

# Install Sealed Secrets using Helm provider
resource "helm_release" "sealed_secrets" {
  count = var.cluster_type == "local" ? 1 : 0
  
  name       = "sealed-secrets"
  repository = "https://bitnami-labs.github.io/sealed-secrets"
  chart      = "sealed-secrets"
  version    = "2.13.2"
  namespace  = kubernetes_namespace.sealed_secrets[0].metadata[0].name
  
  values = [
    yamlencode({
      commandArgs = ["--update-status"]
      fullnameOverride = "sealed-secrets-controller"
    })
  ]
  
  depends_on = [kubernetes_namespace.sealed_secrets]
}

# ====================================================
# ARGOCD
# ====================================================

# Install ArgoCD using Helm provider
resource "helm_release" "argocd" {
  count = var.cluster_type == "local" ? 1 : 0
  
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.49.0"
  namespace  = kubernetes_namespace.argocd[0].metadata[0].name
  
  values = [
    templatefile("${path.module}/../../templates/argocd-values.yaml", {
      environment = var.environment
      domain      = "argocd.${var.environment}.127.0.0.1.nip.io"
    })
  ]
  
  depends_on = [kubernetes_namespace.argocd]
}
