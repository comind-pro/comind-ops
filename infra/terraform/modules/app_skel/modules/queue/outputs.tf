output "endpoint" {
  value = local.queue_endpoint
}

output "queue_urls" {
  value = var.cluster_type == "aws" ? [for q in aws_sqs_queue.app_queues : q.url] : [for q in var.queue_names : "http://${local.queue_endpoint}/queue/${q.name}"]
}
