variable "app_name" { type = string }
variable "environment" { type = string }
variable "cluster_type" { type = string }
variable "kubernetes_namespace" { type = string }
variable "backup_config" { type = any }
variable "database_id" { type = string; default = "" }
variable "storage_buckets" { type = list(string); default = [] }
variable "tags" { type = map(string); default = {} }
