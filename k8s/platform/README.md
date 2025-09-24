# Platform Services

This directory contains the core platform services that provide foundational capabilities for the comind-ops cloud platform.

## Services Included

### 1. ElasticMQ (`elasticmq/`)
**AWS SQS-compatible message queue service**

- **Deployment**: Production-ready ElasticMQ with security context
- **Configuration**: Pre-configured queues with dead letter queues
- **Ingress**: Web UI accessible at `elasticmq.dev.127.0.0.1.nip.io`
- **Features**:
  - Default queue with 3-retry DLQ
  - High-priority queue for urgent messages
  - Notifications queue with 5-retry DLQ
  - Health checks and resource limits

**Queues Available:**
- `default` - General purpose queue
- `high-priority` - For urgent processing
- `notifications` - User notifications
- `default-dlq` & `notifications-dlq` - Dead letter queues

### 2. Docker Registry (`registry/`)
**Private container registry with retention policies**

- **Registry**: Distribution v2 with authentication
- **Storage**: 50GB persistent storage (configurable)
- **Security**: htpasswd authentication, HTTP headers protection
- **Ingress**: Accessible at `registry.dev.127.0.0.1.nip.io`
- **Retention**: Automated cleanup via regctl (keeps 10 latest tags)

**Features:**
- Delete enabled for cleanup operations
- Health checks for storage driver
- Configurable retention policies
- Support for large image uploads (500MB)

### 3. Backup Services (`backups/`)
**Automated backup solutions for databases and object storage**

#### PostgreSQL Backup (`postgres-cronjob.yaml`)
- **Schedule**: Daily at 3 AM
- **Method**: `pg_dumpall` with compression
- **Storage**: Local PVC + optional MinIO upload
- **Retention**: 7 days (configurable)
- **Features**:
  - Backup metadata with size tracking
  - Automatic cleanup of old backups
  - Support for external backup storage

#### MinIO Backup (`minio-cronjob.yaml`)
- **Schedule**: Daily at 4 AM
- **Method**: `mc mirror` for incremental sync
- **Storage**: Local PVC + optional external S3
- **Retention**: 7 days (configurable)
- **Features**:
  - All buckets mirrored
  - Backup metadata with size tracking
  - Support for external backup destinations

## Deployment

### Deploy all platform services:
```bash
kubectl apply -k k8s/platform/
```

### Deploy specific service:
```bash
kubectl apply -f k8s/platform/elasticmq/deployment.yaml
kubectl apply -f k8s/platform/registry/registry.yaml
kubectl apply -f k8s/platform/backups/postgres-cronjob.yaml
```

### Environment-specific deployment:
```bash
# Development
kubectl apply -k k8s/platform/ --set-image elasticmq=softwaremill/elasticmq:latest

# Staging (use values/stage.yaml)
helm template elasticmq k8s/platform/elasticmq/chart -f k8s/platform/elasticmq/values/stage.yaml

# Production (use values/prod.yaml with 2 replicas)
helm template elasticmq k8s/platform/elasticmq/chart -f k8s/platform/elasticmq/values/prod.yaml
```

## Configuration

### ElasticMQ Configuration
- **Dev**: Single replica, 512Mi memory limit
- **Stage**: Single replica, 1Gi memory, conservative timeouts  
- **Prod**: 2 replicas, 2Gi memory, authentication enabled

### Registry Configuration
- **Authentication**: `admin/admin123` (CHANGE IN PRODUCTION!)
- **Retention**: Keep 10 latest tags per repository
- **Storage**: Persistent volume with filesystem backend
- **Cleanup**: Daily at 2 AM via CronJob

### Backup Configuration
- **PostgreSQL**: Full backup with metadata
- **MinIO**: Incremental mirror of all buckets
- **Retention**: 7-day default, configurable
- **Storage**: Local PVC + optional external destinations

## Security Features

1. **Non-root execution**: All containers run as non-root users
2. **Read-only filesystems**: Where possible to prevent tampering
3. **Capability dropping**: Remove all Linux capabilities
4. **Network policies**: Controlled access between services
5. **Secret management**: ConfigMaps for non-sensitive, Secrets for credentials
6. **Resource limits**: Prevent resource exhaustion

## Monitoring

### Health Checks
- **ElasticMQ**: HTTP health check on port 9325
- **Registry**: HTTP health check on `/v2/` endpoint
- **Backups**: Job success/failure monitoring via Kubernetes Jobs

### Logs
```bash
# ElasticMQ logs
kubectl logs -l app=elasticmq -n platform-dev

# Registry logs
kubectl logs -l app=docker-registry -n platform-dev

# Backup job logs
kubectl logs job/postgres-backup-<timestamp> -n backup-system
kubectl logs job/minio-backup-<timestamp> -n backup-system
```

### Metrics
- ElasticMQ web UI provides queue metrics
- Registry provides basic HTTP metrics
- Backup jobs log size and duration metrics

## Troubleshooting

### Common Issues

1. **ElasticMQ connection refused**
   ```bash
   kubectl port-forward svc/elasticmq 9324:9324 -n platform-dev
   curl http://localhost:9324/
   ```

2. **Registry authentication failed**
   ```bash
   kubectl get secret registry-auth -n platform-dev -o yaml
   # Verify htpasswd format
   ```

3. **Backup job failed**
   ```bash
   kubectl describe cronjob postgres-backup -n backup-system
   kubectl logs job/<job-name> -n backup-system
   ```

4. **Storage issues**
   ```bash
   kubectl get pvc -n platform-dev
   kubectl describe pvc registry-storage -n platform-dev
   ```

## Integration

### Application Usage

#### Using ElasticMQ from applications:
```yaml
env:
- name: SQS_ENDPOINT
  value: "http://elasticmq.platform-dev.svc.cluster.local:9324"
- name: SQS_REGION
  value: "elasticmq"
```

#### Using Docker Registry:
```bash
# Login to registry
docker login registry.dev.127.0.0.1.nip.io:8080

# Push image
docker push registry.dev.127.0.0.1.nip.io:8080/myapp:latest
```

#### Backup Restoration:
```bash
# Restore PostgreSQL backup
kubectl exec -it postgres-pod -- psql -U postgres < backup/dump.sql

# Restore MinIO backup
mc mirror backup-location/bucket target-bucket/
```
