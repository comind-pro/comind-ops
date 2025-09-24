variable "app_name" { type = string }
variable "environment" { type = string }
variable "cluster_type" { type = string }
variable "kubernetes_namespace" { type = string }
variable "queue_config" { type = any }
variable "queue_names" { type = list(any) }
variable "tags" { type = map(string); default = {} }
