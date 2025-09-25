#!/bin/bash
set -euo pipefail

# MinIO Backup Script for Comind-Ops Platform
# Creates mirror backup of MinIO data

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2; }

# Configuration
BACKUP_DATE=$(date '+%Y%m%d_%H%M%S')
SOURCE_ALIAS="source-minio"
BACKUP_ALIAS="backup-minio"

log "Starting MinIO backup process..."

# Configure MinIO client for source
mc alias set "$SOURCE_ALIAS" "http://${SOURCE_MINIO_ENDPOINT}" "$SOURCE_MINIO_ACCESS_KEY" "$SOURCE_MINIO_SECRET_KEY"

# Test source connectivity
if ! mc ls "$SOURCE_ALIAS" > /dev/null 2>&1; then
    error "Failed to connect to source MinIO"
    exit 1
fi

log "Connected to source MinIO successfully"

# Get list of buckets to backup (exclude backups bucket to avoid recursion)
BUCKETS_TO_BACKUP=$(mc ls "$SOURCE_ALIAS" | grep -v "backups" | awk '{print $NF}' | sed 's/\///g')

if [ -z "$BUCKETS_TO_BACKUP" ]; then
    log "No buckets found to backup"
    exit 0
fi

log "Buckets to backup: $BUCKETS_TO_BACKUP"

# Create backup metadata
mkdir -p /tmp/minio-backup
cat > /tmp/minio-backup/backup-metadata.json << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "service": "minio",
  "backup_date": "$BACKUP_DATE",
  "source_endpoint": "$SOURCE_MINIO_ENDPOINT",
  "buckets": [$(echo "$BUCKETS_TO_BACKUP" | sed 's/^/"/g' | sed 's/$/"/g' | paste -sd ',')]
}
EOF

# Perform backup for each bucket
TOTAL_SIZE=0
TOTAL_FILES=0

for BUCKET in $BUCKETS_TO_BACKUP; do
    log "Backing up bucket: $BUCKET"
    
    # Create backup directory structure
    BACKUP_PATH="/tmp/minio-backup/$BUCKET"
    mkdir -p "$BACKUP_PATH"
    
    # Mirror bucket contents
    if mc mirror --remove "$SOURCE_ALIAS/$BUCKET" "$BACKUP_PATH/"; then
        log "Successfully mirrored bucket: $BUCKET"
        
        # Get bucket statistics
        BUCKET_SIZE=$(du -sb "$BACKUP_PATH" | cut -f1)
        BUCKET_FILES=$(find "$BACKUP_PATH" -type f | wc -l)
        
        TOTAL_SIZE=$((TOTAL_SIZE + BUCKET_SIZE))
        TOTAL_FILES=$((TOTAL_FILES + BUCKET_FILES))
        
        log "Bucket $BUCKET: ${BUCKET_FILES} files, $((BUCKET_SIZE / 1024 / 1024))MB"
    else
        error "Failed to mirror bucket: $BUCKET"
        exit 1
    fi
done

# Create compressed archive
log "Creating compressed backup archive..."
cd /tmp
ARCHIVE_NAME="minio_backup_${BACKUP_DATE}.tar.gz"

if tar -czf "$ARCHIVE_NAME" -C minio-backup .; then
    log "Backup archive created successfully: $ARCHIVE_NAME"
else
    error "Failed to create backup archive"
    exit 1
fi

# Upload backup archive to backups bucket
log "Uploading backup archive..."
if mc cp "$ARCHIVE_NAME" "$SOURCE_ALIAS/backups/minio/"; then
    log "Backup archive uploaded successfully"
else
    error "Failed to upload backup archive"
    exit 1
fi

# Verify upload
REMOTE_SIZE=$(mc stat "$SOURCE_ALIAS/backups/minio/$ARCHIVE_NAME" | grep Size | awk '{print $2}')
LOCAL_SIZE=$(stat -c%s "$ARCHIVE_NAME")

if [ "$REMOTE_SIZE" = "$LOCAL_SIZE" ]; then
    log "Backup verification successful"
else
    error "Backup verification failed"
    exit 1
fi

# Clean up old backups
log "Cleaning up old backups (retention: $BACKUP_RETENTION_DAYS days)..."
CUTOFF_DATE=$(date -d "$BACKUP_RETENTION_DAYS days ago" +%Y%m%d)

mc ls "$SOURCE_ALIAS/backups/minio/" | while read -r line; do
    FILENAME=$(echo "$line" | awk '{print $NF}')
    
    if [[ "$FILENAME" =~ minio_backup_([0-9]{8})_ ]]; then
        FILE_DATE="${BASH_REMATCH[1]}"
        
        if [ "$FILE_DATE" -lt "$CUTOFF_DATE" ]; then
            log "Removing old backup: $FILENAME"
            mc rm "$SOURCE_ALIAS/backups/minio/$FILENAME" || error "Failed to remove $FILENAME"
        fi
    fi
done

# Generate final backup report
ARCHIVE_SIZE_MB=$((LOCAL_SIZE / 1024 / 1024))
cat > /tmp/minio-backup-report.json << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "service": "minio",
  "status": "success",
  "backup_file": "$ARCHIVE_NAME",
  "backup_size_mb": $ARCHIVE_SIZE_MB,
  "total_files": $TOTAL_FILES,
  "total_size_bytes": $TOTAL_SIZE,
  "buckets_backed_up": $(echo "$BUCKETS_TO_BACKUP" | wc -w),
  "retention_days": $BACKUP_RETENTION_DAYS,
  "source_endpoint": "$SOURCE_MINIO_ENDPOINT"
}
EOF

# Upload backup report
mc cp /tmp/minio-backup-report.json "$SOURCE_ALIAS/backups/minio/reports/backup-report-$BACKUP_DATE.json"

# Clean up local files
rm -rf /tmp/minio-backup "$ARCHIVE_NAME" /tmp/minio-backup-report.json

log "MinIO backup process completed successfully"
log "Archive: $ARCHIVE_NAME (${ARCHIVE_SIZE_MB}MB)"
log "Total files backed up: $TOTAL_FILES"
log "Total size: $((TOTAL_SIZE / 1024 / 1024))MB"
