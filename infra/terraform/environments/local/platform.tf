# ====================================================
# LOCALS
# ====================================================

locals {
  # Parse environments from comma-separated string or list
  environments_list = can(tolist(var.environments)) ? tolist(var.environments) : split(",", tostring(var.environments))
}

# ====================================================
# KUBERNETES NAMESPACES
# ====================================================

# Create namespaces using kubectl
resource "null_resource" "create_namespaces" {
  count = var.cluster_type == "local" ? 1 : 0
  
  depends_on = [null_resource.kubeconfig_local]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Creating Kubernetes namespaces..."
      
      # Create platform namespaces
      %{ for env in local.environments_list ~}
      kubectl create namespace ${var.namespace_prefix}-${env} --dry-run=client -o yaml | kubectl apply -f -
      kubectl label namespace ${var.namespace_prefix}-${env} app.kubernetes.io/name=platform app.kubernetes.io/part-of=comind-ops-platform environment=${env} --overwrite
      %{ endfor ~}
      
      # Create MetalLB namespace
      kubectl create namespace metallb-system --dry-run=client -o yaml | kubectl apply -f -
      kubectl label namespace metallb-system app.kubernetes.io/name=metallb app.kubernetes.io/part-of=comind-ops-platform --overwrite
      
      # Create Ingress Nginx namespace
      kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -
      kubectl label namespace ingress-nginx app.kubernetes.io/name=ingress-nginx app.kubernetes.io/part-of=comind-ops-platform --overwrite
      
      # Create ArgoCD namespace
      kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
      kubectl label namespace argocd app.kubernetes.io/name=argocd app.kubernetes.io/part-of=comind-ops-platform --overwrite
      
      # Create Sealed Secrets namespace
      kubectl create namespace sealed-secrets --dry-run=client -o yaml | kubectl apply -f -
      kubectl label namespace sealed-secrets app.kubernetes.io/name=sealed-secrets app.kubernetes.io/part-of=comind-ops-platform --overwrite
      
      echo "Kubernetes namespaces created successfully"
    EOT
  }
  
  triggers = {
    environments = join(",", local.environments_list)
    namespace_prefix = var.namespace_prefix
  }
}

# Sealed Secrets namespace is created in the create_namespaces resource above

# MetalLB namespace is created in the create_namespaces resource above

# Ingress Nginx namespace is created in the create_namespaces resource above

# ====================================================
# METALLB LOAD BALANCER
# ====================================================

# Install MetalLB using Helm CLI
resource "null_resource" "install_metallb" {
  count = var.cluster_type == "local" ? 1 : 0
  
  depends_on = [null_resource.create_namespaces]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Installing MetalLB..."
      
      # Add MetalLB Helm repository
      helm repo add metallb https://metallb.github.io/metallb
      helm repo update
      
      # Install MetalLB
      helm upgrade --install metallb metallb/metallb \
        --version 0.13.12 \
        --namespace metallb-system \
        --wait --timeout=5m
      
      echo "MetalLB installed successfully"
    EOT
  }
  
  triggers = {
    namespaces_created = null_resource.create_namespaces[0].id
  }
}

# Configure MetalLB IP pool
resource "null_resource" "metallb_ip_pool" {
  count = var.cluster_type == "local" ? 1 : 0
  
  depends_on = [null_resource.kubeconfig_local, null_resource.install_metallb]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Creating MetalLB IP pool..."
      kubectl apply -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - ${var.metallb_ip_range}
EOF
      echo "MetalLB IP pool created successfully"
    EOT
  }
  
  triggers = {
    metallb_installed = null_resource.install_metallb[0].id
    ip_range = var.metallb_ip_range
  }
}

resource "null_resource" "metallb_l2_advertisement" {
  count = var.cluster_type == "local" ? 1 : 0
  
  depends_on = [null_resource.metallb_ip_pool]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Creating MetalLB L2 Advertisement..."
      kubectl apply -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default-l2advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
EOF
      echo "MetalLB L2 Advertisement created successfully"
    EOT
  }
  
  triggers = {
    metallb_ip_pool = null_resource.metallb_ip_pool[0].id
  }
}

# ====================================================
# INGRESS NGINX
# ====================================================

# Install Ingress Nginx using Helm CLI
resource "null_resource" "install_ingress_nginx" {
  count = var.cluster_type == "local" ? 1 : 0
  
  depends_on = [null_resource.create_namespaces, null_resource.metallb_l2_advertisement]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Installing Ingress Nginx..."
      
      # Add Ingress Nginx Helm repository
      helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
      helm repo update
      
      # Install Ingress Nginx
      helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --version 4.8.3 \
        --namespace ingress-nginx \
        --set controller.service.type=LoadBalancer \
        --set controller.service.externalTrafficPolicy=Local \
        --set controller.metrics.enabled=true \
        --set controller.metrics.serviceMonitor.enabled=false \
        --set controller.metrics.prometheusRule.enabled=false \
        --set controller.admissionWebhooks.patch.nodeSelector.kubernetes\\.io/os=linux \
        --set controller.nodeSelector.kubernetes\\.io/os=linux \
        --set defaultBackend.nodeSelector.kubernetes\\.io/os=linux \
        --wait --timeout=5m
      
      echo "Ingress Nginx installed successfully"
    EOT
  }
  
  triggers = {
    metallb_configured = null_resource.metallb_l2_advertisement[0].id
  }
}

# Disable Ingress Nginx admission webhook to avoid certificate issues in k3d
resource "null_resource" "disable_ingress_nginx_webhook" {
  count = var.cluster_type == "local" ? 1 : 0
  
  depends_on = [null_resource.install_ingress_nginx]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Disabling Ingress Nginx admission webhook for k3d compatibility..."
      kubectl delete validatingwebhookconfigurations ingress-nginx-admission --ignore-not-found=true
      echo "Ingress Nginx admission webhook disabled"
    EOT
  }
  
  triggers = {
    ingress_nginx_installed = null_resource.install_ingress_nginx[0].id
  }
}

# Note: Docker image building moved to ArgoCD CI/CD pipeline

# Note: Platform application deployment moved to ArgoCD

# Note: ArgoCD application configuration moved to GitOps

# ====================================================
# SEALED SECRETS
# ====================================================

# Install Sealed Secrets using Helm CLI
resource "null_resource" "install_sealed_secrets" {
  count = var.cluster_type == "local" ? 1 : 0
  
  depends_on = [null_resource.create_namespaces]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Installing Sealed Secrets..."
      
      # Add Sealed Secrets Helm repository
      helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
      helm repo update
      
      # Install Sealed Secrets
      helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
        --version 2.13.2 \
        --namespace sealed-secrets \
        --set commandArgs[0]="--update-status" \
        --set fullnameOverride="sealed-secrets-controller" \
        --wait --timeout=5m
      
      echo "Sealed Secrets installed successfully"
    EOT
  }
  
  triggers = {
    namespaces_created = null_resource.create_namespaces[0].id
  }
}

# ====================================================
# ARGOCD
# ====================================================

# Install ArgoCD using Helm CLI
resource "null_resource" "install_argocd" {
  count = var.cluster_type == "local" ? 1 : 0
  
  depends_on = [null_resource.create_namespaces]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Installing ArgoCD..."
      
      # Use the dedicated ArgoCD installation script
      ENVIRONMENT=${var.environment} ${path.module}/../../scripts/install-argocd.sh
      
      echo "ArgoCD installed successfully"
    EOT
  }
  
  triggers = {
    namespaces_created = null_resource.create_namespaces[0].id
    environment = var.environment
    domain_suffix = var.domain_suffix
    script_version = "2.1"
  }
}

# ArgoCD Repository Secret for Private GitHub Access (conditional)
resource "kubernetes_secret" "argocd_repo_credentials" {
  count = var.cluster_type == "local" && var.repo_type == "private" ? 1 : 0
  
  metadata {
    name      = "argocd-repo-credentials"
    namespace = "argocd"
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
  
  depends_on = [null_resource.create_namespaces]
}

# ArgoCD Repository Server SSH Keys Secret (conditional)
resource "kubernetes_secret" "argocd_repo_server_ssh_keys" {
  count = var.cluster_type == "local" && var.repo_type == "private" ? 1 : 0
  
  metadata {
    name      = "argocd-repo-server-ssh-keys"
    namespace = "argocd"
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
  
  depends_on = [null_resource.create_namespaces]
}

# ArgoCD Project Configuration
resource "null_resource" "argocd_project" {
  count = var.cluster_type == "local" ? 1 : 0
  
  depends_on = [null_resource.kubeconfig_local, null_resource.install_argocd]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Creating ArgoCD project..."
      
      # Wait for ArgoCD to be ready
      kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
      
      # Wait for ArgoCD CRDs to be available
      echo "Waiting for ArgoCD CRDs to be available..."
      kubectl wait --for condition=established --timeout=60s crd/applications.argoproj.io
      kubectl wait --for condition=established --timeout=60s crd/appprojects.argoproj.io
      
      # Create ArgoCD project
      kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: comind-ops-platform
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd
    app.kubernetes.io/component: project
    app.kubernetes.io/part-of: comind-ops-platform
spec:
  description: ComindOps Platform Project
  sourceRepos:
    - ${var.repo_url}
    - https://github.com/comind-pro/*
  destinations:
    - namespace: "*"
      server: https://kubernetes.default.svc
    - namespace: ${var.namespace_prefix}-${var.environment}
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: ""
      kind: Namespace
    - group: ""
      kind: Node
    - group: ""
      kind: PersistentVolume
    - group: apiextensions.k8s.io
      kind: CustomResourceDefinition
    - group: argoproj.io
      kind: Application
    - group: argoproj.io
      kind: AppProject
  namespaceResourceWhitelist:
    - group: ""
      kind: "*"
    - group: apps
      kind: "*"
    - group: extensions
      kind: "*"
    - group: networking.k8s.io
      kind: "*"
    - group: autoscaling
      kind: "*"
    - group: batch
      kind: "*"
    - group: rbac.authorization.k8s.io
      kind: "*"
    - group: policy
      kind: "*"
    - group: monitoring.coreos.com
      kind: "*"
    - group: bitnami.com
      kind: "*"
    - group: metallb.io
      kind: "*"
    - group: sealed-secrets
      kind: "*"
EOF
      
      echo "ArgoCD project created successfully"
    EOT
  }
  
  triggers = {
    argocd_installed = null_resource.install_argocd[0].id
    environment = var.environment
  }
}

# Note: ArgoCD repository configuration moved to GitOps
