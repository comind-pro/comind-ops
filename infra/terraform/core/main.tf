terraform {
  required_version = ">= 1.0"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
  }
}


# Providers
provider "docker" {}

# K3d cluster creation using docker exec commands
resource "null_resource" "k3d_cluster" {
  triggers = {
    cluster_name = var.cluster_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Check if cluster already exists
      if k3d cluster list | grep -q "${var.cluster_name}"; then
        echo "Cluster ${var.cluster_name} already exists, skipping creation"
      else
        echo "Creating k3d cluster ${var.cluster_name}..."
        k3d cluster create ${var.cluster_name} \
          --api-port ${var.cluster_port} \
          --port "${var.ingress_http_port}:80@loadbalancer" \
          --port "${var.ingress_https_port}:443@loadbalancer" \
          --port "${var.registry_port}:5000@server:0" \
          --k3s-arg "--disable=traefik@server:0" \
          --k3s-arg "--disable=servicelb@server:0" \
          --agents 2 \
          --wait
        
        # Wait for cluster to be ready
        timeout=300
        while [ $timeout -gt 0 ]; do
          if kubectl cluster-info --context k3d-${var.cluster_name} >/dev/null 2>&1; then
            echo "Cluster is ready"
            break
          fi
          echo "Waiting for cluster to be ready... ($timeout seconds left)"
          sleep 10
          timeout=$((timeout - 10))
        done
        
        if [ $timeout -le 0 ]; then
          echo "Cluster failed to become ready in time"
          exit 1
        fi
      fi
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "k3d cluster delete ${self.triggers.cluster_name} || true"
  }
}

# Set kubeconfig context
resource "null_resource" "kubeconfig" {
  depends_on = [null_resource.k3d_cluster]

  provisioner "local-exec" {
    command = "kubectl config use-context k3d-${var.cluster_name}"
  }
}

# Configure providers to use k3d cluster
# In CI environments, skip provider configuration if kubeconfig doesn't exist
provider "kubernetes" {
  # Only configure if not in CI or if kubeconfig exists
  config_path    = fileexists(pathexpand("~/.kube/config")) ? "~/.kube/config" : null
  config_context = fileexists(pathexpand("~/.kube/config")) ? "k3d-${var.cluster_name}" : null
}

provider "helm" {
  kubernetes {
    # Only configure if not in CI or if kubeconfig exists  
    config_path    = fileexists(pathexpand("~/.kube/config")) ? "~/.kube/config" : null
    config_context = fileexists(pathexpand("~/.kube/config")) ? "k3d-${var.cluster_name}" : null
  }
}

# Create namespaces
resource "kubernetes_namespace" "platform_namespaces" {
  for_each = toset(["platform-dev", "platform-stage", "platform-prod", "argocd", "sealed-secrets", "metallb-system"])

  metadata {
    name = each.key
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [null_resource.kubeconfig]
}

# MetalLB for local load balancing
resource "helm_release" "metallb" {
  name       = "metallb"
  repository = "https://metallb.github.io/metallb"
  chart      = "metallb"
  version    = "0.13.12"
  namespace  = "metallb-system"

  depends_on = [kubernetes_namespace.platform_namespaces]
}

# MetalLB IP Address Pool Configuration
resource "kubernetes_manifest" "metallb_ippool" {
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "IPAddressPool"
    metadata = {
      name      = "default-pool"
      namespace = "metallb-system"
    }
    spec = {
      addresses = ["172.18.255.200-172.18.255.250"]
    }
  }

  depends_on = [helm_release.metallb]
}

# MetalLB L2 Advertisement
resource "kubernetes_manifest" "metallb_l2advertisement" {
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "L2Advertisement"
    metadata = {
      name      = "default"
      namespace = "metallb-system"
    }
    spec = {
      ipAddressPools = ["default-pool"]
    }
  }

  depends_on = [helm_release.metallb]
}

# Ingress Nginx Controller
resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.8.3"
  namespace  = "ingress-nginx"

  create_namespace = true

  values = [
    yamlencode({
      controller = {
        service = {
          type = "LoadBalancer"
          annotations = {
            "metallb.universe.tf/address-pool" = "default-pool"
          }
        }
        ingressClassResource = {
          default = true
        }
        config = {
          use-forwarded-headers      = "true"
          compute-full-forwarded-for = "true"
        }
      }
    })
  ]

  depends_on = [helm_release.metallb, kubernetes_manifest.metallb_ippool]
}

# Sealed Secrets Controller
resource "helm_release" "sealed_secrets" {
  name       = "sealed-secrets"
  repository = "https://bitnami-labs.github.io/sealed-secrets"
  chart      = "sealed-secrets"
  version    = "2.13.2"
  namespace  = "sealed-secrets"

  values = [
    yamlencode({
      fullnameOverride = "sealed-secrets-controller"
      commandArgs = [
        "--update-status"
      ]
    })
  ]

  depends_on = [kubernetes_namespace.platform_namespaces]
}

# ArgoCD Installation
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.51.6"
  namespace  = "argocd"

  values = [
    yamlencode({
      global = {
        domain = "argocd.${var.environment}.127.0.0.1.nip.io"
      }

      configs = {
        params = {
          "server.insecure" = true
        }
        cm = {
          "application.instanceLabelKey" = "argocd.argoproj.io/instance"
        }
      }

      server = {
        ingress = {
          enabled          = true
          ingressClassName = "nginx"
          annotations = {
            "nginx.ingress.kubernetes.io/ssl-redirect"     = "false"
            "nginx.ingress.kubernetes.io/backend-protocol" = "HTTP"
          }
          hosts = [
            {
              host = "argocd.${var.environment}.127.0.0.1.nip.io"
              paths = [
                {
                  path     = "/"
                  pathType = "Prefix"
                }
              ]
            }
          ]
        }
      }

      applicationSet = {
        enabled = true
      }
    })
  ]

  depends_on = [kubernetes_namespace.platform_namespaces, helm_release.ingress_nginx]
}

# Wait for ArgoCD to be ready
resource "null_resource" "wait_for_argocd" {
  depends_on = [helm_release.argocd]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for ArgoCD to be ready..."
      kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
      kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n argocd
      kubectl wait --for=condition=available --timeout=300s deployment/argocd-dex-server -n argocd
      echo "ArgoCD is ready!"
    EOT
  }
}

# Data sources for outputs
data "external" "argocd_password" {
  depends_on = [null_resource.wait_for_argocd]

  program = ["bash", "-c", <<-EOT
    password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "admin")
    echo "{\"password\": \"$password\"}"
  EOT
  ]
}

