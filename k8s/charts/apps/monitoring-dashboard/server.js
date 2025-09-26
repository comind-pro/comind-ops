const express = require('express');
const axios = require('axios');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 8080;

// Middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'", "https://cdnjs.cloudflare.com"],
      scriptSrc: ["'self'", "'unsafe-inline'", "https://cdnjs.cloudflare.com"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'", "http://localhost:*", "https://*"]
    }
  }
}));
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.static('public'));

// Platform configuration
const PLATFORM_CONFIG = {
  name: 'Comind-Ops Platform',
  version: '1.0.0',
  environment: process.env.NODE_ENV || 'development',
  services: {
    argocd: {
      name: 'ArgoCD',
      url: 'http://argocd.dev.127.0.0.1.nip.io:8080',
      description: 'GitOps Continuous Delivery',
      icon: '🔄'
    },
    minio: {
      name: 'MinIO Console',
      url: 'http://localhost:9001',
      description: 'Object Storage Management',
      icon: '💾'
    },
    registry: {
      name: 'Container Registry',
      url: 'http://registry.dev.127.0.0.1.nip.io:8080',
      description: 'Private Container Registry',
      icon: '📦'
    },
    elasticmq: {
      name: 'ElasticMQ',
      url: 'http://elasticmq.dev.127.0.0.1.nip.io:8080',
      description: 'Message Queue Service',
      icon: '📬'
    }
  },
  credentials: {
    argocd: {
      username: 'admin',
      note: 'Password: Check ArgoCD secret or use kubectl'
    },
    minio: {
      username: 'comind_ops_minio_admin',
      password: 'comind_ops_minio_password'
    },
    postgresql: {
      host: 'localhost:5434',
      username: 'comind_ops_user',
      password: 'comind_ops_password',
      database: 'comind_ops_dev'
    }
  }
};

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    platform: PLATFORM_CONFIG.name,
    version: PLATFORM_CONFIG.version
  });
});

// API endpoint for service status
app.get('/api/services/status', async (req, res) => {
  const serviceStatuses = {};
  
  for (const [key, service] of Object.entries(PLATFORM_CONFIG.services)) {
    try {
      const response = await axios.get(service.url, {
        timeout: 5000,
        validateStatus: () => true // Accept any status code
      });
      serviceStatuses[key] = {
        name: service.name,
        status: response.status < 400 ? 'healthy' : 'warning',
        statusCode: response.status,
        responseTime: Date.now()
      };
    } catch (error) {
      serviceStatuses[key] = {
        name: service.name,
        status: 'unhealthy',
        error: error.message,
        responseTime: Date.now()
      };
    }
  }
  
  res.json(serviceStatuses);
});

// API endpoint for platform info
app.get('/api/platform/info', (req, res) => {
  res.json({
    ...PLATFORM_CONFIG,
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    nodeVersion: process.version,
    architecture: process.arch,
    platform: process.platform
  });
});

// Main dashboard route
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: 'The requested endpoint does not exist',
    availableEndpoints: [
      'GET /',
      'GET /health',
      'GET /api/services/status',
      'GET /api/platform/info'
    ]
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({
    error: 'Internal Server Error',
    message: 'Something went wrong on our end'
  });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Comind-Ops Monitoring Dashboard running on port ${PORT}`);
  console.log(`📊 Environment: ${PLATFORM_CONFIG.environment}`);
  console.log(`🌐 Access: http://localhost:${PORT}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('🛑 SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('🛑 SIGINT received, shutting down gracefully');
  process.exit(0);
});
