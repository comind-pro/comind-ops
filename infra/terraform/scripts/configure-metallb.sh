#!/bin/bash
set -e

# Wait for MetalLB CRDs to be available
echo "Waiting for MetalLB CRDs to be ready..."
timeout=300
while [ $timeout -gt 0 ]; do
  if kubectl get crd ipaddresspools.metallb.io >/dev/null 2>&1; then
    echo "MetalLB CRDs are ready"
    break
  fi
  echo "Waiting for MetalLB CRDs... ($timeout seconds left)"
  sleep 5
  timeout=$((timeout - 5))
done

if [ $timeout -le 0 ]; then
  echo "MetalLB CRDs failed to become ready in time"
  exit 1
fi

# Configure MetalLB IP pool
echo "Configuring MetalLB IP pool..."
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - 172.18.255.200-172.18.255.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
EOF

echo "✅ MetalLB configured"
