# Queue Module - SQS/ElasticMQ queue provisioning

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# AWS SQS queues
resource "aws_sqs_queue" "app_queues" {
  count = var.cluster_type == "aws" ? length(var.queue_names) : 0
  
  name                       = var.queue_names[count.index].name
  delay_seconds              = var.queue_names[count.index].config.delay_seconds
  max_message_size           = var.queue_names[count.index].config.max_message_size
  message_retention_seconds  = var.queue_names[count.index].config.message_retention_seconds
  receive_wait_time_seconds  = var.queue_names[count.index].config.receive_wait_time_seconds
  visibility_timeout_seconds = var.queue_names[count.index].config.visibility_timeout_seconds
  
  tags = var.tags
}

# Dead Letter Queues
resource "aws_sqs_queue" "dlq" {
  count = var.cluster_type == "aws" ? length([for q in var.queue_names : q if q.config.dlq_enabled]) : 0
  
  name = "${var.queue_names[count.index].name}-dlq"
  tags = var.tags
}

# Queue configuration for local ElasticMQ (uses existing platform ElasticMQ)
resource "kubernetes_config_map" "queue_config" {
  count = var.cluster_type == "local" ? 1 : 0
  
  metadata {
    name      = "${var.app_name}-queue-config"
    namespace = var.kubernetes_namespace
  }
  
  data = {
    "queues.conf" = templatefile("${path.module}/templates/elasticmq.conf", {
      queues = var.queue_names
    })
  }
}

# Local variables
locals {
  queue_endpoint = var.cluster_type == "local" ? "elasticmq.platform-${var.environment}.svc.cluster.local:9324" : "sqs.amazonaws.com"
}
