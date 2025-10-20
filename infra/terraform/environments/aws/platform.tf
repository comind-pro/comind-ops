# ====================================================
# KUBERNETES NAMESPACES
# ====================================================

# Create namespaces using Kubernetes provider
resource "kubernetes_namespace" "platform_dev" {
  metadata {
    name = "platform-dev"
    labels = {
      "app.kubernetes.io/name"       = "platform"
      "app.kubernetes.io/instance"   = "dev"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_namespace" "platform_stage" {
  metadata {
    name = "platform-stage"
    labels = {
      "app.kubernetes.io/name"       = "platform"
      "app.kubernetes.io/instance"   = "stage"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_namespace" "platform_prod" {
  metadata {
    name = "platform-prod"
    labels = {
      "app.kubernetes.io/name"       = "platform"
      "app.kubernetes.io/instance"   = "prod"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      "app.kubernetes.io/name"       = "argocd"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_namespace" "sealed_secrets" {
  metadata {
    name = "sealed-secrets"
    labels = {
      "app.kubernetes.io/name"       = "sealed-secrets"
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
      repo_url    = var.repo_url
      repo_name   = "comind-ops"
      repo_server_volumes = var.repo_type == "private" ? jsonencode([
        {
          name = "ssh-keys"
          secret = {
            secretName  = "argocd-repo-server-ssh-keys"
            defaultMode = 0600
          }
        }
      ]) : "[]"
      repo_server_volume_mounts = var.repo_type == "private" ? jsonencode([
        {
          name      = "ssh-keys"
          mountPath = "/app/config/ssh"
          readOnly  = true
        }
      ]) : "[]"
    })
  ]

  depends_on = [kubernetes_namespace.argocd]
}

# ArgoCD Repository Secret for Private GitHub Access (conditional)
resource "kubernetes_secret" "argocd_repo_credentials" {
  count = var.repo_type == "private" ? 1 : 0
  metadata {
    name      = "argocd-repo-credentials"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "argocd"
      "app.kubernetes.io/component" = "repository"
      "app.kubernetes.io/part-of"   = "comind-ops-platform"
    }
  }

  type = "Opaque"

  data = {
    type     = base64encode("git")
    url      = base64encode(var.repo_url)
    username = base64encode(var.github_username)
    password = base64encode(var.github_token)
  }

  depends_on = [kubernetes_namespace.argocd]
}

# ArgoCD Repository Server SSH Keys Secret (conditional)
resource "kubernetes_secret" "argocd_repo_server_ssh_keys" {
  count = var.repo_type == "private" ? 1 : 0
  metadata {
    name      = "argocd-repo-server-ssh-keys"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "argocd"
      "app.kubernetes.io/component" = "repository-server"
      "app.kubernetes.io/part-of"   = "comind-ops-platform"
    }
  }

  type = "Opaque"

  data = {
    ssh_known_hosts = base64encode(<<-EOT
      github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
      github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6Xo5JNt0v84cbhTk5u8He8kSZaGTZKguTq8iXM=
    EOT
    )
    id_ed25519 = base64encode(var.github_ssh_private_key)
  }

  depends_on = [kubernetes_namespace.argocd]
}

# ArgoCD Project Configuration
resource "kubernetes_manifest" "argocd_project" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = "comind-ops-platform"
      namespace = kubernetes_namespace.argocd.metadata[0].name
      labels = {
        "app.kubernetes.io/name"      = "argocd"
        "app.kubernetes.io/component" = "project"
        "app.kubernetes.io/part-of"   = "comind-ops-platform"
      }
    }
    spec = {
      description = "ComindOps Platform Project"
      sourceRepos = [
        var.repo_url,
        "https://github.com/comind-pro/*"
      ]
      destinations = [
        {
          namespace = "*"
          server    = "https://kubernetes.default.svc"
        },
        {
          namespace = "platform-*"
          server    = "https://kubernetes.default.svc"
        },
        {
          namespace = "*-dev"
          server    = "https://kubernetes.default.svc"
        },
        {
          namespace = "*-stage"
          server    = "https://kubernetes.default.svc"
        },
        {
          namespace = "*-prod"
          server    = "https://kubernetes.default.svc"
        }
      ]
      clusterResourceWhitelist = [
        {
          group = ""
          kind  = "Namespace"
        },
        {
          group = ""
          kind  = "Node"
        },
        {
          group = ""
          kind  = "PersistentVolume"
        },
        {
          group = "apiextensions.k8s.io"
          kind  = "CustomResourceDefinition"
        },
        {
          group = "argoproj.io"
          kind  = "Application"
        },
        {
          group = "argoproj.io"
          kind  = "AppProject"
        }
      ]
      namespaceResourceWhitelist = [
        {
          group = ""
          kind  = "*"
        },
        {
          group = "apps"
          kind  = "*"
        },
        {
          group = "extensions"
          kind  = "*"
        },
        {
          group = "networking.k8s.io"
          kind  = "*"
        },
        {
          group = "autoscaling"
          kind  = "*"
        },
        {
          group = "batch"
          kind  = "*"
        },
        {
          group = "rbac.authorization.k8s.io"
          kind  = "*"
        },
        {
          group = "policy"
          kind  = "*"
        },
        {
          group = "monitoring.coreos.com"
          kind  = "*"
        },
        {
          group = "bitnami.com"
          kind  = "*"
        },
        {
          group = "metallb.io"
          kind  = "*"
        },
        {
          group = "sealed-secrets"
          kind  = "*"
        }
      ]
    }
  }

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
      commandArgs      = ["--update-status"]
      fullnameOverride = "sealed-secrets-controller"
    })
  ]

  depends_on = [kubernetes_namespace.sealed_secrets]
}
