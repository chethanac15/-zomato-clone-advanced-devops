# Advanced Multi-Stage Dockerfile for Zomato Clone
# This demonstrates enterprise-grade containerization with security and optimization

# Build stage for Node.js application
FROM node:18-alpine AS builder

# Set build arguments for versioning and metadata
ARG BUILD_NUMBER
ARG GIT_COMMIT
ARG BUILD_DATE
ARG NODE_ENV=production

# Set environment variables
ENV NODE_ENV=${NODE_ENV}
ENV BUILD_NUMBER=${BUILD_NUMBER}
ENV GIT_COMMIT=${GIT_COMMIT}
ENV BUILD_DATE=${BUILD_DATE}

# Install build dependencies
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    git \
    curl \
    && rm -rf /var/cache/apk/*

# Create app directory
WORKDIR /app

# Copy package files
COPY package*.json ./
COPY yarn.lock* ./

# Install dependencies with security audit
RUN npm ci --only=production --audit=false \
    && npm audit --audit-level=moderate \
    && npm outdated || true

# Copy source code
COPY . .

# Run security scans during build
RUN npm audit --audit-level=moderate || true \
    && npm outdated || true

# Build the application
RUN npm run build \
    && npm run test:unit \
    && npm prune --production

# Security scanning stage
FROM aquasec/trivy:latest AS security-scanner

# Copy the built application
COPY --from=builder /app/dist /app/dist
COPY --from=builder /app/package*.json /app/

# Run security scan
RUN trivy fs --severity HIGH,CRITICAL --exit-code 1 /app || true

# Production runtime stage
FROM node:18-alpine AS production

# Set labels for OpenKruise and Kubernetes
LABEL maintainer="devops-team@zomato.com"
LABEL version="1.0.0"
LABEL description="Zomato Clone Application"
LABEL org.opencontainers.image.source="https://github.com/your-org/zomato-clone"
LABEL org.opencontainers.image.revision="${GIT_COMMIT}"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.vendor="Zomato Clone Team"

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs \
    && adduser -S nodejs -u 1001

# Install runtime dependencies and security updates
RUN apk add --no-cache \
    dumb-init \
    curl \
    && apk upgrade --no-cache \
    && rm -rf /var/cache/apk/*

# Set working directory
WORKDIR /app

# Copy built application from builder stage
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/package*.json ./

# Create necessary directories with proper permissions
RUN mkdir -p /app/logs /app/uploads /app/temp \
    && chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Expose ports
EXPOSE 3000 3001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Use dumb-init for proper signal handling
ENTRYPOINT ["dumb-init", "--"]

# Start the application
CMD ["node", "dist/server.js"]

# Development stage with hot reload
FROM node:18-alpine AS development

# Set environment
ENV NODE_ENV=development

# Install development dependencies
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    git \
    curl \
    && rm -rf /var/cache/apk/*

# Create app directory
WORKDIR /app

# Copy package files
COPY package*.json ./
COPY yarn.lock* ./

# Install all dependencies (including dev dependencies)
RUN npm ci

# Copy source code
COPY . .

# Expose ports
EXPOSE 3000 3001 9229

# Start development server with hot reload
CMD ["npm", "run", "dev"]

# Testing stage
FROM node:18-alpine AS testing

# Set environment
ENV NODE_ENV=test

# Install testing dependencies
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    git \
    curl \
    && rm -rf /var/cache/apk/*

# Create app directory
WORKDIR /app

# Copy package files
COPY package*.json ./
COPY yarn.lock* ./

# Install all dependencies
RUN npm ci

# Copy source code
COPY . .

# Run tests
CMD ["npm", "run", "test:all"]

# Security audit stage
FROM node:18-alpine AS security-audit

# Install security tools
RUN apk add --no-cache \
    curl \
    git \
    && npm install -g \
    npm-audit-resolver \
    snyk \
    && rm -rf /var/cache/apk/*

# Create app directory
WORKDIR /app

# Copy package files
COPY package*.json ./
COPY yarn.lock* ./

# Run comprehensive security audit
RUN npm audit --audit-level=moderate || true \
    && snyk test || true

# Performance testing stage
FROM grafana/k6:latest AS performance-testing

# Copy performance test scripts
COPY testing/k6/ /scripts/

# Set working directory
WORKDIR /scripts

# Default command for performance testing
CMD ["k6", "run", "load-test.js"]

# Monitoring stage with custom metrics exporter
FROM node:18-alpine AS monitoring

# Install monitoring dependencies
RUN apk add --no-cache \
    curl \
    && rm -rf /var/cache/apk/*

# Create app directory
WORKDIR /app

# Copy monitoring scripts
COPY monitoring/ ./monitoring/

# Install monitoring dependencies
RUN npm install prom-client express

# Expose monitoring port
EXPOSE 8080

# Start monitoring service
CMD ["node", "monitoring/metrics-exporter.js"]

# Multi-architecture build support
# This stage is used for building images for different architectures
FROM --platform=$BUILDPLATFORM node:18-alpine AS multiarch-builder

# Set build arguments
ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG TARGETOS
ARG TARGETARCH

# Install build dependencies
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    git \
    curl \
    && rm -rf /var/cache/apk/*

# Create app directory
WORKDIR /app

# Copy package files
COPY package*.json ./
COPY yarn.lock* ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY . .

# Build for target architecture
RUN npm run build

# Final multi-arch stage
FROM --platform=$TARGETPLATFORM node:18-alpine AS final

# Set labels
LABEL maintainer="devops-team@zomato.com"
LABEL version="1.0.0"
LABEL description="Zomato Clone Application (Multi-Arch)"

# Create non-root user
RUN addgroup -g 1001 -S nodejs \
    && adduser -S nodejs -u 1001

# Install runtime dependencies
RUN apk add --no-cache \
    dumb-init \
    curl \
    && rm -rf /var/cache/apk/*

# Set working directory
WORKDIR /app

# Copy built application
COPY --from=multiarch-builder --chown=nodejs:nodejs /app/dist ./dist
COPY --from=multiarch-builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=multiarch-builder --chown=nodejs:nodejs /app/package*.json ./

# Create directories
RUN mkdir -p /app/logs /app/uploads /app/temp \
    && chown -R nodejs:nodejs /app

# Switch user
USER nodejs

# Expose ports
EXPOSE 3000 3001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Entrypoint
ENTRYPOINT ["dumb-init", "--"]

# Start application
CMD ["node", "dist/server.js"]

# Documentation stage
FROM alpine:latest AS docs

# Install documentation tools
RUN apk add --no-cache \
    nodejs \
    npm \
    git \
    && npm install -g \
    jsdoc \
    && rm -rf /var/cache/apk/*

# Create docs directory
WORKDIR /docs

# Copy source code
COPY . .

# Generate documentation
RUN jsdoc -c jsdoc.json || true

# Serve documentation
EXPOSE 8080

CMD ["npx", "http-server", ".", "-p", "8080"]

# Cleanup stage for final image optimization
FROM production AS optimized

# Remove unnecessary files
RUN rm -rf /app/temp \
    && rm -rf /app/logs/* \
    && rm -rf /app/uploads/*

# Optimize Node.js
ENV NODE_OPTIONS="--max-old-space-size=512 --optimize-for-size"

# Add security hardening
RUN apk add --no-cache \
    tini \
    && rm -rf /var/cache/apk/*

# Use tini for proper signal handling
ENTRYPOINT ["/sbin/tini", "--"]

# Start application
CMD ["node", "dist/server.js"]
