# Docker Service Registry Terraform Module
# Terraform module for managing Docker services based on registry configuration

terraform {
  required_version = ">= 1.0"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Variables
variable "registry_file" {
  description = "Path to the services registry YAML file"
  type        = string
  default     = "./registry/services.yaml"
}

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
  default     = "dev"
}

variable "network_name" {
  description = "Docker network name"
  type        = string
  default     = "comind-ops-network"
}

variable "data_directory" {
  description = "Base directory for service data"
  type        = string
  default     = "./data"
}

# Create Docker network
resource "docker_network" "main" {
  name = var.network_name
  
  driver = "bridge"
  
  ipam_config {
    subnet = "172.20.0.0/16"
  }
}

# Create base directories
resource "local_file" "data_directories" {
  for_each = toset([
    "${var.data_directory}",
    "${var.data_directory}/postgresql",
    "${var.data_directory}/minio",
    "${var.data_directory}/redis",
    "${var.data_directory}/elasticmq",
    "${var.data_directory}/external"
  ])
  
  content  = ""
  filename = "${each.value}/.gitkeep"
}

# Service configuration files
resource "local_file" "service_configs" {
  for_each = {
    postgresql = {
      template = "postgresql"
      enabled  = true
    }
    minio = {
      template = "minio"
      enabled  = true
    }
    redis = {
      template = "redis"
      enabled  = false
    }
    elasticmq = {
      template = "elasticmq"
      enabled  = false
    }
    external = {
      template = "external"
      enabled  = false
    }
  }
  
  content = templatefile("${path.module}/templates/${each.value.template}.conf.tpl", {
    service_name    = each.key
    environment     = var.environment
    network_name    = var.network_name
    data_directory  = "${var.data_directory}/${each.key}"
  })
  
  filename = "${var.data_directory}/${each.key}/service.conf"
}

# Service management scripts
resource "local_file" "service_scripts" {
  for_each = {
    postgresql = "postgresql"
    minio      = "minio"
    redis      = "redis"
    elasticmq  = "elasticmq"
    external   = "external"
  }
  
  content = templatefile("${path.module}/templates/service-wrapper.sh.tpl", {
    service_name = each.key
    module_type  = each.value
    environment   = var.environment
  })
  
  filename        = "${var.data_directory}/${each.key}/service.sh"
  file_permission = "0755"
}

# Service status monitoring
resource "null_resource" "service_monitor" {
  count = var.environment == "dev" ? 1 : 0
  
  triggers = {
    registry_file = filemd5(var.registry_file)
    environment   = var.environment
  }
  
  provisioner "local-exec" {
    command = "${path.module}/scripts/monitor-services.sh ${var.environment}"
  }
}

# Outputs
output "network_name" {
  description = "Docker network name"
  value       = docker_network.main.name
}

output "network_id" {
  description = "Docker network ID"
  value       = docker_network.main.id
}

output "data_directory" {
  description = "Base data directory"
  value       = var.data_directory
}

output "service_configs" {
  description = "Service configuration files"
  value = {
    for k, v in local_file.service_configs : k => v.filename
  }
}

output "service_scripts" {
  description = "Service management scripts"
  value = {
    for k, v in local_file.service_scripts : k => v.filename
  }
}