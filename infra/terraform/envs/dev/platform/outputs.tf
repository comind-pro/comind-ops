# Development environment outputs

# Environment metadata
output "environment_info" {
  description = "Development environment information"
  value = {
    environment  = local.environment
    region       = local.region
    cluster_type = var.cluster_type
    tags         = local.common_tags
  }
}

# Sample application URLs for easy access
output "application_urls" {
  description = "Application URLs for development environment"
  value = {
    sample_app  = "http://sample-app.dev.127.0.0.1.nip.io:8080"
    hello_world = "http://hello-world.dev.127.0.0.1.nip.io:8080"
    analytics   = "http://analytics.dev.127.0.0.1.nip.io:8080"

    # Platform services
    argocd    = "http://argocd.dev.127.0.0.1.nip.io:8080"
    elasticmq = "http://elasticmq.dev.127.0.0.1.nip.io:8080"
    registry  = "http://registry.dev.127.0.0.1.nip.io:8080"
  }
}

# Resource summary
output "resource_summary" {
  description = "Summary of provisioned resources"
  value = {
    namespaces_created = [
      module.sample_app.namespace,
      module.hello_world_app.namespace,
      module.analytics_app.namespace
    ]

    databases_provisioned = [
      for app, info in {
        sample_app = module.sample_app.database
        analytics  = module.analytics_app.database
      } : app if info.enabled
    ]

    storage_buckets = flatten([
      module.sample_app.storage.enabled ? module.sample_app.storage.bucket_names : [],
      module.analytics_app.storage.enabled ? module.analytics_app.storage.bucket_names : []
    ])

    queues_created = flatten([
      module.sample_app.queue.enabled ? module.sample_app.queue.queues : [],
      module.analytics_app.queue.enabled ? module.analytics_app.queue.queues : []
    ])
  }
}

# Development connection strings (for local testing)
output "dev_connection_info" {
  description = "Connection information for development testing"
  value = var.cluster_type == "local" ? {
    kubectl_context = "k3d-comind-ops-dev"

    port_forwards = {
      sample_app_db     = "kubectl port-forward svc/sample-app-postgresql 5432:5432 -n sample-app-dev"
      analytics_db      = "kubectl port-forward svc/analytics-postgresql 5432:5432 -n analytics-dev"
      sample_storage    = "kubectl port-forward svc/sample-app-minio 9000:9000 -n sample-app-dev"
      analytics_storage = "kubectl port-forward svc/analytics-minio 9000:9000 -n analytics-dev"
      analytics_cache   = "kubectl port-forward svc/analytics-redis-master 6379:6379 -n analytics-dev"
    }

    debug_commands = {
      check_namespaces = "kubectl get namespaces | grep -E '(sample-app|hello-world|analytics)'"
      check_pods       = "kubectl get pods -A | grep -E '(sample-app|hello-world|analytics)'"
      check_services   = "kubectl get services -A | grep -E '(sample-app|hello-world|analytics)'"
      check_ingress    = "kubectl get ingress -A | grep -E '(sample-app|hello-world|analytics)'"
    }
    } : {
    kubectl_context = null
    port_forwards   = {}
    debug_commands  = {}
  }
  sensitive = true
}

# Terraform state information
output "terraform_info" {
  description = "Terraform state and module information"
  value = {
    terraform_version = "> 1.0"
    modules_used = [
      "app_skel (sample-app)",
      "app_skel (hello-world)",
      "app_skel (analytics)"
    ]
    providers_configured = [
      "kubernetes",
      "helm",
      var.cluster_type == "aws" ? "aws" : null,
      var.cluster_type == "digitalocean" ? "digitalocean" : null
    ]
  }
}
