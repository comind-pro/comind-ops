output "vpc_id" {
  description = "ID of the VPC"
  value       = var.cluster_type == "aws" ? aws_vpc.main[0].id : null
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = var.cluster_type == "aws" ? aws_subnet.public[*].id : []
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = var.cluster_type == "aws" ? aws_subnet.private[*].id : []
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = var.cluster_type == "aws" ? aws_internet_gateway.main[0].id : null
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = var.cluster_type == "aws" ? aws_nat_gateway.main[0].id : null
}
