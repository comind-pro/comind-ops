# AWS Infrastructure - EKS Cluster

# Data sources for AWS
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC for EKS cluster
resource "aws_vpc" "main" {
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
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.cluster_name}-igw"
    Environment = var.environment
  }
}

# Public subnets
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "${var.cluster_name}-public-subnet-${count.index + 1}"
    Environment                                 = var.environment
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Private subnets
resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name                                        = "${var.cluster_name}-private-subnet-${count.index + 1}"
    Environment                                 = var.environment
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.cluster_name}-public-rt"
    Environment = var.environment
  }
}

# Associate public subnets with route table
resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway
resource "aws_eip" "nat" {
  count = 2

  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]

  tags = {
    Name        = "${var.cluster_name}-nat-eip-${count.index + 1}"
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "main" {
  count = 2

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
  count = 2

  vpc_id = aws_vpc.main.id

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
  count = 2

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# EKS Cluster IAM role
resource "aws_iam_role" "eks_cluster" {
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
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
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
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

# EKS Node Group
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn
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
  name = aws_eks_cluster.main.name
}

data "aws_eks_cluster_auth" "main" {
  name = aws_eks_cluster.main.name
}

# Update kubeconfig for EKS
resource "null_resource" "kubeconfig" {
  depends_on = [aws_eks_node_group.main]

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
  }
}

# Create namespaces for AWS
resource "null_resource" "create_namespaces" {
  depends_on = [null_resource.kubeconfig]

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

# Install AWS Load Balancer Controller
resource "null_resource" "install_aws_lb_controller" {
  depends_on = [null_resource.create_namespaces]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Installing AWS Load Balancer Controller..."
      
      # Create service account with IAM role
      eksctl create iamserviceaccount \
        --cluster=${var.cluster_name} \
        --namespace=kube-system \
        --name=aws-load-balancer-controller \
        --role-name "AmazonEKSLoadBalancerControllerRole-${var.cluster_name}" \
        --attach-policy-arn=arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess \
        --approve \
        --override-existing-serviceaccounts \
        --region=${var.aws_region} || echo "Service account already exists, continuing..."
      
      # Install AWS Load Balancer Controller
      helm repo add eks https://aws.github.io/eks-charts
      helm repo update
      helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName=${var.cluster_name} \
        --set serviceAccount.create=false \
        --set serviceAccount.name=aws-load-balancer-controller \
        --wait
      
      echo "✅ AWS Load Balancer Controller installed"
    EOT
  }
}

# Install Sealed Secrets Controller for AWS
resource "null_resource" "install_sealed_secrets" {
  depends_on = [null_resource.create_namespaces]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Installing Sealed Secrets on AWS EKS..."
      helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
      helm repo update
      helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
        --version 2.13.2 \
        --namespace sealed-secrets \
        --set commandArgs="{--update-status}" \
        --set fullnameOverride=sealed-secrets-controller \
        --wait
      echo "✅ Sealed Secrets installed on AWS EKS"
    EOT
  }
}

# Install ArgoCD for AWS
resource "null_resource" "install_argocd" {
  depends_on = [null_resource.install_aws_lb_controller, null_resource.install_sealed_secrets]

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
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
      service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
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
resource "null_resource" "wait_for_argocd" {
  depends_on = [null_resource.install_argocd]

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
data "external" "argocd_password" {
  depends_on = [null_resource.wait_for_argocd]

  program = ["bash", "-c", <<-EOT
    password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "admin")
    echo "{\"password\": \"$password\"}"
  EOT
  ]
}
