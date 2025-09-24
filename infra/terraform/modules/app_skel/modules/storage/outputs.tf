# Storage Module Outputs

output "endpoint" {
  description = "Storage endpoint"
  value       = local.storage_endpoint
}

output "access_key" {
  description = "Storage access key"
  value       = local.access_key
  sensitive   = true
}

output "secret_key" {
  description = "Storage secret key"  
  value       = local.secret_key
  sensitive   = true
}

output "bucket_names" {
  description = "List of created bucket names"
  value = var.cluster_type == "aws" ? (
    [for bucket in aws_s3_bucket.app_buckets : bucket.id]
  ) : var.cluster_type == "digitalocean" ? (
    [for bucket in digitalocean_spaces_bucket.app_buckets : bucket.name]
  ) : [for bucket in var.storage_buckets : bucket.name]
}

output "bucket_urls" {
  description = "List of bucket URLs"
  value = var.cluster_type == "aws" ? (
    [for bucket in aws_s3_bucket.app_buckets : "s3://${bucket.id}"]
  ) : var.cluster_type == "digitalocean" ? (
    [for bucket in digitalocean_spaces_bucket.app_buckets : "https://${bucket.name}.${var.region}.digitaloceanspaces.com"]
  ) : [for bucket in var.storage_buckets : "http://${local.storage_endpoint}/${bucket.name}"]
}

output "console_url" {
  description = "Storage console URL (MinIO only)"
  value = var.cluster_type == "local" ? (
    "http://${var.app_name}-minio-console.${var.kubernetes_namespace}.svc.cluster.local:9001"
  ) : ""
}

output "region" {
  description = "Storage region"
  value = var.cluster_type == "aws" ? "us-east-1" : var.region
}

output "versioning_enabled" {
  description = "Whether versioning is enabled on buckets"
  value = length(var.storage_buckets) > 0 ? var.storage_buckets[0].config.versioning_enabled : false
}

output "lifecycle_enabled" {
  description = "Whether lifecycle policies are enabled"
  value = length(var.storage_buckets) > 0 ? var.storage_buckets[0].config.lifecycle_enabled : false
}

# IAM user ARN (AWS only)
output "iam_user_arn" {
  description = "IAM user ARN for S3 access"
  value = var.cluster_type == "aws" && length(aws_iam_user.s3_user) > 0 ? aws_iam_user.s3_user[0].arn : ""
}

# Service information
output "service_name" {
  description = "Storage service name"
  value = var.cluster_type == "local" ? "${var.app_name}-minio" : "s3"
}

output "service_port" {
  description = "Storage service port"
  value = var.cluster_type == "local" ? 9000 : 443
}

output "secure_connection" {
  description = "Whether to use secure (TLS) connection"
  value = var.cluster_type != "local"
}
