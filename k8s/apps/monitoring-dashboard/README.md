# Sample Application

A comprehensive demonstration application showcasing all Comind-Ops Platform capabilities including database integration, message queuing, object storage, monitoring, security, and GitOps workflows.

## Overview

This sample application serves as:
- **Reference implementation** for Comind-Ops Platform features
- **Template** for new applications using `make new-app`
- **Demo** for platform capabilities during onboarding
- **Testing tool** for platform validation

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      SAMPLE APPLICATION                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   Frontend      │  │    Backend      │  │   Workers       │  │
│  │                 │  │                 │  │                 │  │
│  │ • nginx         │  │ • REST API      │  │ • Queue Jobs    │  │
│  │ • Static Files  │  │ • Health Checks │  │ • Cron Tasks    │  │
│  │ • Ingress       │  │ • Metrics       │  │ • Background    │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│           │                     │                     │         │
│           └─────────────────────┼─────────────────────┘         │
│                                 │                               │
│  ┌─────────────────────────────┴─────────────────────────────┐  │
│  │                PLATFORM SERVICES                         │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │  │
│  │  │ PostgreSQL  │  │ ElasticMQ   │  │      MinIO          │ │  │
│  │  │ (Database)  │  │ (Queue)     │  │   (Storage)         │ │  │
│  │  └─────────────┘  └─────────────┘  └─────────────────────┘ │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Features Demonstrated

### ✅ Platform Integrations

- **PostgreSQL Database**: Connection pooling, migrations, backups
- **ElasticMQ Queuing**: SQS-compatible message processing
- **MinIO Storage**: S3-compatible object storage with buckets
- **Redis Cache**: In-memory caching (staging/prod only)

### ✅ Security & Governance

- **Sealed Secrets**: Encrypted secret management with GitOps
- **Network Policies**: Micro-segmentation and traffic control
- **Pod Security**: Non-root containers, read-only filesystems
- **RBAC**: Service account with minimal permissions
- **Resource Limits**: CPU/memory governance

### ✅ Observability

- **Health Checks**: Liveness, readiness, and startup probes
- **Metrics**: Prometheus ServiceMonitor with custom metrics
- **Logging**: Structured JSON logging with correlation IDs
- **Tracing**: OpenTelemetry integration (staging/prod)

### ✅ Operational Excellence

- **Multi-Environment**: Dev, staging, production configurations
- **Auto-scaling**: Horizontal Pod Autoscaler with custom metrics
- **High Availability**: Pod anti-affinity and disruption budgets
- **GitOps**: ArgoCD-managed deployments with sync waves
- **CI/CD Ready**: Container image building and promotion

### ✅ Developer Experience

- **Local Development**: Hot reload and debugging support
- **Configuration Management**: Environment-specific values
- **Secret Management**: Easy secret sealing and rotation
- **Testing**: Health endpoints and validation jobs

## Deployment Guide

### Prerequisites

1. **Comind-Ops Platform**: Complete bootstrap (`make bootstrap`)
2. **Secrets**: Create and seal application secrets
3. **Dependencies**: Platform services running (PostgreSQL, ElasticMQ, MinIO)

### Quick Deployment

```bash
# 1. Ensure platform is running
make status

# 2. Create application secrets (see Secret Management section)
# Create plain secret file, then:
./scripts/seal-secret.sh sample-app dev sample-app-secret.yaml

# 3. Deploy the application (ArgoCD will sync automatically)
git add k8s/apps/sample-app/
git commit -m "Deploy sample-app to development"
git push origin main

# 4. Monitor deployment
kubectl get applications -n argocd
kubectl get pods -n sample-app-dev -w

# 5. Test the application
curl http://sample-app.dev.127.0.0.1.nip.io:8080/health
```

### Environment Promotion

```bash
# Deploy to staging (requires staging secrets)
./scripts/seal-secret.sh sample-app stage sample-app-stage-secret.yaml
git add k8s/apps/sample-app/secrets/stage.sealed.yaml
git commit -m "Add sample-app staging secrets"
git push

# Deploy to production (requires manual approval)
./scripts/seal-secret.sh sample-app prod sample-app-prod-secret.yaml
# Manual ArgoCD sync for production
argocd app sync sample-app-prod
```

## Configuration

### Environment-Specific Settings

| Setting | Dev | Stage | Prod |
|---------|-----|-------|------|
| **Replicas** | 1 | 2 | 3 |
| **CPU Request** | 50m | 250m | 500m |
| **Memory Request** | 64Mi | 256Mi | 512Mi |
| **Autoscaling** | Disabled | 2-8 replicas | 3-20 replicas |
| **Storage** | 1Gi | 5Gi | 50Gi |
| **TLS** | Disabled | Let's Encrypt Staging | Let's Encrypt Prod |
| **Logging** | Debug | Info | Warn |
| **Network Policy** | Relaxed | Restrictive | Maximum Security |

### Platform Service Endpoints

| Environment | Database | Queue | Storage |
|-------------|----------|-------|---------|
| **Dev** | postgres.platform-dev | elasticmq.platform-dev | minio.platform-dev |
| **Stage** | postgres.platform-stage | elasticmq.platform-stage | minio.platform-stage |
| **Prod** | RDS endpoint | SQS endpoint | S3 endpoint |

## Secret Management

### Required Secrets

The application requires these secrets in each environment:

#### Database Secrets
```yaml
DATABASE_URL: "postgresql://user:pass@host:5432/db"
DATABASE_PASSWORD: "secure-password"
```

#### API Keys
```yaml
EXTERNAL_API_KEY: "api-key-value"
JWT_SECRET: "jwt-signing-secret"
```

#### Storage Secrets
```yaml
MINIO_ACCESS_KEY: "access-key"
MINIO_SECRET_KEY: "secret-key"
```

#### Application Secrets
```yaml
SESSION_SECRET: "session-signing-key"
ENCRYPTION_KEY: "32-character-encryption-key"
```

### Creating Secrets

1. **Create plain secret file**:
```bash
cat > sample-app-dev-secret.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: sample-app-secrets
  namespace: sample-app-dev
stringData:
  DATABASE_URL: "postgresql://..."
  # ... other secrets
EOF
```

2. **Seal the secret**:
```bash
./scripts/seal-secret.sh sample-app dev sample-app-dev-secret.yaml
```

3. **Clean up plain secret**:
```bash
rm sample-app-dev-secret.yaml  # IMPORTANT!
```

4. **Commit sealed secret**:
```bash
git add k8s/apps/sample-app/secrets/dev.sealed.yaml
git commit -m "Update sample-app dev secrets"
git push
```

## Local Development

### Port Forwarding

```bash
# Forward application port
kubectl port-forward service/sample-app 8080:80 -n sample-app-dev

# Forward database port
kubectl port-forward service/postgres 5432:5432 -n platform-dev

# Forward queue port
kubectl port-forward service/elasticmq 9324:9324 -n platform-dev
```

### Debug Mode

```bash
# Enable debug logging
kubectl patch deployment sample-app -n sample-app-dev -p '{"spec":{"template":{"spec":{"containers":[{"name":"sample-app","env":[{"name":"LOG_LEVEL","value":"debug"}]}]}}}}'

# View logs
make logs APP=sample-app

# Debug shell
make shell
kubectl exec -it deployment/sample-app -n sample-app-dev -- /bin/bash
```

### Hot Reload

For development, you can enable hot reload by mounting your code:

```yaml
# Add to values/dev.yaml
volumeMounts:
  - name: source-code
    mountPath: /app/src

volumes:
  - name: source-code
    hostPath:
      path: /path/to/your/code
```

## Monitoring

### Health Endpoints

| Endpoint | Purpose | Response |
|----------|---------|----------|
| `/health` | Liveness probe | HTTP 200 "healthy" |
| `/ready` | Readiness probe | HTTP 200 "ready" |
| `/startup` | Startup probe | HTTP 200 "started" |
| `/metrics` | Prometheus metrics | Metrics in Prometheus format |

### Metrics

The application exposes these custom metrics:

- `sample_app_requests_total` - Total HTTP requests
- `sample_app_request_duration_seconds` - Request duration histogram
- `sample_app_database_connections_active` - Active DB connections
- `sample_app_queue_messages_processed_total` - Queue messages processed
- `sample_app_storage_operations_total` - Storage operations

### Dashboards

Pre-configured Grafana dashboards are available:

- **Application Overview**: Request rates, latencies, errors
- **Platform Services**: Database, queue, storage metrics
- **Infrastructure**: CPU, memory, network usage

### Alerts

Key alerts configured:

- High error rate (>5% for 5 minutes)
- High latency (>1s p95 for 5 minutes)
- Pod crash loop
- Database connection failures
- Queue processing delays

## Testing

### Health Checks

```bash
# Basic health check
curl http://sample-app.dev.127.0.0.1.nip.io:8080/health

# Readiness check
curl http://sample-app.dev.127.0.0.1.nip.io:8080/ready

# Metrics endpoint
curl http://sample-app.dev.127.0.0.1.nip.io:8080/metrics
```

### Load Testing

```bash
# Simple load test
ab -n 1000 -c 10 http://sample-app.dev.127.0.0.1.nip.io:8080/

# Watch autoscaling
kubectl get hpa -n sample-app-dev -w
```

### Platform Integration Tests

```bash
# Database connectivity
kubectl exec deployment/sample-app -n sample-app-dev -- pg_isready -h postgres.platform-dev.svc.cluster.local

# Queue connectivity  
kubectl exec deployment/sample-app -n sample-app-dev -- curl elasticmq.platform-dev.svc.cluster.local:9324/

# Storage connectivity
kubectl exec deployment/sample-app -n sample-app-dev -- curl minio.platform-dev.svc.cluster.local:9000/minio/health/live
```

## Troubleshooting

### Common Issues

#### 1. Application Won't Start

```bash
# Check pod status
kubectl get pods -n sample-app-dev
kubectl describe pod <pod-name> -n sample-app-dev

# Check logs
kubectl logs deployment/sample-app -n sample-app-dev

# Check secrets
kubectl get secrets -n sample-app-dev
kubectl describe sealedsecret sample-app-secrets -n sample-app-dev
```

#### 2. Database Connection Issues

```bash
# Test database connectivity
kubectl exec deployment/sample-app -n sample-app-dev -- nc -zv postgres.platform-dev.svc.cluster.local 5432

# Check database logs
kubectl logs deployment/postgres -n platform-dev

# Verify secret values
kubectl get secret sample-app-secrets -n sample-app-dev -o yaml
```

#### 3. Queue Processing Issues

```bash
# Check ElasticMQ status
kubectl get pods -n platform-dev -l app=elasticmq

# View queue contents
curl http://elasticmq.dev.127.0.0.1.nip.io:8080/queue/default

# Check worker logs
kubectl logs deployment/sample-app -n sample-app-dev -c worker
```

#### 4. Storage Access Issues

```bash
# Check MinIO status
kubectl get pods -n platform-dev -l app=minio

# Test bucket access
kubectl exec deployment/sample-app -n sample-app-dev -- \
  mc ls minio/sample-app-uploads-dev
```

### Debug Commands

```bash
# Comprehensive debug info
make debug APP=sample-app

# Check all resources
kubectl get all -n sample-app-dev

# View events
kubectl get events -n sample-app-dev --sort-by=.metadata.creationTimestamp

# Network debugging
kubectl exec deployment/sample-app -n sample-app-dev -- netstat -an
kubectl exec deployment/sample-app -n sample-app-dev -- nslookup postgres.platform-dev.svc.cluster.local
```

## Customization

### Using as a Template

This sample app serves as a template for new applications:

```bash
# Create new app based on sample-app
make new-app APP=my-new-app TEAM=backend --template=sample-app

# Customize for your needs
# - Update Chart.yaml with your app details
# - Modify templates for your requirements  
# - Adjust values for your environments
# - Create your secrets
```

### Extending Features

Common extensions:

1. **Add Redis caching**:
```yaml
# In values.yaml
platformServices:
  cache:
    enabled: true
    host: redis.platform-dev.svc.cluster.local
```

2. **Add background workers**:
```yaml
# Additional deployment for workers
containers:
- name: worker
  image: my-app:latest
  command: ['python', 'worker.py']
```

3. **Add cron jobs**:
```yaml
# In templates/cronjob.yaml
apiVersion: batch/v1
kind: CronJob
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: my-app:latest
            command: ['python', 'backup.py']
```

## Production Checklist

Before deploying to production:

- [ ] **Security review** completed
- [ ] **Load testing** performed  
- [ ] **Disaster recovery** plan documented
- [ ] **Monitoring** and **alerting** configured
- [ ] **Secret rotation** schedule established
- [ ] **Performance benchmarks** established
- [ ] **Documentation** updated
- [ ] **Team training** completed

## Contributing

When modifying this sample application:

1. **Test all environments** (dev/stage/prod)
2. **Update documentation** for changes
3. **Validate platform integrations** still work
4. **Run security scans** on containers
5. **Test upgrade/rollback** procedures

This sample application demonstrates the full power of the comind-ops Platform and serves as the foundation for building robust, secure, and scalable applications.
