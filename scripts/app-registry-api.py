#!/usr/bin/env python3
"""
App Registry API for Comind-Ops Platform
Provides REST API for registering and managing applications
"""

import json
import os
import subprocess
import tempfile
import yaml
from datetime import datetime
from flask import Flask, request, jsonify, render_template_string
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# In-memory storage for demo (use database in production)
apps_registry = {}
teams = ["platform", "backend", "frontend", "mobile", "data", "devops"]

# HTML template for the web interface
HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Comind-Ops Platform - App Registry</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: white;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
        }
        .card {
            background: rgba(255, 255, 255, 0.1);
            border-radius: 15px;
            padding: 20px;
            margin-bottom: 20px;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
        }
        .form-group {
            margin-bottom: 15px;
        }
        label {
            display: block;
            margin-bottom: 5px;
            font-weight: 500;
        }
        input, select, textarea {
            width: 100%;
            padding: 10px;
            border: none;
            border-radius: 8px;
            background: rgba(255, 255, 255, 0.2);
            color: white;
            font-size: 14px;
        }
        input::placeholder, textarea::placeholder {
            color: rgba(255, 255, 255, 0.7);
        }
        button {
            background: rgba(255, 255, 255, 0.2);
            border: none;
            padding: 12px 24px;
            border-radius: 8px;
            color: white;
            font-size: 16px;
            cursor: pointer;
            transition: background 0.3s;
        }
        button:hover {
            background: rgba(255, 255, 255, 0.3);
        }
        .grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
        }
        .app-list {
            max-height: 400px;
            overflow-y: auto;
        }
        .app-item {
            background: rgba(255, 255, 255, 0.1);
            padding: 15px;
            border-radius: 10px;
            margin-bottom: 10px;
        }
        .app-name {
            font-weight: bold;
            font-size: 18px;
        }
        .app-meta {
            font-size: 14px;
            opacity: 0.8;
            margin-top: 5px;
        }
        .status {
            display: inline-block;
            padding: 4px 8px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: bold;
        }
        .status.registered {
            background: rgba(34, 197, 94, 0.3);
            color: #22c55e;
        }
        .status.pending {
            background: rgba(251, 191, 36, 0.3);
            color: #fbbf24;
        }
        .error {
            background: rgba(239, 68, 68, 0.3);
            color: #ef4444;
            padding: 10px;
            border-radius: 8px;
            margin-bottom: 15px;
        }
        .success {
            background: rgba(34, 197, 94, 0.3);
            color: #22c55e;
            padding: 10px;
            border-radius: 8px;
            margin-bottom: 15px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Comind-Ops Platform</h1>
            <p>Application Registry & Management</p>
        </div>

        <div class="grid">
            <div class="card">
                <h2>Register New Application</h2>
                <form id="appForm">
                    <div class="form-group">
                        <label for="name">Application Name *</label>
                        <input type="text" id="name" name="name" placeholder="my-awesome-app" required>
                    </div>
                    
                    <div class="form-group">
                        <label for="type">Application Type *</label>
                        <select id="type" name="type" required>
                            <option value="user">User Application</option>
                            <option value="platform">Platform Service</option>
                        </select>
                    </div>
                    
                    <div class="form-group">
                        <label for="team">Team *</label>
                        <select id="team" name="team" required>
                            <option value="">Select Team</option>
                            <option value="platform">Platform</option>
                            <option value="backend">Backend</option>
                            <option value="frontend">Frontend</option>
                            <option value="mobile">Mobile</option>
                            <option value="data">Data</option>
                            <option value="devops">DevOps</option>
                        </select>
                    </div>
                    
                    <div class="form-group">
                        <label for="repository">Repository URL *</label>
                        <input type="url" id="repository" name="repository" placeholder="https://github.com/org/repo" required>
                    </div>
                    
                    <div class="form-group">
                        <label for="description">Description</label>
                        <textarea id="description" name="description" rows="3" placeholder="Brief description of the application"></textarea>
                    </div>
                    
                    <div class="form-group">
                        <label for="port">Port</label>
                        <input type="number" id="port" name="port" value="8080" min="1" max="65535">
                    </div>
                    
                    <div class="form-group">
                        <label>
                            <input type="checkbox" id="autoSyncProd" name="autoSyncProd">
                            Enable auto-sync for production
                        </label>
                    </div>
                    
                    <button type="submit">Register Application</button>
                </form>
                
                <div id="message"></div>
            </div>
            
            <div class="card">
                <h2>Registered Applications</h2>
                <div id="appList" class="app-list">
                    <p>Loading applications...</p>
                </div>
            </div>
        </div>
    </div>

    <script>
        // Load applications on page load
        document.addEventListener('DOMContentLoaded', function() {
            loadApplications();
        });

        // Handle form submission
        document.getElementById('appForm').addEventListener('submit', function(e) {
            e.preventDefault();
            
            const formData = new FormData(this);
            const data = Object.fromEntries(formData.entries());
            
            // Convert checkbox to boolean
            data.autoSyncProd = document.getElementById('autoSyncProd').checked;
            
            fetch('/api/apps', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(data)
            })
            .then(response => response.json())
            .then(result => {
                if (result.success) {
                    showMessage('Application registered successfully!', 'success');
                    this.reset();
                    loadApplications();
                } else {
                    showMessage('Error: ' + result.error, 'error');
                }
            })
            .catch(error => {
                showMessage('Error: ' + error.message, 'error');
            });
        });

        function loadApplications() {
            fetch('/api/apps')
            .then(response => response.json())
            .then(data => {
                const appList = document.getElementById('appList');
                if (data.apps && data.apps.length > 0) {
                    appList.innerHTML = data.apps.map(app => `
                        <div class="app-item">
                            <div class="app-name">${app.name}</div>
                            <div class="app-meta">
                                Type: ${app.type} | Team: ${app.team} | Port: ${app.port}
                            </div>
                            <div class="app-meta">
                                Repository: ${app.repository}
                            </div>
                            <div class="app-meta">
                                Status: <span class="status ${app.status}">${app.status}</span>
                                | Registered: ${new Date(app.registered_at).toLocaleDateString()}
                            </div>
                        </div>
                    `).join('');
                } else {
                    appList.innerHTML = '<p>No applications registered yet.</p>';
                }
            })
            .catch(error => {
                document.getElementById('appList').innerHTML = '<p>Error loading applications.</p>';
            });
        }

        function showMessage(message, type) {
            const messageDiv = document.getElementById('message');
            messageDiv.innerHTML = `<div class="${type}">${message}</div>`;
            setTimeout(() => {
                messageDiv.innerHTML = '';
            }, 5000);
        }
    </script>
</body>
</html>
"""

@app.route('/')
def index():
    """Serve the main web interface"""
    return render_template_string(HTML_TEMPLATE)

@app.route('/api/apps', methods=['GET'])
def get_apps():
    """Get all registered applications"""
    return jsonify({
        'success': True,
        'apps': list(apps_registry.values())
    })

@app.route('/api/apps', methods=['POST'])
def register_app():
    """Register a new application"""
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['name', 'type', 'team', 'repository']
        for field in required_fields:
            if not data.get(field):
                return jsonify({
                    'success': False,
                    'error': f'Missing required field: {field}'
                }), 400
        
        app_name = data['name']
        
        # Check if app already exists
        if app_name in apps_registry:
            return jsonify({
                'success': False,
                'error': f'Application {app_name} already exists'
            }), 409
        
        # Prepare app data
        app_data = {
            'name': app_name,
            'type': data['type'],
            'team': data['team'],
            'repository': data['repository'],
            'description': data.get('description', ''),
            'port': int(data.get('port', 8080)),
            'environments': ['dev', 'stage', 'prod'],
            'auto_sync_prod': data.get('autoSyncProd', False),
            'status': 'registered',
            'registered_at': datetime.now().isoformat(),
            'chart_path': f"k8s/charts/{data['type']}/{app_name}",
            'argocd_path': f"k8s/kustomize/{data['type']}"
        }
        
        # Call the registration script
        try:
            result = register_app_script(app_data)
            if result['success']:
                apps_registry[app_name] = app_data
                return jsonify({
                    'success': True,
                    'message': f'Application {app_name} registered successfully',
                    'app': app_data
                })
            else:
                return jsonify({
                    'success': False,
                    'error': result['error']
                }), 500
        except Exception as e:
            return jsonify({
                'success': False,
                'error': f'Registration failed: {str(e)}'
            }), 500
            
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'Invalid request: {str(e)}'
        }), 400

@app.route('/api/apps/<app_name>', methods=['DELETE'])
def delete_app(app_name):
    """Delete an application"""
    if app_name not in apps_registry:
        return jsonify({
            'success': False,
            'error': f'Application {app_name} not found'
        }), 404
    
    try:
        # Remove from registry
        del apps_registry[app_name]
        
        # TODO: Clean up Helm charts and ArgoCD applications
        # This would require additional implementation
        
        return jsonify({
            'success': True,
            'message': f'Application {app_name} deleted successfully'
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'Deletion failed: {str(e)}'
        }), 500

@app.route('/api/teams', methods=['GET'])
def get_teams():
    """Get available teams"""
    return jsonify({
        'success': True,
        'teams': teams
    })

def register_app_script(app_data):
    """Call the registration script with app data"""
    try:
        # Prepare script arguments
        cmd = [
            './scripts/register-app.sh',
            '--name', app_data['name'],
            '--type', app_data['type'],
            '--team', app_data['team'],
            '--repo', app_data['repository'],
            '--description', app_data['description'],
            '--port', str(app_data['port'])
        ]
        
        if app_data['auto_sync_prod']:
            cmd.append('--auto-sync-prod')
        
        # Run the script
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd=os.getcwd()
        )
        
        if result.returncode == 0:
            return {'success': True, 'output': result.stdout}
        else:
            return {'success': False, 'error': result.stderr}
            
    except Exception as e:
        return {'success': False, 'error': str(e)}

if __name__ == '__main__':
    print("🚀 Starting Comind-Ops Platform App Registry API...")
    print("📱 Web interface: http://localhost:5000")
    print("🔌 API endpoint: http://localhost:5000/api/apps")
    print("🛑 Press Ctrl+C to stop")
    
    app.run(host='0.0.0.0', port=5000, debug=True)
