#!/bin/bash
# Service Wrapper Template
# Generated wrapper script for service management

set -euo pipefail

# Service configuration
SERVICE_NAME="${SERVICE_NAME:-${service_name}}"
SERVICE_TYPE="${SERVICE_TYPE:-${module_type}}"
ENVIRONMENT="${ENVIRONMENT:-${environment}}"

# Source the actual service implementation
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
SERVICE_SCRIPT="${BASE_DIR}/modules/${module_type}/service.sh"

if [ ! -f "$SERVICE_SCRIPT" ]; then
    echo "Error: Service script not found: $SERVICE_SCRIPT" >&2
    exit 1
fi

# Source the service implementation
source "$SERVICE_SCRIPT"

# Override service name and type
SERVICE_NAME="${service_name}"
SERVICE_TYPE="${module_type}"

# Run the main function with all arguments
main "$@"
