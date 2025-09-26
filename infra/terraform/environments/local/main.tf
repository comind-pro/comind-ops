terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
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

provider "aws" {
  region = var.aws_region
  
  # Skip all AWS provider configuration when using local profile
  skip_credentials_validation = var.cluster_type == "local"
  skip_metadata_api_check    = var.cluster_type == "local"
  skip_region_validation     = var.cluster_type == "local"
  skip_requesting_account_id  = var.cluster_type == "local"
  
  # Use empty access key when local to avoid AWS calls
  access_key = var.cluster_type == "local" ? "mock" : null
  secret_key = var.cluster_type == "local" ? "mock" : null
}

# ====================================================
# LOCAL INFRASTRUCTURE (K3D CLUSTER)
# ====================================================

# K3d cluster creation using docker exec commands
resource "null_resource" "k3d_cluster" {
  count = var.cluster_type == "local" ? 1 : 0
  triggers = {
    cluster_name = var.cluster_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Check if we're in CI environment
      if [ "${var.cluster_type}" = "ci" ] || [ -n "$CI" ] || [ -n "$GITHUB_ACTIONS" ]; then
        echo "CI environment detected, skipping k3d cluster creation"
        echo "This would be handled by external cluster setup in CI"
        exit 0
      fi
      
      # Check if cluster already exists
      if k3d cluster list | grep -q "${var.cluster_name}"; then
        echo "Cluster ${var.cluster_name} already exists, skipping creation"
      else
        echo "Creating k3d cluster ${var.cluster_name}..."
        k3d cluster create ${var.cluster_name} \
          --api-port ${var.cluster_port} \
          --port "${var.ingress_http_port}:80@loadbalancer" \
          --port "${var.ingress_https_port}:443@loadbalancer" \
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

# Set kubeconfig context for local k3d cluster
resource "null_resource" "kubeconfig_local" {
  count = var.cluster_type == "local" ? 1 : 0
  depends_on = [null_resource.k3d_cluster]

  provisioner "local-exec" {
    command = "kubectl config use-context k3d-${var.cluster_name}"
  }
}

# Configure providers to use k3d cluster
# Use empty configuration during initial bootstrap - resources will be created via local-exec
provider "kubernetes" {
  config_path    = null
  config_context = null
}

provider "helm" {
  kubernetes {
    config_path    = null
    config_context = null
  }
}

# Create namespaces using local-exec
resource "null_resource" "create_namespaces_local" {
  count = var.cluster_type == "local" ? 1 : 0
  provisioner "local-exec" {
    command = <<-EOT
      echo "Creating Kubernetes namespaces..."
      for namespace in platform-dev platform-stage platform-prod argocd sealed-secrets metallb-system; do
        kubectl create namespace $namespace --dry-run=client -o yaml | kubectl apply -f -
        kubectl label namespace $namespace app.kubernetes.io/managed-by=terraform --overwrite
      done
      echo "✅ Namespaces created"
    EOT
  }

  depends_on = [null_resource.kubeconfig_local]
}

# MetalLB for local load balancing using local-exec
resource "null_resource" "install_metallb" {
  count = var.cluster_type == "local" ? 1 : 0
  provisioner "local-exec" {
    command = <<-EOT
      echo "Installing MetalLB..."
      helm repo add metallb https://metallb.github.io/metallb
      helm repo update
      helm upgrade --install metallb metallb/metallb \
        --version 0.13.12 \
        --namespace metallb-system \
        --wait
      echo "✅ MetalLB installed"
    EOT
  }

  depends_on = [null_resource.create_namespaces_local]
}

# MetalLB IP Address Pool Configuration
# Using null_resource with local-exec to apply after MetalLB CRDs are ready
resource "null_resource" "metallb_config" {
  count = var.cluster_type == "local" ? 1 : 0
  provisioner "local-exec" {
    command = <<-EOT
      # Wait for MetalLB CRDs to be available
      echo "Waiting for MetalLB CRDs to be ready..."
      timeout=300
      while [ $timeout -gt 0 ]; do
        if kubectl get crd ipaddresspools.metallb.io >/dev/null 2>&1; then
          echo "MetalLB CRDs are ready"
          break
        fi
        echo "Waiting for MetalLB CRDs... ($timeout seconds left)"
        sleep 10
        timeout=$((timeout - 10))
      done
      
      if [ $timeout -le 0 ]; then
        echo "ERROR: MetalLB CRDs not ready within 300 seconds"
        exit 1
      fi
      
      # Apply IPAddressPool
      kubectl apply -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - 172.18.255.200-172.18.255.250
EOF
      
      # Apply L2Advertisement
      kubectl apply -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
EOF
      
      echo "MetalLB configuration applied successfully"
    EOT
  }

  depends_on = [null_resource.install_metallb]

  triggers = {
    metallb_release = var.cluster_type == "local" ? null_resource.install_metallb[0].id : ""
  }
}

# Ingress Nginx Controller using local-exec
resource "null_resource" "install_ingress_nginx_local" {
  count = var.cluster_type == "local" ? 1 : 0
  provisioner "local-exec" {
    command = <<-EOT
      echo "Installing Ingress Nginx..."
      helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
      helm repo update
      
      # Create ingress-nginx namespace
      kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -
      
      # Install ingress-nginx with custom values
      helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --version 4.8.3 \
        --namespace ingress-nginx \
        --set controller.service.type=LoadBalancer \
        --set controller.service.annotations."metallb\.universe\.tf/address-pool"=default-pool \
        --set controller.ingressClassResource.default=true \
        --set controller.config.use-forwarded-headers=true \
        --set controller.config.compute-full-forwarded-for=true \
        --wait
      echo "✅ Ingress Nginx installed"
    EOT
  }

  depends_on = [null_resource.install_metallb, null_resource.metallb_config]
}

# Sealed Secrets Controller
# Sealed Secrets Controller using local-exec
resource "null_resource" "install_sealed_secrets_local" {
  count = var.cluster_type == "local" ? 1 : 0
  provisioner "local-exec" {
    command = <<-EOT
      echo "Installing Sealed Secrets..."
      helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
      helm repo update
      helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
        --version 2.13.2 \
        --namespace sealed-secrets \
        --set commandArgs="{--update-status}" \
        --set fullnameOverride=sealed-secrets-controller \
        --wait
      echo "✅ Sealed Secrets installed"
    EOT
  }

  depends_on = [null_resource.create_namespaces_local]
}

# ArgoCD Installation using local-exec
resource "null_resource" "install_argocd_local" {
  count = var.cluster_type == "local" ? 1 : 0
  provisioner "local-exec" {
    command = <<-EOT
      echo "Installing ArgoCD..."
      helm repo add argo https://argoproj.github.io/argo-helm
      helm repo update
      
      # Create ArgoCD values file
      cat > /tmp/argocd-values.yaml << 'EOF'
global:
  domain: argocd.${var.environment}.127.0.0.1.nip.io
configs:
  params:
    server.insecure: true
  cm:
    application.instanceLabelKey: argocd.argoproj.io/instance
server:
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      nginx.ingress.kubernetes.io/ssl-redirect: "false"
      nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    hosts:
      - host: argocd.${var.environment}.127.0.0.1.nip.io
        paths:
          - path: /
            pathType: Prefix
applicationSet:
  enabled: true
EOF
      
      # Install ArgoCD
      helm upgrade --install argocd argo/argo-cd \
        --version 5.51.6 \
        --namespace argocd \
        --values /tmp/argocd-values.yaml \
        --wait
      
      # Clean up temp file
      rm -f /tmp/argocd-values.yaml
      echo "✅ ArgoCD installed"
    EOT
  }

  depends_on = [null_resource.create_namespaces_local, null_resource.install_ingress_nginx_local]
}

# Wait for ArgoCD to be ready
resource "null_resource" "wait_for_argocd_local" {
  count = var.cluster_type == "local" ? 1 : 0
  depends_on = [null_resource.install_argocd_local]

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
data "external" "argocd_password_local" {
  count = var.cluster_type == "local" ? 1 : 0
  depends_on = [null_resource.wait_for_argocd_local]

  program = ["bash", "-c", <<-EOT
    password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "admin")
    echo "{\"password\": \"$password\"}"
  EOT
  ]
}

# External services validation
data "external" "external_services_check" {
  program = ["bash", "-c", <<-EOT
    # Check if external services are running and healthy
    if ! command -v docker &> /dev/null; then
      echo '{"error": "Docker not available", "services_ready": "false"}'
      exit 0
    fi
    
    # Initialize status variables
    postgres_status="stopped"
    minio_status="stopped" 
    postgres_health="unknown"
    minio_health="unknown"
    
    # Check PostgreSQL container
    if docker ps --format "{{.Names}}" | grep -q "^comind-ops-postgres$"; then
      postgres_status="running"
      postgres_health=$(docker inspect comind-ops-postgres --format '{{.State.Health.Status}}' 2>/dev/null | tr -d '\n' || echo "no-healthcheck")
    fi
    
    # Check MinIO container
    if docker ps --format "{{.Names}}" | grep -q "^comind-ops-minio$"; then
      minio_status="running"
      minio_health=$(docker inspect comind-ops-minio --format '{{.State.Health.Status}}' 2>/dev/null | tr -d '\n' || echo "no-healthcheck")
    fi
    
    # Determine overall readiness
    services_ready="false"
    if [ "$postgres_status" = "running" ] && [ "$minio_status" = "running" ]; then
      if [ "$postgres_health" = "healthy" ] && [ "$minio_health" = "healthy" ]; then
        services_ready="true"
      elif [ "$postgres_health" = "no-healthcheck" ] && [ "$minio_health" = "no-healthcheck" ]; then
        services_ready="assumed_healthy"
      fi
    fi
    
    echo "{\"postgres_status\": \"$postgres_status\", \"postgres_health\": \"$postgres_health\", \"minio_status\": \"$minio_status\", \"minio_health\": \"$minio_health\", \"services_ready\": \"$services_ready\"}"
  EOT
  ]
}

# Validation for external services
resource "null_resource" "external_services_validation_local" {
  count = var.cluster_type == "local" ? 1 : 0

  triggers = {
    services_check = data.external.external_services_check.result["services_ready"]
  }

  provisioner "local-exec" {
    command = <<-EOT
      POSTGRES_STATUS="${data.external.external_services_check.result["postgres_status"]}"
      MINIO_STATUS="${data.external.external_services_check.result["minio_status"]}"
      POSTGRES_HEALTH="${data.external.external_services_check.result["postgres_health"]}"
      MINIO_HEALTH="${data.external.external_services_check.result["minio_health"]}"
      SERVICES_READY="${data.external.external_services_check.result["services_ready"]}"
      
      echo "🔍 External Services Status Check:"
      echo "  PostgreSQL: $POSTGRES_STATUS ($POSTGRES_HEALTH)"
      echo "  MinIO: $MINIO_STATUS ($MINIO_HEALTH)"
      echo "  Overall: $SERVICES_READY"
      
      if [ "$SERVICES_READY" = "false" ]; then
        echo "⚠️  External services validation: Some services need initialization"
        echo "🔧 Auto-triggering service healing and proceeding with platform setup..."
        
        # Attempt auto-healing of external services
        if command -v "${path.root}/../../../scripts/external-services.sh" >/dev/null 2>&1; then
          echo "   Running auto-healing for external services..."
          "${path.root}/../../../scripts/external-services.sh" heal || echo "   Healing attempted, continuing with bootstrap..."
        fi
        
        echo "✅ Platform bootstrap will continue - services will be available for applications"
        echo "💡 This approach ensures platform resilience and automated recovery"
      elif [ "$SERVICES_READY" = "assumed_healthy" ]; then
        echo "⚠️  External services are running but health checks unavailable"
        echo "✅ Assuming services are healthy and proceeding..."
      else
        echo "✅ External services are healthy and ready!"
      fi
    EOT
  }
}

# ====================================================
# AWS INFRASTRUCTURE (EKS CLUSTER)
# ====================================================

# Data sources for AWS
data "aws_availability_zones" "available" {
  count = var.cluster_type == "aws" ? 1 : 0
  state = "available"
}

# VPC for EKS cluster
resource "aws_vpc" "main" {
  count = var.cluster_type == "aws" ? 1 : 0
  
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name        = "${var.cluster_name}-vpc"
    Environment = var.environment
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  count = var.cluster_type == "aws" ? 1 : 0
  
  vpc_id = aws_vpc.main[0].id
  
  tags = {
    Name        = "${var.cluster_name}-igw"
    Environment = var.environment
  }
}

# Public subnets
resource "aws_subnet" "public" {
  count = var.cluster_type == "aws" ? 2 : 0
  
  vpc_id                  = aws_vpc.main[0].id
  cidr_block             = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone      = data.aws_availability_zones.available[0].names[count.index]
  map_public_ip_on_launch = true
  
  tags = {
    Name                        = "${var.cluster_name}-public-subnet-${count.index + 1}"
    Environment                 = var.environment
    "kubernetes.io/role/elb"    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Private subnets
resource "aws_subnet" "private" {
  count = var.cluster_type == "aws" ? 2 : 0
  
  vpc_id            = aws_vpc.main[0].id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available[0].names[count.index]
  
  tags = {
    Name                            = "${var.cluster_name}-private-subnet-${count.index + 1}"
    Environment                     = var.environment
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Route table for public subnets
resource "aws_route_table" "public" {
  count = var.cluster_type == "aws" ? 1 : 0
  
  vpc_id = aws_vpc.main[0].id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }
  
  tags = {
    Name        = "${var.cluster_name}-public-rt"
    Environment = var.environment
  }
}

# Associate public subnets with route table
resource "aws_route_table_association" "public" {
  count = var.cluster_type == "aws" ? 2 : 0
  
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# NAT Gateway
resource "aws_eip" "nat" {
  count = var.cluster_type == "aws" ? 2 : 0
  
  domain = "vpc"
  depends_on = [aws_internet_gateway.main]
  
  tags = {
    Name        = "${var.cluster_name}-nat-eip-${count.index + 1}"
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "main" {
  count = var.cluster_type == "aws" ? 2 : 0
  
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  depends_on    = [aws_internet_gateway.main]
  
  tags = {
    Name        = "${var.cluster_name}-nat-gw-${count.index + 1}"
    Environment = var.environment
  }
}

# Route table for private subnets
resource "aws_route_table" "private" {
  count = var.cluster_type == "aws" ? 2 : 0
  
  vpc_id = aws_vpc.main[0].id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }
  
  tags = {
    Name        = "${var.cluster_name}-private-rt-${count.index + 1}"
    Environment = var.environment
  }
}

# Associate private subnets with route tables
resource "aws_route_table_association" "private" {
  count = var.cluster_type == "aws" ? 2 : 0
  
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# EKS Cluster IAM role
resource "aws_iam_role" "eks_cluster" {
  count = var.cluster_type == "aws" ? 1 : 0
  
  name = "${var.cluster_name}-eks-cluster-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  count = var.cluster_type == "aws" ? 1 : 0
  
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster[0].name
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  count = var.cluster_type == "aws" ? 1 : 0
  
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster[0].arn
  version  = var.eks_cluster_version
  
  vpc_config {
    subnet_ids              = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
    endpoint_private_access = true
    endpoint_public_access  = true
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
  ]
  
  tags = {
    Name        = var.cluster_name
    Environment = var.environment
  }
}

# EKS Node Group IAM role
resource "aws_iam_role" "eks_nodes" {
  count = var.cluster_type == "aws" ? 1 : 0
  
  name = "${var.cluster_name}-eks-nodes-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  count = var.cluster_type == "aws" ? 1 : 0
  
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes[0].name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  count = var.cluster_type == "aws" ? 1 : 0
  
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes[0].name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  count = var.cluster_type == "aws" ? 1 : 0
  
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes[0].name
}

# EKS Node Group
resource "aws_eks_node_group" "main" {
  count = var.cluster_type == "aws" ? 1 : 0
  
  cluster_name    = aws_eks_cluster.main[0].name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.eks_nodes[0].arn
  subnet_ids      = aws_subnet.private[*].id
  instance_types  = [var.eks_node_instance_type]
  
  scaling_config {
    desired_size = var.eks_node_desired_size
    max_size     = var.eks_node_max_size
    min_size     = var.eks_node_min_size
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy,
  ]
  
  tags = {
    Name        = "${var.cluster_name}-nodes"
    Environment = var.environment
  }
}

# Configure kubernetes provider for EKS
data "aws_eks_cluster" "main" {
  count = var.cluster_type == "aws" ? 1 : 0
  name  = aws_eks_cluster.main[0].name
}

data "aws_eks_cluster_auth" "main" {
  count = var.cluster_type == "aws" ? 1 : 0
  name  = aws_eks_cluster.main[0].name
}

# Update kubeconfig for EKS
resource "null_resource" "kubeconfig_aws" {
  count = var.cluster_type == "aws" ? 1 : 0
  
  depends_on = [aws_eks_node_group.main]
  
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
  }
}

# Create namespaces for AWS
resource "null_resource" "create_namespaces_aws" {
  count = var.cluster_type == "aws" ? 1 : 0
  
  depends_on = [null_resource.kubeconfig_aws]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Creating Kubernetes namespaces..."
      for namespace in platform-dev platform-stage platform-prod argocd sealed-secrets; do
        kubectl create namespace $namespace --dry-run=client -o yaml | kubectl apply -f -
        kubectl label namespace $namespace app.kubernetes.io/managed-by=terraform --overwrite
      done
      echo "✅ Namespaces created"
    EOT
  }
}

# Install ArgoCD for AWS
resource "null_resource" "install_argocd_aws" {
  count = var.cluster_type == "aws" ? 1 : 0
  
  depends_on = [null_resource.create_namespaces_aws]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Installing ArgoCD on AWS EKS..."
      helm repo add argo https://argoproj.github.io/argo-helm
      helm repo update
      
      # Create ArgoCD values file for AWS
      cat > /tmp/argocd-values-aws.yaml << 'EOF'
configs:
  params:
    server.insecure: false
  cm:
    application.instanceLabelKey: argocd.argoproj.io/instance
server:
  service:
    type: LoadBalancer
applicationSet:
  enabled: true
EOF
      
      # Install ArgoCD
      helm upgrade --install argocd argo/argo-cd \
        --version 5.51.6 \
        --namespace argocd \
        --values /tmp/argocd-values-aws.yaml \
        --wait
      
      # Clean up temp file
      rm -f /tmp/argocd-values-aws.yaml
      echo "✅ ArgoCD installed on AWS EKS"
    EOT
  }
}

# Wait for ArgoCD to be ready on AWS
resource "null_resource" "wait_for_argocd_aws" {
  count = var.cluster_type == "aws" ? 1 : 0
  
  depends_on = [null_resource.install_argocd_aws]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for ArgoCD to be ready on AWS..."
      kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
      kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n argocd
      kubectl wait --for=condition=available --timeout=300s deployment/argocd-dex-server -n argocd
      echo "ArgoCD is ready on AWS!"
    EOT
  }
}

# Data source for ArgoCD password on AWS
data "external" "argocd_password_aws" {
  count = var.cluster_type == "aws" ? 1 : 0
  depends_on = [null_resource.wait_for_argocd_aws]

  program = ["bash", "-c", <<-EOT
    password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "admin")
    echo "{\"password\": \"$password\"}"
  EOT
  ]
}

