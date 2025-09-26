# ====================================================
# KUBERNETES NAMESPACES
# ====================================================

# Create namespaces using Kubernetes provider
resource "kubernetes_namespace" "platform_dev" {
  metadata {
    name = "platform-dev"
    labels = {
      "app.kubernetes.io/name" = "platform"
      "app.kubernetes.io/instance" = "dev"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  depends_on = [module.eks]
}

resource "kubernetes_namespace" "platform_stage" {
  metadata {
    name = "platform-stage"
    labels = {
      "app.kubernetes.io/name" = "platform"
      "app.kubernetes.io/instance" = "stage"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  depends_on = [module.eks]
}

resource "kubernetes_namespace" "platform_prod" {
  metadata {
    name = "platform-prod"
    labels = {
      "app.kubernetes.io/name" = "platform"
      "app.kubernetes.io/instance" = "prod"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  depends_on = [module.eks]
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      "app.kubernetes.io/name" = "argocd"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  depends_on = [module.eks]
}

resource "kubernetes_namespace" "sealed_secrets" {
  metadata {
    name = "sealed-secrets"
    labels = {
      "app.kubernetes.io/name" = "sealed-secrets"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  depends_on = [module.eks]
}

# ====================================================
# ARGOCD
# ====================================================

# Install ArgoCD using Helm provider
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.49.0"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  
  values = [
    templatefile("${path.module}/../../templates/argocd-values.yaml", {
      environment = var.environment
      domain      = "argocd.${var.environment}.comind.pro"
    })
  ]
  
  depends_on = [kubernetes_namespace.argocd]
}

# ====================================================
# SEALED SECRETS
# ====================================================

# Install Sealed Secrets using Helm provider
resource "helm_release" "sealed_secrets" {
  name       = "sealed-secrets"
  repository = "https://bitnami-labs.github.io/sealed-secrets"
  chart      = "sealed-secrets"
  version    = "2.13.2"
  namespace  = kubernetes_namespace.sealed_secrets.metadata[0].name
  
  values = [
    yamlencode({
      commandArgs = ["--update-status"]
      fullnameOverride = "sealed-secrets-controller"
    })
  ]
  
  depends_on = [kubernetes_namespace.sealed_secrets]
}
