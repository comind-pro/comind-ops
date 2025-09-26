output "cluster_created" {
  description = "Whether the cluster was created"
  value       = var.cluster_type == "local" ? null_resource.k3d_cluster[0].id : null
}
