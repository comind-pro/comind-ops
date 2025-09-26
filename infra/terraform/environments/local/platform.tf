# ====================================================
# LOCALS
# ====================================================

locals {
  # Parse environments from comma-separated string or list
  environments_list = can(tolist(var.environments)) ? tolist(var.environments) : split(",", var.environments)
}

# ====================================================
# KUBERNETES NAMESPACES
# ====================================================

# Create namespaces using Kubernetes provider
resource "kubernetes_namespace" "platform_dev" {
  count = var.cluster_type == "local" ? 1 : 0
  
  metadata {
    name = var.multi_environment ? "${var.namespace_prefix}-${var.environment}" : "${var.namespace_prefix}-${var.environment}"
    labels = {
      "app.kubernetes.io/name" = "platform"
      "app.kubernetes.io/instance" = var.environment
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  depends_on = [null_resource.kubeconfig_local]
}

# Create namespaces for multiple environments if enabled
resource "kubernetes_namespace" "platform_multi" {
  for_each = var.cluster_type == "local" && var.multi_environment ? toset(local.environments_list) : toset([])
  
  metadata {
    name = "${var.namespace_prefix}-${each.key}"
    labels = {
      "app.kubernetes.io/name" = "platform"
      "app.kubernetes.io/instance" = each.key
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
      domain      = "argocd.${var.environment}.${var.domain_suffix}"
      repo_url    = var.repo_url
      repo_name   = "comind-ops"
      multi_environment = var.multi_environment
      environments = jsonencode(local.environments_list)
      namespace_prefix = var.namespace_prefix
      repo_server_volumes = var.repo_type == "private" ? jsonencode([
        {
          name = "ssh-keys"
          secret = {
            secretName = "argocd-repo-server-ssh-keys"
            defaultMode = 0600
          }
        }
      ]) : "[]"
      repo_server_volume_mounts = var.repo_type == "private" ? jsonencode([
        {
          name = "ssh-keys"
          mountPath = "/app/config/ssh"
          readOnly = true
        }
      ]) : "[]"
    })
  ]
  
  depends_on = [kubernetes_namespace.argocd]
}

# ArgoCD Repository Secret for Private GitHub Access (conditional)
resource "kubernetes_secret" "argocd_repo_credentials" {
  count = var.cluster_type == "local" && var.repo_type == "private" ? 1 : 0
  
  metadata {
    name      = "argocd-repo-credentials"
    namespace = kubernetes_namespace.argocd[0].metadata[0].name
    labels = {
      "app.kubernetes.io/name" = "argocd"
      "app.kubernetes.io/component" = "repository"
      "app.kubernetes.io/part-of" = "comind-ops-platform"
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
  count = var.cluster_type == "local" && var.repo_type == "private" ? 1 : 0
  
  metadata {
    name      = "argocd-repo-server-ssh-keys"
    namespace = kubernetes_namespace.argocd[0].metadata[0].name
    labels = {
      "app.kubernetes.io/name" = "argocd"
      "app.kubernetes.io/component" = "repository-server"
      "app.kubernetes.io/part-of" = "comind-ops-platform"
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
  count = var.cluster_type == "local" ? 1 : 0
  
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = "comind-ops-platform"
      namespace = kubernetes_namespace.argocd[0].metadata[0].name
      labels = {
        "app.kubernetes.io/name" = "argocd"
        "app.kubernetes.io/component" = "project"
        "app.kubernetes.io/part-of" = "comind-ops-platform"
      }
    }
    spec = {
      description = "ComindOps Platform Project"
      sourceRepos = [
        var.repo_url,
        "https://github.com/comind-pro/*"
      ]
      destinations = var.multi_environment ? concat([
        {
          namespace = "*"
          server    = "https://kubernetes.default.svc"
        }
      ], [
        for env in local.environments_list : {
          namespace = "${var.namespace_prefix}-${env}"
          server    = "https://kubernetes.default.svc"
        }
      ]) : [
        {
          namespace = "*"
          server    = "https://kubernetes.default.svc"
        },
        {
          namespace = "${var.namespace_prefix}-${var.environment}"
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
