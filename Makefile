# Makefile for Zomato Clone Advanced DevOps Project

.PHONY: help install test build clean docker-build docker-run docker-compose k8s-deploy terraform-init terraform-plan terraform-apply monitoring-setup security-setup openkruise-setup chaos-test docs-generate performance-test load-test health-check lint lint-fix security-audit

# Default target
help:
	@echo "Available commands:"
	@echo "  install          - Install dependencies"
	@echo "  test            - Run tests"
	@echo "  build           - Build the application"
	@echo "  clean           - Clean build artifacts"
	@echo "  docker-build    - Build Docker image"
	@echo "  docker-run      - Run Docker container"
	@echo "  docker-compose  - Start all services with Docker Compose"
	@echo "  k8s-deploy      - Deploy to Kubernetes"
	@echo "  terraform-init  - Initialize Terraform"
	@echo "  terraform-plan  - Plan Terraform changes"
	@echo "  terraform-apply - Apply Terraform changes"
	@echo "  monitoring-setup - Setup monitoring stack"
	@echo "  security-setup  - Setup security tools"
	@echo "  openkruise-setup - Setup OpenKruise"
	@echo "  chaos-test      - Run chaos engineering tests"
	@echo "  docs-generate   - Generate documentation"
	@echo "  performance-test - Run performance tests"
	@echo "  load-test       - Run load tests"
	@echo "  health-check    - Check application health"
	@echo "  lint            - Run linting"
	@echo "  lint-fix        - Fix linting issues"
	@echo "  security-audit  - Run security audit"

# Install dependencies
install:
	@echo "Installing dependencies..."
	npm install

# Run tests
test:
	@echo "Running tests..."
	npm test

# Build the application
build:
	@echo "Building application..."
	npm run build

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	npm run clean

# Build Docker image
docker-build:
	@echo "Building Docker image..."
	npm run docker:build

# Run Docker container
docker-run:
	@echo "Running Docker container..."
	npm run docker:run

# Start all services with Docker Compose
docker-compose:
	@echo "Starting services with Docker Compose..."
	npm run docker:compose

# Deploy to Kubernetes
k8s-deploy:
	@echo "Deploying to Kubernetes..."
	npm run k8s:deploy

# Initialize Terraform
terraform-init:
	@echo "Initializing Terraform..."
	npm run terraform:init

# Plan Terraform changes
terraform-plan:
	@echo "Planning Terraform changes..."
	npm run terraform:plan

# Apply Terraform changes
terraform-apply:
	@echo "Applying Terraform changes..."
	npm run terraform:apply

# Setup monitoring stack
monitoring-setup:
	@echo "Setting up monitoring stack..."
	npm run monitoring:setup

# Setup security tools
security-setup:
	@echo "Setting up security tools..."
	npm run security:setup

# Setup OpenKruise
openkruise-setup:
	@echo "Setting up OpenKruise..."
	npm run openkruise:setup

# Run chaos engineering tests
chaos-test:
	@echo "Running chaos engineering tests..."
	npm run chaos:test

# Generate documentation
docs-generate:
	@echo "Generating documentation..."
	npm run docs:generate

# Run performance tests
performance-test:
	@echo "Running performance tests..."
	npm run performance:benchmark

# Run load tests
load-test:
	@echo "Running load tests..."
	npm run load:test

# Check application health
health-check:
	@echo "Checking application health..."
	npm run health:check

# Run linting
lint:
	@echo "Running linting..."
	npm run lint

# Fix linting issues
lint-fix:
	@echo "Fixing linting issues..."
	npm run lint:fix

# Run security audit
security-audit:
	@echo "Running security audit..."
	npm run security:audit

# Full development setup
dev-setup: install build test lint security-audit
	@echo "Development setup complete!"

# Full production deployment
prod-deploy: terraform-init terraform-plan terraform-apply k8s-deploy monitoring-setup security-setup openkruise-setup
	@echo "Production deployment complete!"

# Full testing suite
test-suite: test performance-test load-test chaos-test
	@echo "Testing suite complete!"
