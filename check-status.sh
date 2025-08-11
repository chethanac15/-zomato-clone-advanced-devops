#!/bin/bash

# Zomato Clone Advanced DevOps Project - Status Checker
# This script checks the status of all project components

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check Node.js application
check_node_app() {
    echo "=== Node.js Application Status ==="
    
    if [ -f .app.pid ]; then
        APP_PID=$(cat .app.pid)
        if ps -p $APP_PID > /dev/null; then
            echo "✅ Application is running (PID: $APP_PID)"
            
            # Check if application responds
            if command_exists curl; then
                if curl -s -f http://localhost:3000/health > /dev/null; then
                    echo "✅ Health check passed"
                else
                    echo "❌ Health check failed"
                fi
                
                if curl -s -f http://localhost:3000/metrics > /dev/null; then
                    echo "✅ Metrics endpoint accessible"
                else
                    echo "❌ Metrics endpoint not accessible"
                fi
            fi
        else
            echo "❌ Application PID file exists but process is not running"
        fi
    else
        echo "❌ Application is not running (no PID file)"
    fi
    echo
}

# Check Docker services
check_docker_services() {
    echo "=== Docker Services Status ==="
    
    if command_exists docker; then
        if docker info >/dev/null 2>&1; then
            echo "✅ Docker daemon is running"
            
            # Check running containers
            RUNNING_CONTAINERS=$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -v "NAMES")
            if [ -n "$RUNNING_CONTAINERS" ]; then
                echo "✅ Running containers:"
                echo "$RUNNING_CONTAINERS"
            else
                echo "❌ No containers are running"
            fi
            
            # Check docker-compose services
            if command_exists docker-compose; then
                if [ -f docker-compose.yml ]; then
                    echo "✅ Docker Compose file found"
                    docker-compose ps
                else
                    echo "❌ Docker Compose file not found"
                fi
            fi
        else
            echo "❌ Docker daemon is not running"
        fi
    else
        echo "❌ Docker is not installed"
    fi
    echo
}

# Check Kubernetes cluster
check_kubernetes() {
    echo "=== Kubernetes Cluster Status ==="
    
    if command_exists kubectl; then
        if kubectl cluster-info >/dev/null 2>&1; then
            echo "✅ Kubernetes cluster is accessible"
            
            # Check nodes
            NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
            if [ "$NODES" -gt 0 ]; then
                echo "✅ Cluster has $NODES node(s)"
                kubectl get nodes --no-headers | head -3
            else
                echo "❌ No nodes found in cluster"
            fi
            
            # Check namespaces
            NAMESPACES=$(kubectl get namespaces --no-headers 2>/dev/null | grep -c "zomato\|monitoring\|security" || echo "0")
            if [ "$NAMESPACES" -gt 0 ]; then
                echo "✅ Project namespaces found:"
                kubectl get namespaces | grep -E "(zomato|monitoring|security)"
            else
                echo "❌ Project namespaces not found"
            fi
            
            # Check pods
            PODS=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | grep -c "zomato\|monitoring\|security" || echo "0")
            if [ "$PODS" -gt 0 ]; then
                echo "✅ Project pods found:"
                kubectl get pods --all-namespaces | grep -E "(zomato|monitoring|security)" | head -5
            else
                echo "❌ Project pods not found"
            fi
        else
            echo "❌ Kubernetes cluster is not accessible"
        fi
    else
        echo "❌ kubectl is not installed"
    fi
    echo
}

# Check monitoring stack
check_monitoring() {
    echo "=== Monitoring Stack Status ==="
    
    # Check Prometheus
    if curl -s -f http://localhost:9090/-/healthy > /dev/null 2>&1; then
        echo "✅ Prometheus is running"
    else
        echo "❌ Prometheus is not accessible"
    fi
    
    # Check Grafana
    if curl -s -f http://localhost:3001/api/health > /dev/null 2>&1; then
        echo "✅ Grafana is running"
    else
        echo "❌ Grafana is not accessible"
    fi
    
    # Check SonarQube
    if curl -s -f http://localhost:9000/api/system/status > /dev/null 2>&1; then
        echo "✅ SonarQube is running"
    else
        echo "❌ SonarQube is not accessible"
    fi
    
    # Check Jaeger
    if curl -s -f http://localhost:16686/api/services > /dev/null 2>&1; then
        echo "✅ Jaeger is running"
    else
        echo "❌ Jaeger is not accessible"
    fi
    echo
}

# Check CI/CD tools
check_cicd() {
    echo "=== CI/CD Tools Status ==="
    
    # Check Jenkins
    if curl -s -f http://localhost:8080/api/json > /dev/null 2>&1; then
        echo "✅ Jenkins is running"
    else
        echo "❌ Jenkins is not accessible"
    fi
    
    # Check ArgoCD
    if command_exists kubectl; then
        ARGOCD_PODS=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep -c "Running" || echo "0")
        if [ "$ARGOCD_PODS" -gt 0 ]; then
            echo "✅ ArgoCD is running ($ARGOCD_PODS pods)"
        else
            echo "❌ ArgoCD is not running"
        fi
    fi
    echo
}

# Check database services
check_database() {
    echo "=== Database Services Status ==="
    
    # Check PostgreSQL
    if command_exists psql; then
        if PGPASSWORD=password psql -h localhost -U postgres -d zomato -c "SELECT 1;" >/dev/null 2>&1; then
            echo "✅ PostgreSQL is accessible"
        else
            echo "❌ PostgreSQL is not accessible"
        fi
    else
        echo "⚠️  psql not installed, cannot check PostgreSQL directly"
    fi
    
    # Check Redis
    if command_exists redis-cli; then
        if redis-cli -h localhost ping >/dev/null 2>&1; then
            echo "✅ Redis is accessible"
        else
            echo "❌ Redis is not accessible"
        fi
    else
        echo "⚠️  redis-cli not installed, cannot check Redis directly"
    fi
    echo
}

# Check infrastructure tools
check_infrastructure() {
    echo "=== Infrastructure Tools Status ==="
    
    # Check Terraform
    if command_exists terraform; then
        echo "✅ Terraform is installed"
        if [ -d terraform ]; then
            echo "✅ Terraform directory found"
        else
            echo "❌ Terraform directory not found"
        fi
    else
        echo "❌ Terraform is not installed"
    fi
    
    # Check Helm
    if command_exists helm; then
        echo "✅ Helm is installed"
    else
        echo "❌ Helm is not installed"
    fi
    
    # Check AWS CLI
    if command_exists aws; then
        if aws sts get-caller-identity >/dev/null 2>&1; then
            echo "✅ AWS CLI is configured"
        else
            echo "⚠️  AWS CLI is installed but not configured"
        fi
    else
        echo "❌ AWS CLI is not installed"
    fi
    
    # Check Azure CLI
    if command_exists az; then
        if az account show >/dev/null 2>&1; then
            echo "✅ Azure CLI is configured"
        else
            echo "⚠️  Azure CLI is installed but not configured"
        fi
    else
        echo "❌ Azure CLI is not installed"
    fi
    
    # Check Google Cloud CLI
    if command_exists gcloud; then
        if gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
            echo "✅ Google Cloud CLI is configured"
        else
            echo "⚠️  Google Cloud CLI is installed but not configured"
        fi
    else
        echo "❌ Google Cloud CLI is not installed"
    fi
    echo
}

# Check project files
check_project_files() {
    echo "=== Project Files Status ==="
    
    # Check essential files
    ESSENTIAL_FILES=("package.json" "Dockerfile" "docker-compose.yml" "src/app.js" "src/public/index.html")
    for file in "${ESSENTIAL_FILES[@]}"; do
        if [ -f "$file" ]; then
            echo "✅ $file exists"
        else
            echo "❌ $file missing"
        fi
    done
    
    # Check directories
    ESSENTIAL_DIRS=("src" "k8s" "monitoring" "security" "testing" "terraform" "jenkins")
    for dir in "${ESSENTIAL_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            echo "✅ $dir/ directory exists"
        else
            echo "❌ $dir/ directory missing"
        fi
    done
    
    # Check if node_modules exists
    if [ -d "node_modules" ]; then
        echo "✅ Dependencies installed"
    else
        echo "❌ Dependencies not installed (run 'npm install')"
    fi
    echo
}

# Check system resources
check_system_resources() {
    echo "=== System Resources Status ==="
    
    # Check disk space
    DISK_USAGE=$(df -h . | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$DISK_USAGE" -lt 80 ]; then
        echo "✅ Disk usage: ${DISK_USAGE}%"
    else
        echo "⚠️  Disk usage: ${DISK_USAGE}% (consider cleanup)"
    fi
    
    # Check memory
    if command_exists free; then
        MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
        echo "ℹ️  Memory usage: ${MEMORY_USAGE}%"
    fi
    
    # Check CPU load
    if command_exists uptime; then
        LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
        echo "ℹ️  Load average: $LOAD_AVG"
    fi
    echo
}

# Main function
main() {
    echo "🚀 Zomato Clone Advanced DevOps Project - Status Check"
    echo "=================================================="
    echo
    
    check_project_files
    check_node_app
    check_docker_services
    check_database
    check_kubernetes
    check_monitoring
    check_cicd
    check_infrastructure
    check_system_resources
    
    echo "=================================================="
    log "Status check completed!"
    
    # Summary
    echo
    echo "📋 Quick Actions:"
    echo "  • Start project: ./start.sh"
    echo "  • View help: make help"
    echo "  • Check logs: make logs"
    echo "  • Run tests: make test"
    echo "  • Deploy: make deploy"
}

# Run main function
main "$@"
