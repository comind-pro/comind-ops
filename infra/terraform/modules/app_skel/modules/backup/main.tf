# Backup Module - Automated backup jobs

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# Database backup CronJob
resource "kubernetes_cron_job_v1" "database_backup" {
  count = var.backup_config.database_backup_enabled && var.database_id != "" ? 1 : 0
  
  metadata {
    name      = "${var.app_name}-db-backup"
    namespace = var.kubernetes_namespace
  }
  
  spec {
    schedule = var.backup_config.backup_schedule
    
    job_template {
      metadata {
        labels = {
          app = "${var.app_name}-backup"
        }
      }
      
      spec {
        template {
          metadata {
            labels = {
              app = "${var.app_name}-backup"  
            }
          }
          
          spec {
            restart_policy = "OnFailure"
            
            container {
              name  = "backup"
              image = "postgres:15-alpine"
              
              command = ["/bin/sh", "-c", "pg_dump $DATABASE_URL > /backup/backup-$(date +%Y%m%d_%H%M%S).sql"]
              
              env {
                name  = "DATABASE_URL"
                value = "postgresql://user:pass@host/db" # This would come from secrets
              }
              
              volume_mount {
                name       = "backup-storage"
                mount_path = "/backup"
              }
            }
            
            volume {
              name = "backup-storage"
              persistent_volume_claim {
                claim_name = "${var.app_name}-backup-pvc"
              }
            }
          }
        }
      }
    }
  }
}
