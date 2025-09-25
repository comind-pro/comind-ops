# Platform Healing Architecture - Comind-Ops Platform

## Overview

The Comind-Ops platform uses a **layered healing architecture** with clear separation of concerns and delegation patterns.

## Architecture Components

### 1. Main Orchestrator: `platform-health.sh`
- **Role**: Platform-wide health monitoring and orchestration
- **Responsibilities**:
  - Coordinate healing across all platform components
  - Delegate specialized healing to component scripts
  - Provide comprehensive health reports
  - Monitor Kubernetes resources (pods, deployments, ingress)
  - ArgoCD health validation and recovery

### 2. External Services Specialist: `external-services.sh`
- **Role**: External Docker services management
- **Responsibilities**:
  - PostgreSQL configuration auto-fixing
  - Container restart loop detection and resolution
  - MinIO permission and bucket management
  - Service recreation for persistent issues
  - External service health monitoring

### 3. Application Specialists: (Future)
- **Role**: Application-specific healing logic
- **Examples**: `helm-health.sh`, `argocd-health.sh`, `ingress-health.sh`

## Healing Flow

```
User/System Issue
       ↓
platform-health.sh (Orchestrator)
       ↓
    Delegates to:
    ├── external-services.sh heal    (External services)
    ├── kubectl operations           (Kubernetes resources)
    ├── ingress connectivity checks  (Network layer)
    └── ArgoCD health validation     (GitOps layer)
       ↓
Comprehensive Recovery
```

## Command Structure

### Platform-Level Commands
```bash
# Comprehensive platform healing
./scripts/platform-health.sh heal

# Platform health assessment
./scripts/platform-health.sh check

# Health report generation
./scripts/platform-health.sh report
```

### Component-Level Commands
```bash
# External services only
./scripts/external-services.sh heal

# Service status
./scripts/external-services.sh status
```

## Benefits of This Architecture

### 1. **Clear Separation of Concerns**
- Each script has a single, well-defined responsibility
- No code duplication between scripts
- Easier to maintain and extend

### 2. **Delegation Pattern**
- Platform orchestrator delegates to specialists
- Component experts handle their domain
- Consistent interface across all healing operations

### 3. **Scalability**
- Easy to add new component healers
- Platform orchestrator remains simple
- Modular architecture supports growth

### 4. **Testability**
- Each component can be tested independently
- Integration testing through orchestrator
- Clear boundaries for unit testing

## Best Practices

### 1. **Single Responsibility Principle**
- Each script handles one domain
- No overlapping responsibilities
- Clear ownership of functionality

### 2. **Consistent Interface**
- All healing scripts use similar command structure
- Consistent return codes and logging
- Standardized error handling

### 3. **Graceful Degradation**
- If one component fails, others continue
- Non-critical issues don't stop platform operation
- Clear reporting of partial failures

## Adding New Healers

To add a new component healer:

1. Create a new script following the pattern: `scripts/component-health.sh`
2. Implement the `heal` command
3. Add delegation in `platform-health.sh`
4. Update this documentation

Example:
```bash
# In platform-health.sh
log "Step N: Healing component X..."
if "$SCRIPT_DIR/component-health.sh" heal; then
    success "Component X healing completed"
else
    warning "Component X healing had issues"
fi
```

## Monitoring and Alerting

The platform healing system provides:
- Comprehensive health reports
- Proactive issue detection
- Automated recovery actions
- Clear logging and audit trails

This architecture ensures the platform truly **manages itself** with minimal human intervention.
