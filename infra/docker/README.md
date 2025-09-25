# Modular Docker Service System Documentation

## Overview

The modular Docker service system provides a flexible, extensible way to manage Docker services with an object-oriented programming pattern. It uses an abstract base class approach with concrete implementations for different service types.

## Architecture

### Directory Structure

```
infra/docker/
├── modules/
│   ├── base/                 # Abstract base service class
│   │   ├── service.sh        # Base service implementation
│   │   ├── main.tf          # Terraform base module
│   │   ├── templates/       # Service templates
│   │   └── scripts/         # Utility scripts
│   ├── postgresql/          # PostgreSQL service implementation
│   │   └── service.sh
│   ├── minio/               # MinIO service implementation
│   │   └── service.sh
│   ├── redis/               # Redis service implementation
│   │   └── service.sh
│   ├── elasticmq/           # ElasticMQ service implementation
│   │   └── service.sh
│   └── external/            # Generic external service implementation
│       └── service.sh
├── registry/
│   └── services.yaml        # Service registry configuration
└── services/
    ├── docker-manager.sh    # Main service orchestrator
    └── services-setup.sh    # Platform integration script
```

### Abstract Base Class

The base service class (`modules/base/service.sh`) defines the common interface:

```bash
# Abstract methods (must be implemented by concrete services)
function start() { ... }
function stop() { ... }
function restart() { ... }
function status() { ... }
function healthcheck() { ... }
function recover() { ... }
function build() { ... }
function configure() { ... }
function validate() { ... }
```

### Service Registry

The registry (`registry/services.yaml`) defines service configurations:

```yaml
services = {
  postgresql = {
    enabled = true
    module = "postgresql"
    config = {
      version = "15-alpine"
      port = 5432
      database = "comind_ops_dev"
      # ... other config
    }
    dependencies = []
    healthcheck = {
      command = "pg_isready -U ${username}"
      interval = "30s"
      timeout = "10s"
      retries = 3
    }
  }
  # ... other services
}
```

## Usage

### Direct Service Management

```bash
# Start a specific service
./infra/docker/services/docker-manager.sh start postgresql

# Check service status
./infra/docker/services/docker-manager.sh status postgresql

# Health check all services
./infra/docker/services/docker-manager.sh healthcheck-all

# List all services
./infra/docker/services/docker-manager.sh list
```

### Platform Integration

```bash
# Start all services (used by Makefile)
./infra/docker/services-setup.sh start

# Check service status
./infra/docker/services-setup.sh status

# Health check
./infra/docker/services-setup.sh healthcheck
```

### Individual Service Management

```bash
# Direct service management
./infra/docker/modules/postgresql/service.sh start
./infra/docker/modules/postgresql/service.sh status
./infra/docker/modules/postgresql/service.sh healthcheck
```

## Adding New Services

### 1. Create Service Implementation

Create a new directory under `modules/`:

```bash
mkdir -p infra/docker/modules/my-service
```

### 2. Implement Service Script

Create `infra/docker/modules/my-service/service.sh`:

```bash
#!/bin/bash
# My Service Implementation

set -euo pipefail

# Source the base service
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "${BASE_DIR}/modules/base/service.sh"

# Service-specific configuration
SERVICE_NAME="${SERVICE_NAME:-my-service}"
SERVICE_TYPE="${SERVICE_TYPE:-my-service}"
SERVICE_VERSION="${SERVICE_VERSION:-latest}"

# Override abstract methods
function start() {
    log "Starting my-service..."
    # Implementation here
}

function stop() {
    log "Stopping my-service..."
    # Implementation here
}

# ... implement other methods

# Export functions
export -f start stop status healthcheck recover build configure validate

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

### 3. Add to Registry

Add service configuration to `registry/services.yaml`:

```yaml
services = {
  my-service = {
    enabled = true
    module = "my-service"
    config = {
      version = "latest"
      port = 8080
      # ... service-specific config
    }
    dependencies = []
    healthcheck = {
      command = "curl -f http://localhost:8080/health"
      interval = "30s"
      timeout = "10s"
      retries = 3
    }
  }
}
```

### 4. Make Executable

```bash
chmod +x infra/docker/modules/my-service/service.sh
```

## Terraform Integration

The system includes Terraform modules for infrastructure management:

### Base Module

The base module (`modules/base/main.tf`) provides:
- Docker network creation
- Directory structure setup
- Service configuration file generation
- Service monitoring

### Usage in Terraform

```hcl
module "docker_services" {
  source = "./infra/docker/modules/base"
  
  registry_file    = "./infra/docker/registry/services.yaml"
  environment      = "dev"
  network_name     = "comind-ops-network"
  data_directory   = "./data"
}
```

## Benefits

1. **Modularity**: Easy to add new services without modifying existing code
2. **Consistency**: All services follow the same interface pattern
3. **Extensibility**: Abstract base class allows for easy extension
4. **Registry-based**: Configuration-driven service management
5. **Terraform Integration**: Infrastructure as code for service management
6. **Health Monitoring**: Built-in health checking and recovery
7. **Platform Integration**: Seamless integration with existing platform scripts

## Service Types

### Core Services
- **postgresql**: Database service
- **minio**: Object storage service
- **redis**: Caching service (optional)
- **elasticmq**: Message queue service (optional)

### External Services
- **external**: Generic service for any Docker image
- Can be configured via registry for any external service

## Future Enhancements

1. **Service Discovery**: Automatic service discovery and registration
2. **Load Balancing**: Built-in load balancing for multiple instances
3. **Scaling**: Automatic scaling based on metrics
4. **Backup/Restore**: Automated backup and restore capabilities
5. **Monitoring**: Enhanced monitoring and alerting
6. **Security**: Enhanced security features and secrets management
