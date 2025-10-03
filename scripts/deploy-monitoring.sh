#!/bin/bash

# Deploy Monitoring Dashboard Script
# This script deploys the monitoring dashboard and sets up access

set -e

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to set up port forwarding
setup_port_forward() {
    echo -e "${YELLOW}🔗 Setting up port forwarding for monitoring dashboard...${NC}"
    
    # Kill any existing port forward processes
    pkill -f "kubectl port-forward.*ingress-nginx-controller" || true
    
    # Start port forwarding in background
    kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80 >/dev/null 2>&1 &
    PORT_FORWARD_PID=$!
    
    # Wait a moment for port forward to establish
    sleep 3
    
    # Test the port forward
    if curl -s -H "Host: monitoring.dev.127.0.0.1.nip.io" http://localhost:8080 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Monitoring dashboard accessible at: http://localhost:8080${NC}"
        echo -e "${GREEN}   (Use Host header: monitoring.dev.127.0.0.1.nip.io)${NC}"
        echo -e "${BLUE}💡 To access in browser, use: curl -H 'Host: monitoring.dev.127.0.0.1.nip.io' http://localhost:8080${NC}"
        
        # Start the simple proxy for easier access
        echo -e "${YELLOW}🚀 Starting monitoring dashboard proxy on port 8081...${NC}"
        python3 "$(dirname "$0")/simple-monitoring-proxy.py" 8081 >/dev/null 2>&1 &
        PROXY_PID=$!
        sleep 2
        
        if curl -s http://localhost:8081 >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Monitoring dashboard proxy running at: http://localhost:8081${NC}"
            echo -e "${GREEN}🌐 You can now access the dashboard directly in your browser!${NC}"
        else
            echo -e "${YELLOW}⚠️  Proxy failed to start, but port forwarding is available${NC}"
        fi
    else
        echo -e "${RED}❌ Failed to establish port forwarding${NC}"
        return 1
    fi
}

# Function to check if port forwarding is needed
check_access() {
    INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    if [ -n "$INGRESS_IP" ]; then
        # Test direct access
        if timeout 5 curl -s http://$INGRESS_IP >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Direct access available at: http://monitoring.dev.127.0.0.1.nip.io${NC}"
            return 0
        fi
    fi
    
    # Test port forward access
    if curl -s -H "Host: monitoring.dev.127.0.0.1.nip.io" http://localhost:8080 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Port forward access available at: http://localhost:8080${NC}"
        echo -e "${BLUE}💡 Use: curl -H 'Host: monitoring.dev.127.0.0.1.nip.io' http://localhost:8080${NC}"
        return 0
    fi
    
    return 1
}

echo -e "${BLUE}🚀 Deploying Monitoring Dashboard...${NC}"

# Deploy monitoring dashboard from charts if present
if [ -d "k8s/charts/apps/monitoring-dashboard" ]; then
    echo -e "${YELLOW}🔧 Deploying monitoring dashboard from charts...${NC}"
    # Retry Helm install/upgrade up to 3 times with longer timeout
    set +e
    for i in 1 2 3; do
        helm upgrade --install monitoring-dashboard k8s/charts/apps/monitoring-dashboard \
            -n monitoring-dashboard-dev \
            --create-namespace \
            -f k8s/charts/apps/monitoring-dashboard/values/dev.yaml \
            --wait --timeout=10m --atomic && break
        echo -e "${YELLOW}Retrying monitoring-dashboard install ($i/3)...${NC}"; sleep 10
    done
    set -e

    # Wait for deployment to be ready with retries
    echo -e "${YELLOW}⏳ Waiting for monitoring dashboard to be ready...${NC}"
    for i in 1 2 3 4 5; do
        if kubectl wait --for=condition=available --timeout=60s deployment/monitoring-dashboard -n monitoring-dashboard-dev; then
            break
        fi
        echo -e "${YELLOW}…not ready yet, retry $i/5${NC}"; sleep 6
    done
else
    echo -e "${YELLOW}⚠️  Monitoring dashboard chart not found at k8s/charts/apps/monitoring-dashboard. Skipping deployment...${NC}"
fi

# Check if ingress is accessible
echo -e "${YELLOW}🔍 Checking ingress accessibility...${NC}"
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -n "$INGRESS_IP" ]; then
    echo -e "${GREEN}✅ Ingress controller IP: $INGRESS_IP${NC}"
    
    # Test if the IP is accessible
    if timeout 5 curl -s http://$INGRESS_IP >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Monitoring dashboard accessible at: http://monitoring.dev.127.0.0.1.nip.io${NC}"
    else
        echo -e "${YELLOW}⚠️  Ingress IP not accessible from host. Setting up port forwarding...${NC}"
        setup_port_forward
    fi
else
    echo -e "${YELLOW}⚠️  No ingress IP assigned. Setting up port forwarding...${NC}"
    setup_port_forward
fi

echo -e "${GREEN}🎉 Monitoring dashboard deployment completed!${NC}"

# Main execution
if [ "$1" = "check" ]; then
    check_access
elif [ "$1" = "port-forward" ]; then
    setup_port_forward
else
    # Default: deploy and set up access
    setup_port_forward
fi
