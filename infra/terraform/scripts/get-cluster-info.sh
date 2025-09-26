#!/bin/bash
set -e

# Get cluster information
CLUSTER_NAME="${CLUSTER_NAME:-comind-ops-dev}"
CLUSTER_TYPE="${CLUSTER_TYPE:-local}"

if [ "$CLUSTER_TYPE" = "local" ]; then
  # Check if k3d cluster exists
  if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    CLUSTER_STATUS="running"
    CLUSTER_ENDPOINT="https://localhost:6443"
  else
    CLUSTER_STATUS="not_found"
    CLUSTER_ENDPOINT=""
  fi
else
  # For AWS, we'd get this from AWS CLI
  CLUSTER_STATUS="unknown"
  CLUSTER_ENDPOINT=""
fi

# Output JSON
cat <<EOF
{
  "cluster_name": "$CLUSTER_NAME",
  "cluster_type": "$CLUSTER_TYPE",
  "cluster_status": "$CLUSTER_STATUS",
  "cluster_endpoint": "$CLUSTER_ENDPOINT"
}
EOF
