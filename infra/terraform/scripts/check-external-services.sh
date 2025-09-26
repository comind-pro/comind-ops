#!/bin/bash
set -e

# Check PostgreSQL
if docker ps --format "table {{.Names}}" | grep -q "comind-ops-postgres"; then
  POSTGRES_STATUS="running"
  # Try to check health
  if docker exec comind-ops-postgres pg_isready -U postgres >/dev/null 2>&1; then
    POSTGRES_HEALTH="healthy"
  else
    POSTGRES_HEALTH="unhealthy"
  fi
else
  POSTGRES_STATUS="stopped"
  POSTGRES_HEALTH="unknown"
fi

# Check MinIO
if docker ps --format "table {{.Names}}" | grep -q "comind-ops-minio"; then
  MINIO_STATUS="running"
  # Try to check health
  if curl -s http://localhost:9000/minio/health/live >/dev/null 2>&1; then
    MINIO_HEALTH="healthy"
  else
    MINIO_HEALTH="unhealthy"
  fi
else
  MINIO_STATUS="stopped"
  MINIO_HEALTH="unknown"
fi

# Determine overall services readiness
if [ "$POSTGRES_STATUS" = "running" ] && [ "$MINIO_STATUS" = "running" ]; then
  SERVICES_READY="ready"
elif [ "$POSTGRES_STATUS" = "stopped" ] && [ "$MINIO_STATUS" = "stopped" ]; then
  SERVICES_READY="not_running"
else
  SERVICES_READY="partial"
fi

# Output JSON
cat <<EOF
{
  "postgres_status": "$POSTGRES_STATUS",
  "postgres_health": "$POSTGRES_HEALTH",
  "minio_status": "$MINIO_STATUS",
  "minio_health": "$MINIO_HEALTH",
  "services_ready": "$SERVICES_READY"
}
EOF
