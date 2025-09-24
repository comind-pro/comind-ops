# ===========================================
# Multi-stage Dockerfile for Sample Application
# Demonstrates best practices for container security
# ===========================================

# ===========================================
# BUILD STAGE
# ===========================================
FROM node:18-alpine AS builder

# Set build metadata
LABEL stage=builder
LABEL maintainer="Comind-Ops Platform Team <platform@comind-ops.io>"

# Create non-root user for build
RUN addgroup -g 1001 -S builder && \
    adduser -S builder -u 1001 -G builder

# Set working directory
WORKDIR /build

# Copy package files first (for better caching)
COPY --chown=builder:builder package*.json ./

# Switch to non-root user
USER builder

# Install dependencies
RUN npm ci --only=production && \
    npm cache clean --force

# Copy application source
COPY --chown=builder:builder src/ ./src/
COPY --chown=builder:builder public/ ./public/

# Build application (if build step exists)
# RUN npm run build

# ===========================================
# PRODUCTION STAGE
# ===========================================
FROM node:18-alpine AS production

# Set image metadata
LABEL name="comind-ops/sample-app"
LABEL version="1.0.0"
LABEL description="Sample application demonstrating Comind-Ops Platform capabilities"
LABEL maintainer="Comind-Ops Platform Team <platform@comind-ops.io>"
LABEL org.opencontainers.image.source="https://github.com/your-org/comind-ops-cloud-setup"
LABEL org.opencontainers.image.documentation="https://github.com/your-org/comind-ops-cloud-setup/blob/main/k8s/apps/sample-app/README.md"
LABEL org.opencontainers.image.licenses="MIT"

# Install security updates and required packages
RUN apk update && \
    apk upgrade && \
    apk add --no-cache \
        tini \
        curl \
        ca-certificates && \
    rm -rf /var/cache/apk/*

# Create non-root application user
RUN addgroup -g 1001 -S appuser && \
    adduser -S appuser -u 1001 -G appuser

# Set working directory
WORKDIR /app

# Copy built application from builder stage
COPY --from=builder --chown=appuser:appuser /build/node_modules ./node_modules
COPY --from=builder --chown=appuser:appuser /build/package*.json ./
COPY --from=builder --chown=appuser:appuser /build/src ./src
COPY --from=builder --chown=appuser:appuser /build/public ./public

# Create application directories
RUN mkdir -p /app/logs /app/tmp && \
    chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose application port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Use tini as init process
ENTRYPOINT ["/sbin/tini", "--"]

# Start application
CMD ["node", "src/index.js"]
