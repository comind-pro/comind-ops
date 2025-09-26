#!/bin/bash

# Monitoring Dashboard Proxy Script
# Creates a simple proxy to access the monitoring dashboard without Host headers

set -e

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

PORT=${1:-8081}

echo -e "${BLUE}🚀 Starting Monitoring Dashboard Proxy on port $PORT...${NC}"

# Kill any existing proxy processes
pkill -f "monitoring-proxy" || true

# Create a simple Node.js proxy server
cat > /tmp/monitoring-proxy.js << 'EOF'
const http = require('http');
const httpProxy = require('http-proxy');

const proxy = httpProxy.createProxyServer({
  target: 'http://localhost:8080',
  changeOrigin: true,
  headers: {
    'Host': 'monitoring.dev.127.0.0.1.nip.io'
  }
});

const server = http.createServer((req, res) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
  proxy.web(req, res);
});

server.on('error', (err) => {
  console.error('Proxy server error:', err);
});

const PORT = process.env.PORT || 8081;
server.listen(PORT, () => {
  console.log(`Monitoring dashboard proxy running on http://localhost:${PORT}`);
  console.log('Access the dashboard at: http://localhost:' + PORT);
});
EOF

# Check if Node.js is available
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js is not installed. Installing a simple Python proxy instead...${NC}"
    
    # Create a Python proxy instead
    cat > /tmp/monitoring-proxy.py << 'EOF'
#!/usr/bin/env python3
import http.server
import socketserver
import urllib.request
import urllib.parse

class ProxyHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.proxy_request()
    
    def do_POST(self):
        self.proxy_request()
    
    def proxy_request(self):
        try:
            # Forward request to the port-forwarded service
            url = f"http://localhost:8080{self.path}"
            headers = {
                'Host': 'monitoring.dev.127.0.0.1.nip.io',
                'User-Agent': self.headers.get('User-Agent', ''),
                'Accept': self.headers.get('Accept', '*/*'),
                'Accept-Language': self.headers.get('Accept-Language', ''),
                'Accept-Encoding': self.headers.get('Accept-Encoding', ''),
                'Connection': 'keep-alive',
            }
            
            req = urllib.request.Request(url, headers=headers)
            response = urllib.request.urlopen(req)
            
            self.send_response(response.getcode())
            
            # Copy headers
            for header, value in response.headers.items():
                if header.lower() not in ['connection', 'transfer-encoding']:
                    self.send_header(header, value)
            self.end_headers()
            
            # Copy body
            self.wfile.write(response.read())
            
        except Exception as e:
            self.send_error(500, f"Proxy error: {str(e)}")
    
    def log_message(self, format, *args):
        print(f"{self.address_string()} - {format % args}")

if __name__ == "__main__":
    PORT = int(os.environ.get('PORT', 8081))
    with socketserver.TCPServer(("", PORT), ProxyHandler) as httpd:
        print(f"Monitoring dashboard proxy running on http://localhost:{PORT}")
        print("Access the dashboard at: http://localhost:" + str(PORT))
        httpd.serve_forever()
EOF
    
    # Make Python proxy executable
    chmod +x /tmp/monitoring-proxy.py
    
    # Start Python proxy
    PORT=$PORT /tmp/monitoring-proxy.py &
    PROXY_PID=$!
    
else
    # Check if http-proxy is available
    if ! npm list -g http-proxy &> /dev/null; then
        echo -e "${YELLOW}📦 Installing http-proxy package...${NC}"
        npm install -g http-proxy
    fi
    
    # Start Node.js proxy
    PORT=$PORT /tmp/monitoring-proxy.js &
    PROXY_PID=$!
fi

# Wait a moment for proxy to start
sleep 2

# Test the proxy
if curl -s http://localhost:$PORT >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Monitoring dashboard proxy is running!${NC}"
    echo -e "${GREEN}🌐 Access the dashboard at: http://localhost:$PORT${NC}"
    echo -e "${BLUE}💡 The proxy automatically handles the Host header for you${NC}"
    echo -e "${YELLOW}📝 Proxy PID: $PROXY_PID${NC}"
    echo -e "${YELLOW}🛑 To stop the proxy, run: kill $PROXY_PID${NC}"
else
    echo -e "${RED}❌ Failed to start proxy${NC}"
    exit 1
fi
