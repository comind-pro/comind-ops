#!/bin/bash
set -euo pipefail

# PostgreSQL Backup Script for Comind-Ops Platform
# Backs up PostgreSQL databases to MinIO

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2; }

# Configuration
BACKUP_DATE=$(date '+%Y%m%d_%H%M%S')
BACKUP_DIR="/tmp/postgres-backup"
BACKUP_FILE="postgres_backup_${BACKUP_DATE}.sql"
COMPRESSED_FILE="${BACKUP_FILE}.gz"

# MinIO configuration
MC_ALIAS="backup-minio"
BUCKET_NAME="backups"
BACKUP_PREFIX="postgres"

log "Starting PostgreSQL backup process..."

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Install MinIO client
apk add --no-cache curl
curl -o /usr/local/bin/mc https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x /usr/local/bin/mc

# Configure MinIO client
log "Configuring MinIO client..."
mc alias set "$MC_ALIAS" "http://${MINIO_ENDPOINT}" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY"

# Test MinIO connectivity
if ! mc ls "$MC_ALIAS" > /dev/null 2>&1; then
    error "Failed to connect to MinIO"
    exit 1
fi

log "Connected to MinIO successfully"

# Create backup
log "Creating PostgreSQL backup..."
cd "$BACKUP_DIR"

if pg_dumpall -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" > "$BACKUP_FILE"; then
    log "Database dump completed successfully"
else
    error "Database dump failed"
    exit 1
fi

# Compress backup
log "Compressing backup file..."
if gzip "$BACKUP_FILE"; then
    log "Backup compressed successfully"
else
    error "Failed to compress backup"
    exit 1
fi

# Upload to MinIO
log "Uploading backup to MinIO..."
if mc cp "$COMPRESSED_FILE" "$MC_ALIAS/$BUCKET_NAME/$BACKUP_PREFIX/"; then
    log "Backup uploaded successfully to MinIO"
else
    error "Failed to upload backup to MinIO"
    exit 1
fi

# Verify upload
REMOTE_SIZE=$(mc stat "$MC_ALIAS/$BUCKET_NAME/$BACKUP_PREFIX/$COMPRESSED_FILE" | grep Size | awk '{print $2}')
LOCAL_SIZE=$(stat -c%s "$COMPRESSED_FILE")

if [ "$REMOTE_SIZE" = "$LOCAL_SIZE" ]; then
    log "Backup verification successful (Size: $LOCAL_SIZE bytes)"
else
    error "Backup verification failed (Local: $LOCAL_SIZE, Remote: $REMOTE_SIZE)"
    exit 1
fi

# Clean up old backups
log "Cleaning up old backups (retention: $BACKUP_RETENTION_DAYS days)..."
CUTOFF_DATE=$(date -d "$BACKUP_RETENTION_DAYS days ago" +%Y%m%d)

# List and remove old backups
mc ls "$MC_ALIAS/$BUCKET_NAME/$BACKUP_PREFIX/" | while read -r line; do
    # Extract filename from mc ls output
    FILENAME=$(echo "$line" | awk '{print $NF}')
    
    # Extract date from filename (assuming format: postgres_backup_YYYYMMDD_HHMMSS.sql.gz)
    if [[ "$FILENAME" =~ postgres_backup_([0-9]{8})_ ]]; then
        FILE_DATE="${BASH_REMATCH[1]}"
        
        if [ "$FILE_DATE" -lt "$CUTOFF_DATE" ]; then
            log "Removing old backup: $FILENAME"
            mc rm "$MC_ALIAS/$BUCKET_NAME/$BACKUP_PREFIX/$FILENAME" || error "Failed to remove $FILENAME"
        fi
    fi
done

# Generate backup report
BACKUP_SIZE_MB=$((LOCAL_SIZE / 1024 / 1024))
cat > /tmp/backup-report.json << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "service": "postgresql",
  "status": "success",
  "backup_file": "$COMPRESSED_FILE",
  "backup_size_mb": $BACKUP_SIZE_MB,
  "retention_days": $BACKUP_RETENTION_DAYS,
  "minio_endpoint": "$MINIO_ENDPOINT",
  "bucket": "$BUCKET_NAME",
  "prefix": "$BACKUP_PREFIX"
}
EOF

# Upload backup report
mc cp /tmp/backup-report.json "$MC_ALIAS/$BUCKET_NAME/$BACKUP_PREFIX/reports/backup-report-$BACKUP_DATE.json"

# Clean up local files
rm -f "$COMPRESSED_FILE" /tmp/backup-report.json

log "PostgreSQL backup process completed successfully"
log "Backup file: $COMPRESSED_FILE (${BACKUP_SIZE_MB}MB)"
log "Uploaded to: $MC_ALIAS/$BUCKET_NAME/$BACKUP_PREFIX/$COMPRESSED_FILE"
