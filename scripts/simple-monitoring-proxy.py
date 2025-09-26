#!/usr/bin/env python3
"""
Simple Monitoring Dashboard Proxy
Provides easy access to the monitoring dashboard without Host headers
"""

import http.server
import socketserver
import urllib.request
import urllib.parse
import os
import sys
import signal
import threading
import time

class MonitoringProxyHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.proxy_request()
    
    def do_POST(self):
        self.proxy_request()
    
    def do_HEAD(self):
        self.proxy_request()
    
    def proxy_request(self):
        try:
            # Forward request to the port-forwarded service
            url = f"http://localhost:8080{self.path}"
            headers = {
                'Host': 'monitoring.dev.127.0.0.1.nip.io',
                'User-Agent': self.headers.get('User-Agent', 'Monitoring-Proxy/1.0'),
                'Accept': self.headers.get('Accept', '*/*'),
                'Accept-Language': self.headers.get('Accept-Language', ''),
                'Accept-Encoding': self.headers.get('Accept-Encoding', ''),
                'Connection': 'keep-alive',
            }
            
            # Add any additional headers
            for header in ['Content-Type', 'Authorization', 'Cookie']:
                if header in self.headers:
                    headers[header] = self.headers[header]
            
            req = urllib.request.Request(url, headers=headers)
            response = urllib.request.urlopen(req, timeout=30)
            
            self.send_response(response.getcode())
            
            # Copy headers (excluding problematic ones)
            for header, value in response.headers.items():
                if header.lower() not in ['connection', 'transfer-encoding', 'content-encoding']:
                    self.send_header(header, value)
            self.end_headers()
            
            # Copy body
            self.wfile.write(response.read())
            
        except urllib.error.HTTPError as e:
            self.send_error(e.code, f"Upstream error: {e.reason}")
        except urllib.error.URLError as e:
            self.send_error(502, f"Connection error: {str(e)}")
        except Exception as e:
            self.send_error(500, f"Proxy error: {str(e)}")
    
    def log_message(self, format, *args):
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] {self.address_string()} - {format % args}")

def check_port_forward():
    """Check if port forwarding is active"""
    try:
        req = urllib.request.Request('http://localhost:8080', headers={'Host': 'monitoring.dev.127.0.0.1.nip.io'})
        urllib.request.urlopen(req, timeout=5)
        return True
    except:
        return False

def start_proxy(port=8081):
    """Start the monitoring dashboard proxy"""
    print(f"🚀 Starting Monitoring Dashboard Proxy on port {port}...")
    
    # Check if port forwarding is active
    if not check_port_forward():
        print("❌ Port forwarding to localhost:8080 is not active.")
        print("💡 Please run: kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80")
        return False
    
    try:
        with socketserver.TCPServer(("", port), MonitoringProxyHandler) as httpd:
            print(f"✅ Monitoring dashboard proxy running on http://localhost:{port}")
            print(f"🌐 Access the dashboard at: http://localhost:{port}")
            print("💡 The proxy automatically handles the Host header for you")
            print("🛑 Press Ctrl+C to stop the proxy")
            
            # Handle graceful shutdown
            def signal_handler(sig, frame):
                print("\n🛑 Shutting down proxy...")
                httpd.shutdown()
                sys.exit(0)
            
            signal.signal(signal.SIGINT, signal_handler)
            signal.signal(signal.SIGTERM, signal_handler)
            
            httpd.serve_forever()
            
    except OSError as e:
        if e.errno == 48:  # Address already in use
            print(f"❌ Port {port} is already in use. Try a different port.")
            print(f"💡 Usage: {sys.argv[0]} [PORT]")
        else:
            print(f"❌ Failed to start proxy: {e}")
        return False
    except KeyboardInterrupt:
        print("\n🛑 Proxy stopped by user")
        return True

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8081
    start_proxy(port)
