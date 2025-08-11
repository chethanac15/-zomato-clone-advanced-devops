#!/bin/bash

# Deployment script for Zomato Clone Advanced DevOps Project

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        error "Node.js is not installed"
    fi
    
    # Check npm
    if ! command -v npm &> /dev/null; then
        error "npm is not installed"
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed"
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is not installed"
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        warn "kubectl is not installed - Kubernetes deployment will be skipped"
        SKIP_K8S=true
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        warn "Terraform is not installed - Infrastructure deployment will be skipped"
        SKIP_TERRAFORM=true
    fi
    
    log "Prerequisites check complete"
}

# Function to install dependencies
install_dependencies() {
    log "Installing dependencies..."
    npm install
    log "Dependencies installed successfully"
}

# Function to run tests
run_tests() {
    log "Running tests..."
    npm test
    log "Tests completed successfully"
}

# Function to build application
build_application() {
    log "Building application..."
    npm run build
    log "Application built successfully"
}

# Function to build Docker image
build_docker_image() {
    log "Building Docker image..."
    npm run docker:build
    log "Docker image built successfully"
}

# Function to start Docker services
start_docker_services() {
    log "Starting Docker services..."
    npm run docker:compose
    log "Docker services started successfully"
}

# Function to deploy to Kubernetes
deploy_kubernetes() {
    if [ "$SKIP_K8S" = true ]; then
        warn "Skipping Kubernetes deployment"
        return
    fi
    
    log "Deploying to Kubernetes..."
    npm run k8s:deploy
    log "Kubernetes deployment completed successfully"
}

# Function to setup monitoring
setup_monitoring() {
    if [ "$SKIP_K8S" = true ]; then
        warn "Skipping monitoring setup (requires Kubernetes)"
        return
    fi
    
    log "Setting up monitoring stack..."
    npm run monitoring:setup
    log "Monitoring setup completed successfully"
}

# Function to setup security
setup_security() {
    if [ "$SKIP_K8S" = true ]; then
        warn "Skipping security setup (requires Kubernetes)"
        return
    fi
    
    log "Setting up security tools..."
    npm run security:setup
    log "Security setup completed successfully"
}

# Function to setup OpenKruise
setup_openkruise() {
    if [ "$SKIP_K8S" = true ]; then
        warn "Skipping OpenKruise setup (requires Kubernetes)"
        return
    fi
    
    log "Setting up OpenKruise..."
    npm run openkruise:setup
    log "OpenKruise setup completed successfully"
}

# Function to deploy infrastructure
deploy_infrastructure() {
    if [ "$SKIP_TERRAFORM" = true ]; then
        warn "Skipping infrastructure deployment"
        return
    fi
    
    log "Deploying infrastructure with Terraform..."
    npm run terraform:init
    npm run terraform:plan
    npm run terraform:apply
    log "Infrastructure deployment completed successfully"
}

# Function to run chaos tests
run_chaos_tests() {
    if [ "$SKIP_K8S" = true ]; then
        warn "Skipping chaos tests (requires Kubernetes)"
        return
    fi
    
    log "Running chaos engineering tests..."
    npm run chaos:test
    log "Chaos tests completed successfully"
}

# Function to check application health
check_health() {
    log "Checking application health..."
    
    # Wait for application to be ready
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s http://localhost:3000/health &> /dev/null; then
            log "Application is healthy"
            return 0
        fi
        
        info "Waiting for application to be ready... (attempt $attempt/$max_attempts)"
        sleep 10
        attempt=$((attempt + 1))
    done
    
    error "Application failed to become healthy after $max_attempts attempts"
}

# Function to display deployment status
show_status() {
    log "Deployment status:"
    echo
    echo "=== Running Services ==="
    docker-compose ps
    echo
    echo "=== Application Status ==="
    if curl -s http://localhost:3000/health &> /dev/null; then
        echo "✅ Application is running and healthy"
    else
        echo "❌ Application is not responding"
    fi
    echo
    echo "=== Access URLs ==="
    echo "Application: http://localhost:3000"
    echo "Health Check: http://localhost:3000/health"
    echo "API Docs: http://localhost:3000/api-docs"
    echo "Metrics: http://localhost:3000/metrics"
    
    if [ "$SKIP_K8S" != true ]; then
        echo "Grafana: http://localhost:3001 (admin/admin)"
        echo "Prometheus: http://localhost:9090"
    fi
    
    echo "SonarQube: http://localhost:9000"
    echo "Jenkins: http://localhost:8080"
    echo
    echo "=== Database ==="
    echo "PostgreSQL: localhost:5432"
    echo "Redis: localhost:6379"
}

# Function to cleanup on failure
cleanup() {
    error "Deployment failed. Cleaning up..."
    docker-compose down
    exit 1
}

# Main deployment function
main() {
    local environment=${1:-development}
    
    log "Starting deployment for environment: $environment"
    
    # Set trap for cleanup on failure
    trap cleanup ERR
    
    # Check prerequisites
    check_prerequisites
    
    # Install dependencies
    install_dependencies
    
    # Run tests
    run_tests
    
    # Build application
    build_application
    
    # Build Docker image
    build_docker_image
    
    # Start Docker services
    start_docker_services
    
    # Deploy infrastructure if production
    if [ "$environment" = "production" ] && [ "$SKIP_TERRAFORM" != true ]; then
        deploy_infrastructure
    fi
    
    # Deploy to Kubernetes if available
    deploy_kubernetes
    
    # Setup monitoring if available
    setup_monitoring
    
    # Setup security if available
    setup_security
    
    # Setup OpenKruise if available
    setup_openkruise
    
    # Check application health
    check_health
    
    # Run chaos tests if available
    run_chaos_tests
    
    # Show final status
    show_status
    
    log "Deployment completed successfully!"
}

# Parse command line arguments
case "${1:-development}" in
    "development"|"dev")
        main "development"
        ;;
    "staging"|"stage")
        main "staging"
        ;;
    "production"|"prod")
        main "production"
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [environment]"
        echo
        echo "Environments:"
        echo "  development  - Development environment (default)"
        echo "  staging      - Staging environment"
        echo "  production   - Production environment"
        echo
        echo "Examples:"
        echo "  $0                    # Deploy to development"
        echo "  $0 staging            # Deploy to staging"
        echo "  $0 production         # Deploy to production"
        ;;
    *)
        error "Unknown environment: $1. Use 'help' for available options."
        ;;
esac
