const logger = require('./logger');

// Health check implementation
const health = (req, res) => {
  const healthData = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    service: 'sample-app',
    version: '1.0.0',
    checks: {
      database: checkDatabase(),
      storage: checkStorage(),
      queue: checkQueue(),
      cache: checkCache()
    }
  };

  const allHealthy = Object.values(healthData.checks).every(check => check.status === 'ok');
  
  if (allHealthy) {
    res.status(200).json(healthData);
  } else {
    res.status(503).json(healthData);
  }
};

// Readiness probe - app is ready to receive traffic
const readiness = (req, res) => {
  const readinessData = {
    status: 'ready',
    timestamp: new Date().toISOString(),
    service: 'sample-app',
    dependencies: {
      database: process.env.DATABASE_ENABLED === 'true' ? checkDatabase() : { status: 'disabled' },
      storage: process.env.STORAGE_ENABLED === 'true' ? checkStorage() : { status: 'disabled' },
      queue: process.env.QUEUE_ENABLED === 'true' ? checkQueue() : { status: 'disabled' },
      cache: process.env.CACHE_ENABLED === 'true' ? checkCache() : { status: 'disabled' }
    }
  };

  const allReady = Object.values(readinessData.dependencies).every(dep => 
    dep.status === 'ok' || dep.status === 'disabled'
  );

  if (allReady) {
    res.status(200).json(readinessData);
  } else {
    res.status(503).json(readinessData);
  }
};

// Liveness probe - app is alive and functioning
const liveness = (req, res) => {
  const livenessData = {
    status: 'alive',
    timestamp: new Date().toISOString(),
    service: 'sample-app',
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    cpu: process.cpuUsage()
  };

  res.status(200).json(livenessData);
};

// Individual service checks
function checkDatabase() {
  if (process.env.DATABASE_ENABLED !== 'true') {
    return { status: 'disabled' };
  }

  // In a real app, you would actually test the database connection
  // For demo purposes, we'll simulate it
  try {
    // Simulate database check
    if (process.env.DATABASE_HOST && process.env.DATABASE_PORT) {
      return {
        status: 'ok',
        host: process.env.DATABASE_HOST,
        port: process.env.DATABASE_PORT,
        database: process.env.DATABASE_NAME || 'default'
      };
    } else {
      return {
        status: 'error',
        message: 'Database connection not configured'
      };
    }
  } catch (error) {
    logger.error('Database health check failed', { error: error.message });
    return {
      status: 'error',
      message: error.message
    };
  }
}

function checkStorage() {
  if (process.env.STORAGE_ENABLED !== 'true') {
    return { status: 'disabled' };
  }

  try {
    // Simulate storage check
    if (process.env.STORAGE_ENDPOINT) {
      return {
        status: 'ok',
        endpoint: process.env.STORAGE_ENDPOINT,
        buckets: process.env.STORAGE_BUCKETS?.split(',') || []
      };
    } else {
      return {
        status: 'error',
        message: 'Storage endpoint not configured'
      };
    }
  } catch (error) {
    logger.error('Storage health check failed', { error: error.message });
    return {
      status: 'error',
      message: error.message
    };
  }
}

function checkQueue() {
  if (process.env.QUEUE_ENABLED !== 'true') {
    return { status: 'disabled' };
  }

  try {
    // Simulate queue check
    if (process.env.QUEUE_ENDPOINT) {
      return {
        status: 'ok',
        endpoint: process.env.QUEUE_ENDPOINT,
        queues: process.env.QUEUE_QUEUES?.split(',') || []
      };
    } else {
      return {
        status: 'error',
        message: 'Queue endpoint not configured'
      };
    }
  } catch (error) {
    logger.error('Queue health check failed', { error: error.message });
    return {
      status: 'error',
      message: error.message
    };
  }
}

function checkCache() {
  if (process.env.CACHE_ENABLED !== 'true') {
    return { status: 'disabled' };
  }

  try {
    // Simulate cache check
    if (process.env.CACHE_ENDPOINT) {
      return {
        status: 'ok',
        endpoint: process.env.CACHE_ENDPOINT,
        port: process.env.CACHE_PORT || '6379'
      };
    } else {
      return {
        status: 'error',
        message: 'Cache endpoint not configured'
      };
    }
  } catch (error) {
    logger.error('Cache health check failed', { error: error.message });
    return {
      status: 'error',
      message: error.message
    };
  }
}

module.exports = {
  health,
  readiness,
  liveness
};
