# Outputs for AWS environment

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = var.cluster_name
}

output "cluster_context" {
  description = "Kubernetes context name"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "argocd_endpoint" {
  description = "ArgoCD web UI endpoint"
  value       = "https://$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
}

output "argocd_credentials" {
  description = "ArgoCD admin credentials"
  value = {
    username = "admin"
    password = data.external.argocd_password.result.password
  }
  sensitive = true
}

output "namespaces_created" {
  description = "List of namespaces created by Terraform"
  value       = ["platform-dev", "platform-stage", "platform-prod", "argocd", "sealed-secrets"]
}

# AWS-specific outputs
output "aws_vpc_id" {
  description = "AWS VPC ID"
  value       = aws_vpc.main.id
}

output "aws_eks_cluster_name" {
  description = "AWS EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "aws_eks_cluster_version" {
  description = "AWS EKS cluster Kubernetes version"
  value       = aws_eks_cluster.main.version
}

output "aws_public_subnet_ids" {
  description = "AWS public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "aws_private_subnet_ids" {
  description = "AWS private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "environment_type" {
  description = "Environment type"
  value       = "aws"
}
