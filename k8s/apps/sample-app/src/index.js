const express = require('express');
const prometheus = require('prom-client');
const healthcheck = require('./healthcheck');
const logger = require('./logger');

const app = express();
const port = process.env.PORT || 8080;

// Prometheus metrics
const httpRequestDuration = new prometheus.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code']
});

const httpRequestsTotal = new prometheus.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

// Middleware for metrics
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route ? req.route.path : req.path;
    
    httpRequestDuration
      .labels(req.method, route, res.statusCode.toString())
      .observe(duration);
      
    httpRequestsTotal
      .labels(req.method, route, res.statusCode.toString())
      .inc();
  });
  
  next();
});

// Basic middleware
app.use(express.json());
app.use(express.static('public'));

// Logging middleware
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.path}`, { 
    method: req.method,
    path: req.path,
    ip: req.ip,
    userAgent: req.get('User-Agent')
  });
  next();
});

// Routes
app.get('/', (req, res) => {
  res.json({
    message: 'Welcome to Comind-Ops Sample Application!',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    platform: 'comind-ops',
    environment: process.env.NODE_ENV || 'development'
  });
});

app.get('/api/info', (req, res) => {
  res.json({
    app: {
      name: 'sample-app',
      version: '1.0.0',
      description: 'Sample application demonstrating Comind-Ops Platform capabilities'
    },
    platform: {
      name: 'comind-ops',
      features: {
        database: process.env.DATABASE_ENABLED === 'true',
        storage: process.env.STORAGE_ENABLED === 'true',
        queue: process.env.QUEUE_ENABLED === 'true',
        cache: process.env.CACHE_ENABLED === 'true'
      }
    },
    runtime: {
      node: process.version,
      platform: process.platform,
      arch: process.arch,
      memory: process.memoryUsage(),
      uptime: process.uptime()
    }
  });
});

app.get('/api/config', (req, res) => {
  const config = {
    database: {
      enabled: process.env.DATABASE_ENABLED === 'true',
      host: process.env.DATABASE_HOST,
      port: process.env.DATABASE_PORT,
      name: process.env.DATABASE_NAME
    },
    storage: {
      enabled: process.env.STORAGE_ENABLED === 'true',
      endpoint: process.env.STORAGE_ENDPOINT,
      buckets: process.env.STORAGE_BUCKETS?.split(',') || []
    },
    queue: {
      enabled: process.env.QUEUE_ENABLED === 'true',
      endpoint: process.env.QUEUE_ENDPOINT,
      queues: process.env.QUEUE_QUEUES?.split(',') || []
    },
    cache: {
      enabled: process.env.CACHE_ENABLED === 'true',
      endpoint: process.env.CACHE_ENDPOINT,
      port: process.env.CACHE_PORT
    }
  };
  
  res.json(config);
});

// Health check endpoints
app.get('/health', healthcheck.health);
app.get('/ready', healthcheck.readiness);
app.get('/live', healthcheck.liveness);

// Metrics endpoint
app.get('/metrics', (req, res) => {
  res.set('Content-Type', prometheus.register.contentType);
  res.end(prometheus.register.metrics());
});

// Error handling
app.use((err, req, res, next) => {
  logger.error('Unhandled error', { error: err.message, stack: err.stack });
  res.status(500).json({ error: 'Internal Server Error' });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not Found' });
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  process.exit(0);
});

// Start server
app.listen(port, '0.0.0.0', () => {
  logger.info(`Sample app listening on port ${port}`, { port, nodeEnv: process.env.NODE_ENV });
});
