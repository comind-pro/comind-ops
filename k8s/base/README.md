# Base Kubernetes Resources

This directory contains the base Kubernetes resources that provide foundational security, governance, and operational policies for the comind-ops cloud platform.

## Resources Included

### 1. Namespaces (`namespaces.yaml`)
- **monitoring**: For monitoring tools (Prometheus, Grafana)
- **ingress-nginx**: For ingress controller components
- **backup-system**: For backup operations

*Note: Platform namespaces (platform-dev, platform-stage, platform-prod) are created by Terraform.*

### 2. RBAC (`rbac.yaml`)
- **backup-operator**: Service account and cluster role for backup operations
- **app-deployer**: Service accounts and roles for application deployments in each platform environment
- Proper role bindings with least-privilege access

### 3. Resource Quotas (`resource-quotas.yaml`)
- **platform-dev**: 4 CPU / 8Gi RAM requests, 8 CPU / 16Gi RAM limits
- **platform-stage**: 2 CPU / 4Gi RAM requests, 4 CPU / 8Gi RAM limits  
- **platform-prod**: 6 CPU / 12Gi RAM requests, 12 CPU / 24Gi RAM limits
- **monitoring**: 2 CPU / 4Gi RAM requests, 4 CPU / 8Gi RAM limits
- **backup-system**: 1 CPU / 2Gi RAM requests, 2 CPU / 4Gi RAM limits

### 4. Limit Ranges (`limit-ranges.yaml`)
- Container resource limits and defaults for each namespace
- PVC size limits (dev: 50Gi max, stage: 20Gi max, prod: 100Gi max)
- Prevents resource abuse and ensures consistent sizing

### 5. Network Policies (`network-policies.yaml`)
- **Default deny**: All ingress traffic blocked by default
- **Ingress controller access**: Allow traffic from nginx-ingress
- **Same namespace**: Allow pod-to-pod communication within namespace
- **DNS resolution**: Allow DNS queries (UDP/TCP port 53)
- **External egress**: Allow HTTP/HTTPS outbound traffic

### 6. Pod Security (`pod-security.yaml`)
- **Platform namespaces**: Restricted Pod Security Standard enforcement
- **System namespaces**: Baseline Pod Security Standard for operational flexibility
- Security best practices documentation via ConfigMap

## Usage

### Apply all base resources:
```bash
kubectl apply -k k8s/base/
```

### Apply specific resource type:
```bash
kubectl apply -f k8s/base/rbac.yaml
kubectl apply -f k8s/base/resource-quotas.yaml
```

### Validate network policies:
```bash
kubectl get networkpolicy -A
kubectl describe networkpolicy default-deny-ingress -n platform-dev
```

### Check resource quotas:
```bash
kubectl get resourcequota -A
kubectl describe resourcequota platform-dev-quota -n platform-dev
```

## Security Features

1. **Defense in depth**: Multiple layers of security (RBAC, Network Policies, Pod Security)
2. **Least privilege**: Service accounts have minimal required permissions
3. **Resource governance**: Quotas prevent resource exhaustion
4. **Network segmentation**: Traffic isolation between namespaces
5. **Pod security**: Restricted containers with non-root execution

## Monitoring

These resources provide the foundation for secure multi-tenant operations. Monitor resource usage with:

```bash
# Check resource usage against quotas
kubectl top pods -A
kubectl describe resourcequota -A

# Verify network policy enforcement
kubectl exec -it <pod-name> -n platform-dev -- curl <external-service>
```
