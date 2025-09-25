# External Services Management

Guide to managing PostgreSQL and MinIO services that run outside Kubernetes as Docker containers for the Comind-Ops Platform.

## Overview

The Comind-Ops Platform uses external Docker containers for data storage services to provide:

- **Better Data Persistence**: Data survives Kubernetes cluster recreations
- **Easier Management**: Direct access to databases and storage without Kubernetes complexity
- **Performance**: Reduced overhead and better resource utilization
- **Development Experience**: Familiar Docker tooling and debugging

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           COMIND-OPS PLATFORM                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────┐    ┌─────────────────────────────────────────┐  │
│  │   KUBERNETES CLUSTER │    │         EXTERNAL SERVICES              │  │
│  │                     │    │                                         │  │
│  │  ┌───────────────┐  │    │  ┌─────────────────┐ ┌─────────────────┐ │  │
│  │  │ Applications  │──┼────┼─▶│   PostgreSQL    │ │      MinIO      │ │  │
│  │  │               │  │    │  │   (port 5432)   │ │  (ports 9000/1) │ │  │
│  │  └───────────────┘  │    │  └─────────────────┘ └─────────────────┘ │  │
│  │                     │    │                                         │  │
│  │  ┌───────────────┐  │    │  ┌─────────────────┐ ┌─────────────────┐ │  │
│  │  │ Platform Svcs │  │    │  │ Backup Services │ │  Init Services  │ │  │
│  │  │ (ElasticMQ)   │  │    │  │   (Automated)   │ │  (Setup/Config) │ │  │
│  │  └───────────────┘  │    │  └─────────────────┘ └─────────────────┘ │  │
│  └─────────────────────┘    └─────────────────────────────────────────┘  │
│                                                                         │
│           Network: k3d-comind-ops-dev         Network: comind-ops       │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Services

### PostgreSQL Database

- **Container Name**: `comind-ops-postgres`
- **Image**: `postgres:16-alpine`
- **Port**: `5432`
- **Network IP**: `172.20.0.10`
- **Databases**: `comind_ops`, `sample_app_dev`, `sample_app_stage`, `sample_app_prod`
- **Features**: Multi-database setup, optimized configuration, automated backups

### MinIO Object Storage

- **Container Name**: `comind-ops-minio`
- **Image**: `minio/minio:latest`
- **Ports**: `9000` (API), `9001` (Console)
- **Network IP**: `172.20.0.20`
- **Buckets**: `app-data`, `backups`, `logs`, `uploads`, `artifacts`
- **Features**: S3-compatible API, web console, lifecycle policies, automated backups

## Management Commands

### Basic Operations

```bash
# Start all external services
make services-start

# Stop all external services
make services-stop

# Check service status
make services-status

# View service logs
make services-logs

# Initial setup (first time only)
make services-setup
```

### Using the External Services Script

```bash
# Start services
./scripts/external-services.sh start

# Start specific service
./scripts/external-services.sh start --service postgres
./scripts/external-services.sh start --service minio

# Check status with health checks
./scripts/external-services.sh status

# Follow logs in real-time
./scripts/external-services.sh logs --follow

# Show logs for specific service
./scripts/external-services.sh logs --service postgres --follow
```

### Backup Operations

```bash
# Create backup of all services
make services-backup

# Backup specific service
./scripts/external-services.sh backup --service postgres
./scripts/external-services.sh backup --service minio

# Backups are stored in MinIO bucket: backups/postgres/ and backups/minio/
```

## Configuration

### Environment Variables

Copy the environment template and customize:

```bash
# Copy template
cp infra/docker/env.template infra/docker/.env

# Edit configuration
nano infra/docker/.env
```

**Key settings:**

```bash
# Environment
ENV=dev

# PostgreSQL
POSTGRES_PASSWORD=secure_password_change_me
POSTGRES_USER=comind_ops_user

# MinIO
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin123

# Backups
BACKUP_RETENTION_DAYS=7
```

### Network Configuration

Services are connected via a dedicated Docker network:

- **Network Name**: `comind-ops-network`
- **Subnet**: `172.20.0.0/16`
- **PostgreSQL IP**: `172.20.0.10`
- **MinIO IP**: `172.20.0.20`

## Database Management

### PostgreSQL Connection

From host machine:
```bash
psql -h localhost -p 5432 -U comind_ops_user -d comind_ops
```

From Kubernetes pods:
```bash
# Using external service name
psql -h sample-app-postgres-external -p 5432 -U sample_app_user -d sample_app_dev
```

### Database Structure

- **comind_ops**: Main platform database
- **sample_app_dev**: Development environment database
- **sample_app_stage**: Staging environment database  
- **sample_app_prod**: Production environment database

### Users and Permissions

- `comind_ops_user`: Main platform user
- `sample_app_user`: Application-specific user with limited permissions
- `backup_user`: Read-only user for backup operations

## Object Storage Management

### MinIO Access

**Web Console**: http://localhost:9001
- Username: `minioadmin` (or configured value)
- Password: `minioadmin123` (or configured value)

**API Endpoint**: http://localhost:9000

### Bucket Structure

- `app-data`: Application runtime data
- `backups`: Automated backup storage
- `logs`: Application and platform logs
- `uploads`: User-uploaded content
- `artifacts`: Build artifacts and deployments

### Using MinIO CLI

```bash
# Install MinIO client
brew install minio/stable/mc

# Configure alias
mc alias set local http://localhost:9000 minioadmin minioadmin123

# List buckets
mc ls local

# Upload file
mc cp file.txt local/uploads/

# Download file
mc cp local/uploads/file.txt .
```

## Kubernetes Integration

### Service Discovery

Applications in Kubernetes connect to external services via:

1. **ExternalName Services**: Map external containers to Kubernetes services
2. **Endpoints**: Direct IP mapping for reliable connectivity
3. **DNS Resolution**: Using service names within the cluster

### Example Configuration

```yaml
apiVersion: v1
kind: Service
metadata:
  name: sample-app-postgres-external
spec:
  type: ExternalName
  externalName: host.docker.internal
  ports:
  - port: 5432
---
apiVersion: v1
kind: Endpoints
metadata:
  name: sample-app-postgres-external
subsets:
- addresses:
  - ip: 172.20.0.10
  ports:
  - port: 5432
```

## Backup and Recovery

### Automated Backups

Backups run automatically and include:

**PostgreSQL Backup:**
- Script: `infra/docker/scripts/backup-postgres.sh`
- Full database dump with `pg_dumpall`
- Compressed and uploaded to MinIO
- Retention policy: 7 days (configurable)
- Backup reports with metadata

**MinIO Backup:**
- Script: `infra/docker/scripts/backup-minio.sh`
- Mirror of all buckets (except backups)
- Compressed archive format
- Stored in backups bucket
- Verification and reporting

### Manual Backup

```bash
# Run immediate backup
make services-backup

# PostgreSQL only
./scripts/external-services.sh backup --service postgres

# MinIO only
./scripts/external-services.sh backup --service minio
```

### Recovery Procedures

1. **Stop services**: `make services-stop`
2. **Download backup** from MinIO backups bucket
3. **Restore data** to appropriate volumes
4. **Start services**: `make services-start`
5. **Verify integrity** and functionality

## Monitoring and Health Checks

### Health Endpoints

**PostgreSQL**: 
```bash
docker exec comind-ops-postgres pg_isready -U comind_ops_user -d comind_ops
```

**MinIO**:
```bash
curl -f http://localhost:9000/minio/health/live
```

### Logs

```bash
# View all service logs
make services-logs

# Follow specific service
docker logs -f comind-ops-postgres
docker logs -f comind-ops-minio
```

### Resource Usage

```bash
# Check resource usage
docker stats comind-ops-postgres comind-ops-minio

# Inspect containers
docker inspect comind-ops-postgres
docker inspect comind-ops-minio
```

## Troubleshooting

### Common Issues

**Services won't start:**
- Check Docker daemon is running
- Verify port availability (5432, 9000, 9001)
- Check environment configuration
- Review container logs

**Connection refused:**
- Verify network connectivity
- Check firewall settings
- Ensure services are healthy
- Validate Kubernetes service configuration

**Data not persisting:**
- Check volume mounts
- Verify permissions
- Ensure volumes exist
- Check disk space

### Debug Commands

```bash
# Check network
docker network inspect comind-ops-network

# Check volumes
docker volume ls | grep comind-ops

# Inspect service
docker exec -it comind-ops-postgres bash
docker exec -it comind-ops-minio bash

# Test connectivity from Kubernetes
kubectl run debug --image=busybox --rm -it --restart=Never -- nslookup sample-app-postgres-external
```

### Performance Tuning

**PostgreSQL:**
- Adjust `shared_buffers` in `postgresql.conf`
- Tune connection limits
- Monitor query performance
- Optimize database schemas

**MinIO:**
- Configure appropriate resource limits
- Monitor disk I/O
- Optimize bucket policies
- Review access patterns

## Security Considerations

### Network Security
- Services isolated in dedicated Docker network
- No external access except through configured ports
- Firewall rules for production environments

### Authentication
- Strong passwords required
- Service-specific users with minimal permissions
- Regular credential rotation recommended

### Data Protection
- Encrypted connections where possible
- Regular security updates
- Backup encryption
- Access logging and monitoring

This external services architecture provides a robust foundation for the Comind-Ops Platform while maintaining simplicity and reliability.
