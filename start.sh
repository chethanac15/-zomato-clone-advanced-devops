#!/bin/bash

# Zomato Clone Advanced DevOps Project - Startup Script
# This script helps you start the project components

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Check if Docker is running
check_docker() {
    if ! docker info &> /dev/null; then
        error "Docker is not running. Please start Docker first."
    fi
    log "Docker is running"
}

# Check if Node.js is installed
check_node() {
    if ! command -v node &> /dev/null; then
        error "Node.js is not installed. Please install Node.js 18+ first."
    fi
    log "Node.js $(node --version) is installed"
}

# Check if npm is installed
check_npm() {
    if ! command -v npm &> /dev/null; then
        error "npm is not installed. Please install npm first."
    fi
    log "npm $(npm --version) is installed"
}

# Install dependencies
install_deps() {
    log "Installing Node.js dependencies..."
    npm install
    log "Dependencies installed successfully"
}

# Start with Docker Compose
start_docker() {
    log "Starting services with Docker Compose..."
    docker-compose up -d postgres redis
    log "Waiting for database services to be ready..."
    sleep 10
    log "Database services started"
}

# Start the application
start_app() {
    log "Starting Zomato application..."
    npm run dev &
    APP_PID=$!
    log "Application started with PID: $APP_PID"
    echo $APP_PID > .app.pid
}

# Start monitoring services
start_monitoring() {
    log "Starting monitoring services..."
    docker-compose up -d prometheus grafana sonarqube
    log "Monitoring services started"
}

# Start CI/CD services
start_cicd() {
    log "Starting CI/CD services..."
    docker-compose up -d jenkins
    log "CI/CD services started"
}

# Display status
show_status() {
    log "Project status:"
    echo
    echo "=== Running Services ==="
    docker-compose ps
    echo
    echo "=== Application Status ==="
    if [ -f .app.pid ]; then
        APP_PID=$(cat .app.pid)
        if ps -p $APP_PID > /dev/null; then
            echo "✅ Application is running (PID: $APP_PID)"
        else
            echo "❌ Application is not running"
        fi
    else
        echo "❌ Application PID file not found"
    fi
    echo
    echo "=== Access URLs ==="
    echo "Application: http://localhost:3000"
    echo "Health Check: http://localhost:3000/health"
    echo "API Docs: http://localhost:3000/api-docs"
    echo "Metrics: http://localhost:3000/metrics"
    echo "Grafana: http://localhost:3001 (admin/admin)"
    echo "Prometheus: http://localhost:9090"
    echo "SonarQube: http://localhost:9000"
    echo "Jenkins: http://localhost:8080"
    echo
    echo "=== Database ==="
    echo "PostgreSQL: localhost:5432"
    echo "Redis: localhost:6379"
}

# Stop all services
stop_all() {
    log "Stopping all services..."
    
    # Stop application
    if [ -f .app.pid ]; then
        APP_PID=$(cat .app.pid)
        if ps -p $APP_PID > /dev/null; then
            kill $APP_PID
            log "Application stopped"
        fi
        rm -f .app.pid
    fi
    
    # Stop Docker services
    docker-compose down
    log "All services stopped"
}

# Clean up
cleanup() {
    log "Cleaning up..."
    rm -f .app.pid
    log "Cleanup completed"
}

# Main function
main() {
    case "${1:-start}" in
        "start")
            log "Starting Zomato Clone Advanced DevOps Project..."
            check_docker
            check_node
            check_npm
            install_deps
            start_docker
            start_app
            start_monitoring
            start_cicd
            sleep 5
            show_status
            log "Project started successfully!"
            ;;
        "stop")
            stop_all
            ;;
        "restart")
            stop_all
            sleep 2
            main start
            ;;
        "status")
            show_status
            ;;
        "cleanup")
            cleanup
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [command]"
            echo
            echo "Commands:"
            echo "  start     Start all project services (default)"
            echo "  stop      Stop all project services"
            echo "  restart   Restart all project services"
            echo "  status    Show current project status"
            echo "  cleanup   Clean up temporary files"
            echo "  help      Show this help message"
            ;;
        *)
            error "Unknown command: $1. Use 'help' for available commands."
            ;;
    esac
}

# Error handling
error() {
    echo -e "\033[0;31m[ERROR] $1${NC}" >&2
    exit 1
}

# Trap cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"
