#!/bin/bash
set -e

# Check if we're in CI environment
if [ "${CLUSTER_TYPE}" = "ci" ] || [ -n "$CI" ] || [ -n "$GITHUB_ACTIONS" ]; then
  echo "CI environment detected, skipping k3d cluster creation"
  echo "This would be handled by external cluster setup in CI"
  exit 0
fi

# Check if cluster already exists
if k3d cluster list | grep -q "${CLUSTER_NAME}"; then
  echo "Cluster ${CLUSTER_NAME} already exists, skipping creation"
else
  echo "Creating k3d cluster ${CLUSTER_NAME}..."
  k3d cluster create ${CLUSTER_NAME} \
    --api-port ${CLUSTER_PORT} \
    --port "${INGRESS_HTTP_PORT}:80@loadbalancer" \
    --port "${INGRESS_HTTPS_PORT}:443@loadbalancer" \
    --k3s-arg "--disable=traefik@server:0" \
    --k3s-arg "--disable=servicelb@server:0" \
    --agents 2 \
    --wait
  
  # Wait for cluster to be ready
  timeout=300
  while [ $timeout -gt 0 ]; do
    if kubectl cluster-info --context k3d-${CLUSTER_NAME} >/dev/null 2>&1; then
      echo "Cluster is ready"
      break
    fi
    echo "Waiting for cluster to be ready... ($timeout seconds left)"
    sleep 10
    timeout=$((timeout - 10))
  done
  
  if [ $timeout -le 0 ]; then
    echo "Cluster failed to become ready in time"
    exit 1
  fi
fi
