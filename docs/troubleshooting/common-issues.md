# Common Issues and Solutions

## Comind-Ops Platform Troubleshooting Guide

This document provides solutions to common issues encountered when using the Comind-Ops Platform.

## Table of Contents

1. [Bootstrap Issues](#bootstrap-issues)
2. [Kubernetes Issues](#kubernetes-issues)
3. [ArgoCD Issues](#argocd-issues)
4. [Helm Issues](#helm-issues)
5. [Terraform Issues](#terraform-issues)
6. [Application Issues](#application-issues)
7. [Network Issues](#network-issues)
8. [Storage Issues](#storage-issues)
9. [Security Issues](#security-issues)
10. [Performance Issues](#performance-issues)

## Bootstrap Issues

### Issue: Bootstrap Command Fails

#### Symptoms
- `make bootstrap` command fails with errors
- Platform components not deployed
- Error messages during bootstrap process

#### Common Causes
1. **Missing Dependencies**
   ```bash
   # Check if all required tools are installed
   make check-deps
   ```

2. **Insufficient Resources**
   ```bash
   # Check available system resources
   docker system df
   kubectl top nodes
   ```

3. **Port Conflicts**
   ```bash
   # Check for port conflicts
   netstat -tulpn | grep :80
   netstat -tulpn | grep :443
   ```

#### Solutions

**Solution 1: Install Missing Dependencies**
```bash
# Install required tools
brew install docker kubectl helm terraform k3d yamllint yq jq

# Verify installation
make check-deps
```

**Solution 2: Free Up Resources**
```bash
# Clean up Docker resources
docker system prune -a

# Clean up Kubernetes resources
kubectl delete namespace test-* --ignore-not-found=true

# Restart Docker
sudo systemctl restart docker
```

**Solution 3: Resolve Port Conflicts**
```bash
# Stop conflicting services
sudo systemctl stop nginx
sudo systemctl stop apache2

# Use different ports
export INGRESS_HTTP_PORT=8080
export INGRESS_HTTPS_PORT=8443
make bootstrap
```

### Issue: External Services Not Starting

#### Symptoms
- PostgreSQL, Redis, or MinIO containers not starting
- Connection errors to external services
- Services not accessible

#### Solutions

**Solution 1: Check Docker Compose**
```bash
# Check Docker Compose status
docker-compose ps

# View logs
docker-compose logs postgresql
docker-compose logs redis
docker-compose logs minio

# Restart services
docker-compose restart
```

**Solution 2: Check Environment Variables**
```bash
# Verify environment file
cat .env

# Check required variables
grep -E "POSTGRES_|REDIS_|MINIO_" .env

# Update environment file
cp .env.example .env
# Edit .env with correct values
```

**Solution 3: Check Port Availability**
```bash
# Check if ports are available
netstat -tulpn | grep :5432  # PostgreSQL
netstat -tulpn | grep :6379  # Redis
netstat -tulpn | grep :9000  # MinIO

# Kill processes using ports if needed
sudo lsof -ti:5432 | xargs kill -9
sudo lsof -ti:6379 | xargs kill -9
sudo lsof -ti:9000 | xargs kill -9
```

## Kubernetes Issues

### Issue: Pods Not Starting

#### Symptoms
- Pods stuck in `Pending` or `CrashLoopBackOff` state
- Pods not ready
- Resource errors

#### Solutions

**Solution 1: Check Pod Status**
```bash
# Check pod status
kubectl get pods -A

# Describe problematic pods
kubectl describe pod <pod-name> -n <namespace>

# Check pod logs
kubectl logs <pod-name> -n <namespace>
```

**Solution 2: Check Resource Constraints**
```bash
# Check node resources
kubectl top nodes

# Check pod resource requests
kubectl describe pod <pod-name> -n <namespace> | grep -A 5 "Requests:"

# Check resource quotas
kubectl get resourcequota -A
```

**Solution 3: Check Image Pull Issues**
```bash
# Check image pull secrets
kubectl get secrets -A | grep docker

# Check image availability
docker pull <image-name>

# Update image pull policy
kubectl patch deployment <deployment-name> -n <namespace> -p '{"spec":{"template":{"spec":{"containers":[{"name":"<container-name>","imagePullPolicy":"IfNotPresent"}]}}}}'
```

### Issue: Services Not Accessible

#### Symptoms
- Services not reachable from outside cluster
- Connection timeouts
- DNS resolution issues

#### Solutions

**Solution 1: Check Service Configuration**
```bash
# Check service status
kubectl get services -A

# Check service endpoints
kubectl get endpoints -A

# Describe service
kubectl describe service <service-name> -n <namespace>
```

**Solution 2: Check Ingress Configuration**
```bash
# Check ingress status
kubectl get ingress -A

# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

**Solution 3: Check Network Policies**
```bash
# Check network policies
kubectl get networkpolicies -A

# Check if network policies are blocking traffic
kubectl describe networkpolicy <policy-name> -n <namespace>

# Temporarily disable network policies for testing
kubectl delete networkpolicy <policy-name> -n <namespace>
```

## ArgoCD Issues

### Issue: Applications Not Syncing

#### Symptoms
- Applications stuck in `OutOfSync` state
- Sync operations failing
- Applications not updating

#### Solutions

**Solution 1: Check ArgoCD Status**
```bash
# Check ArgoCD applications
kubectl get applications -n argocd

# Check ArgoCD server status
kubectl get pods -n argocd

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-server
```

**Solution 2: Check Repository Access**
```bash
# Check repository connections
kubectl get secrets -n argocd | grep repo

# Test repository access
kubectl exec -n argocd deployment/argocd-server -- argocd repo get <repo-url>

# Update repository credentials
kubectl create secret generic <repo-secret> -n argocd --from-literal=url=<repo-url> --from-literal=username=<username> --from-literal=password=<password>
```

**Solution 3: Check Application Configuration**
```bash
# Check application configuration
kubectl describe application <app-name> -n argocd

# Check sync status
kubectl get application <app-name> -n argocd -o yaml | grep -A 10 "status:"

# Force sync application
kubectl patch application <app-name> -n argocd --type merge -p '{"operation":{"sync":{"syncOptions":["CreateNamespace=true"]}}}'
```

### Issue: ArgoCD Login Issues

#### Symptoms
- Cannot login to ArgoCD UI
- Authentication failures
- Access denied errors

#### Solutions

**Solution 1: Check ArgoCD Server**
```bash
# Check ArgoCD server status
kubectl get pods -n argocd

# Check ArgoCD server logs
kubectl logs -n argocd deployment/argocd-server

# Restart ArgoCD server
kubectl rollout restart deployment/argocd-server -n argocd
```

**Solution 2: Check Admin Password**
```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Reset admin password
kubectl -n argocd patch secret argocd-secret -p '{"stringData": {"admin.password": "$2a$10$rRyBsGSHK6.uc8fntPwVFOBGpG3idAHag4YXP2snp2I0TjXfYyJwe", "admin.passwordMtime": "'$(date +%Y-%m-%dT%H:%M:%S)'"}}'
```

**Solution 3: Access ArgoCD**
```bash
# Get ArgoCD access credentials and setup
make argo-login

# This will display:
# - ArgoCD Web UI URL
# - Admin credentials
# - Port forwarding command (if needed)
```

## Helm Issues

### Issue: Helm Chart Installation Fails

#### Symptoms
- Helm install command fails
- Chart validation errors
- Template rendering issues

#### Solutions

**Solution 1: Check Chart Validity**
```bash
# Lint chart
helm lint <chart-path>

# Check chart dependencies
helm dependency list <chart-path>

# Update dependencies
helm dependency update <chart-path>
```

**Solution 2: Check Values File**
```bash
# Validate values file
helm template <chart-name> <chart-path> -f <values-file>

# Check for required values
helm template <chart-name> <chart-path> --dry-run

# Use default values
helm install <release-name> <chart-path> --dry-run
```

**Solution 3: Check Kubernetes Resources**
```bash
# Check if resources already exist
kubectl get all -n <namespace>

# Check for conflicts
kubectl describe <resource-type> <resource-name> -n <namespace>

# Clean up existing resources
kubectl delete <resource-type> <resource-name> -n <namespace>
```

### Issue: Helm Chart Upgrade Fails

#### Symptoms
- Helm upgrade command fails
- Rollback required
- Version conflicts

#### Solutions

**Solution 1: Check Upgrade Status**
```bash
# Check release status
helm status <release-name> -n <namespace>

# Check release history
helm history <release-name> -n <namespace>

# Check upgrade logs
helm upgrade <release-name> <chart-path> -n <namespace> --debug --dry-run
```

**Solution 2: Rollback Release**
```bash
# Rollback to previous version
helm rollback <release-name> <revision> -n <namespace>

# Check rollback status
helm status <release-name> -n <namespace>

# List available revisions
helm history <release-name> -n <namespace>
```

**Solution 3: Force Upgrade**
```bash
# Force upgrade (use with caution)
helm upgrade <release-name> <chart-path> -n <namespace> --force

# Check upgrade status
helm status <release-name> -n <namespace>
```

## Terraform Issues

### Issue: Terraform Plan/Apply Fails

#### Symptoms
- Terraform plan shows errors
- Terraform apply fails
- Resource conflicts

#### Solutions

**Solution 1: Check Terraform State**
```bash
# Check terraform state
terraform state list

# Check specific resource
terraform state show <resource-name>

# Refresh state
terraform refresh
```

**Solution 2: Check Provider Configuration**
```bash
# Check provider versions
terraform version

# Check provider configuration
terraform providers

# Update provider versions
terraform init -upgrade
```

**Solution 3: Check Resource Dependencies**
```bash
# Check resource dependencies
terraform graph | dot -Tpng > graph.png

# Check for circular dependencies
terraform validate

# Fix dependency issues
terraform plan -detailed-exitcode
```

### Issue: Terraform State Issues

#### Symptoms
- State file corruption
- State drift
- Resource not found errors

#### Solutions

**Solution 1: Backup and Restore State**
```bash
# Backup current state
cp terraform.tfstate terraform.tfstate.backup

# Check state file
terraform state list

# Restore from backup if needed
cp terraform.tfstate.backup terraform.tfstate
```

**Solution 2: Import Existing Resources**
```bash
# Import existing resource
terraform import <resource-type>.<resource-name> <resource-id>

# Check import status
terraform state show <resource-type>.<resource-name>

# Plan to verify
terraform plan
```

**Solution 3: Remove and Recreate Resources**
```bash
# Remove from state
terraform state rm <resource-type>.<resource-name>

# Recreate resource
terraform apply

# Check resource status
terraform state show <resource-type>.<resource-name>
```

## Application Issues

### Issue: Application Not Starting

#### Symptoms
- Application pods not ready
- Application crashes
- Health check failures

#### Solutions

**Solution 1: Check Application Logs**
```bash
# Check pod logs
kubectl logs <pod-name> -n <namespace>

# Check previous container logs
kubectl logs <pod-name> -n <namespace> --previous

# Follow logs in real-time
kubectl logs -f <pod-name> -n <namespace>
```

**Solution 2: Check Application Configuration**
```bash
# Check deployment configuration
kubectl describe deployment <deployment-name> -n <namespace>

# Check configmap
kubectl describe configmap <configmap-name> -n <namespace>

# Check secrets
kubectl describe secret <secret-name> -n <namespace>
```

**Solution 3: Check Resource Limits**
```bash
# Check resource usage
kubectl top pods -n <namespace>

# Check resource limits
kubectl describe pod <pod-name> -n <namespace> | grep -A 5 "Limits:"

# Update resource limits
kubectl patch deployment <deployment-name> -n <namespace> -p '{"spec":{"template":{"spec":{"containers":[{"name":"<container-name>","resources":{"limits":{"memory":"256Mi","cpu":"200m"}}}]}}}}'
```

### Issue: Application Performance Issues

#### Symptoms
- Slow response times
- High resource usage
- Timeout errors

#### Solutions

**Solution 1: Check Resource Usage**
```bash
# Check pod resource usage
kubectl top pods -n <namespace>

# Check node resource usage
kubectl top nodes

# Check resource limits
kubectl describe pod <pod-name> -n <namespace> | grep -A 5 "Limits:"
```

**Solution 2: Check Application Metrics**
```bash
# Access monitoring dashboard
make monitoring-access

# This will set up access to:
# - Prometheus: http://localhost:9090
# - Grafana: http://localhost:3000
# - Monitoring Dashboard: http://localhost:8081
```

**Solution 3: Scale Application**
```bash
# Scale deployment
kubectl scale deployment <deployment-name> -n <namespace> --replicas=3

# Check scaling status
kubectl get pods -n <namespace>

# Set up horizontal pod autoscaler
kubectl autoscale deployment <deployment-name> -n <namespace> --cpu-percent=70 --min=2 --max=10
```

## Network Issues

### Issue: Network Connectivity Problems

#### Symptoms
- Services not reachable
- DNS resolution failures
- Connection timeouts

#### Solutions

**Solution 1: Check Network Policies**
```bash
# Check network policies
kubectl get networkpolicies -A

# Check if policies are blocking traffic
kubectl describe networkpolicy <policy-name> -n <namespace>

# Test connectivity
kubectl run test-pod --image=busybox -it --rm -- nslookup <service-name>
```

**Solution 2: Check DNS Configuration**
```bash
# Check DNS pods
kubectl get pods -n kube-system | grep dns

# Check DNS configuration
kubectl get configmap coredns -n kube-system -o yaml

# Test DNS resolution
kubectl run test-pod --image=busybox -it --rm -- nslookup kubernetes.default
```

**Solution 3: Check Service Discovery**
```bash
# Check services
kubectl get services -A

# Check endpoints
kubectl get endpoints -A

# Test service connectivity
kubectl run test-pod --image=busybox -it --rm -- wget -qO- <service-name>.<namespace>.svc.cluster.local
```

## Storage Issues

### Issue: Persistent Volume Issues

#### Symptoms
- Pods stuck in Pending state
- Volume mount failures
- Storage not accessible

#### Solutions

**Solution 1: Check Persistent Volumes**
```bash
# Check persistent volumes
kubectl get pv

# Check persistent volume claims
kubectl get pvc -A

# Check volume status
kubectl describe pv <pv-name>
```

**Solution 2: Check Storage Classes**
```bash
# Check storage classes
kubectl get storageclass

# Check default storage class
kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}'

# Set default storage class
kubectl patch storageclass <storage-class-name> -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

**Solution 3: Check Volume Mounts**
```bash
# Check pod volume mounts
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 "Mounts:"

# Check volume status
kubectl get events -n <namespace> | grep <pod-name>

# Check volume permissions
kubectl exec <pod-name> -n <namespace> -- ls -la <mount-path>
```

## Security Issues

### Issue: Pod Security Policy Violations

#### Symptoms
- Pods not starting due to security policy violations
- Security context errors
- Permission denied errors

#### Solutions

**Solution 1: Check Pod Security Standards**
```bash
# Check pod security standards
kubectl get psp

# Check pod security context
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 "Security Context:"

# Check security policies
kubectl get networkpolicies -A
```

**Solution 2: Update Security Context**
```bash
# Update deployment security context
kubectl patch deployment <deployment-name> -n <namespace> -p '{"spec":{"template":{"spec":{"securityContext":{"runAsNonRoot":true,"runAsUser":1000},"containers":[{"name":"<container-name>","securityContext":{"allowPrivilegeEscalation":false,"readOnlyRootFilesystem":true}}]}}}}'
```

**Solution 3: Check RBAC Permissions**
```bash
# Check service account permissions
kubectl get rolebindings -A
kubectl get clusterrolebindings

# Check service account
kubectl describe serviceaccount <service-account-name> -n <namespace>

# Update RBAC permissions
kubectl create rolebinding <role-binding-name> -n <namespace> --role=<role-name> --serviceaccount=<namespace>:<service-account-name>
```

## Performance Issues

### Issue: High Resource Usage

#### Symptoms
- High CPU usage
- High memory usage
- Slow performance

#### Solutions

**Solution 1: Check Resource Usage**
```bash
# Check pod resource usage
kubectl top pods -A

# Check node resource usage
kubectl top nodes

# Check resource limits
kubectl describe pod <pod-name> -n <namespace> | grep -A 5 "Limits:"
```

**Solution 2: Optimize Resource Limits**
```bash
# Update resource limits
kubectl patch deployment <deployment-name> -n <namespace> -p '{"spec":{"template":{"spec":{"containers":[{"name":"<container-name>","resources":{"limits":{"memory":"512Mi","cpu":"500m"},"requests":{"memory":"256Mi","cpu":"250m"}}}]}}}}'
```

**Solution 3: Scale Resources**
```bash
# Scale deployment
kubectl scale deployment <deployment-name> -n <namespace> --replicas=5

# Set up horizontal pod autoscaler
kubectl autoscale deployment <deployment-name> -n <namespace> --cpu-percent=70 --min=3 --max=10

# Check scaling status
kubectl get hpa -n <namespace>
```

### Issue: Slow Application Response

#### Symptoms
- High latency
- Timeout errors
- Slow database queries

#### Solutions

**Solution 1: Check Application Metrics**
```bash
# Access monitoring dashboard
make monitoring-access

# Check specific metrics (after monitoring is accessible)
curl "http://localhost:9090/api/v1/query?query=up"
curl "http://localhost:9090/api/v1/query?query=rate(http_requests_total[5m])"
```

**Solution 2: Check Database Performance**
```bash
# Check database connections
kubectl exec -it <postgresql-pod> -n <namespace> -- psql -U postgres -c "SELECT * FROM pg_stat_activity;"

# Check database performance
kubectl exec -it <postgresql-pod> -n <namespace> -- psql -U postgres -c "SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;"
```

**Solution 3: Check Cache Performance**
```bash
# Check Redis performance
kubectl exec -it <redis-pod> -n <namespace> -- redis-cli info stats

# Check cache hit rate
kubectl exec -it <redis-pod> -n <namespace> -- redis-cli info stats | grep keyspace
```

## Getting Help

### Log Collection
When reporting issues, collect the following logs:

```bash
# Collect system information
kubectl cluster-info
kubectl get nodes
kubectl get pods -A

# Collect application logs
kubectl logs <pod-name> -n <namespace> > app-logs.txt

# Collect system logs
kubectl logs -n kube-system <system-pod> > system-logs.txt

# Collect ArgoCD logs
kubectl logs -n argocd deployment/argocd-server > argocd-logs.txt
```

### Support Channels
- **GitHub Issues**: [Create an issue](https://github.com/comind-pro/comind-ops/issues)
- **Documentation**: [Platform Documentation](https://github.com/comind-pro/comind-ops/docs)
- **Community**: [Discord Server](https://discord.gg/comind-ops)

### Emergency Contacts
- **Critical Issues**: security@comind-ops.com
- **General Support**: support@comind-ops.com
- **Documentation**: docs@comind-ops.com
