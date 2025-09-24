// Simple structured logger for the sample application
const LOG_LEVEL = process.env.LOG_LEVEL || 'info';
const NODE_ENV = process.env.NODE_ENV || 'development';

const logLevels = {
  error: 0,
  warn: 1,
  info: 2,
  debug: 3
};

function shouldLog(level) {
  return logLevels[level] <= logLevels[LOG_LEVEL];
}

function formatMessage(level, message, meta = {}) {
  const timestamp = new Date().toISOString();
  
  const logEntry = {
    timestamp,
    level: level.toUpperCase(),
    message,
    service: 'sample-app',
    version: '1.0.0',
    environment: NODE_ENV,
    ...meta
  };

  if (NODE_ENV === 'development') {
    // Pretty print for development
    const metaStr = Object.keys(meta).length > 0 ? ` ${JSON.stringify(meta)}` : '';
    return `${timestamp} [${level.toUpperCase()}] ${message}${metaStr}`;
  } else {
    // JSON format for production (better for log aggregation)
    return JSON.stringify(logEntry);
  }
}

function log(level, message, meta = {}) {
  if (!shouldLog(level)) {
    return;
  }

  const formattedMessage = formatMessage(level, message, meta);
  
  if (level === 'error') {
    console.error(formattedMessage);
  } else if (level === 'warn') {
    console.warn(formattedMessage);
  } else {
    console.log(formattedMessage);
  }
}

module.exports = {
  error: (message, meta) => log('error', message, meta),
  warn: (message, meta) => log('warn', message, meta),
  info: (message, meta) => log('info', message, meta),
  debug: (message, meta) => log('debug', message, meta)
};
