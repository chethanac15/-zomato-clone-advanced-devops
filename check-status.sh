#!/bin/bash

# Check status script for Zomato Clone Advanced DevOps Project

set -e

echo "🔍 Checking project status..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    
    case $status in
        "OK")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "ERROR")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
    esac
}

# Check if Node.js is installed and running
echo "=== Node.js Status ==="
if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v)
    print_status "OK" "Node.js installed: $NODE_VERSION"
    
    # Check if it's the right version
    MAJOR_VERSION=$(echo $NODE_VERSION | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$MAJOR_VERSION" -ge 18 ]; then
        print_status "OK" "Node.js version is compatible (>=18)"
    else
        print_status "WARNING" "Node.js version may be too old (current: $NODE_VERSION, required: >=18)"
    fi
else
    print_status "ERROR" "Node.js is not installed"
fi

# Check if npm is installed
echo -e "\n=== npm Status ==="
if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm -v)
    print_status "OK" "npm installed: $NPM_VERSION"
else
    print_status "ERROR" "npm is not installed"
fi

# Check if dependencies are installed
echo -e "\n=== Dependencies Status ==="
if [ -d "node_modules" ]; then
    print_status "OK" "Dependencies are installed"
    
    # Check if package-lock.json exists
    if [ -f "package-lock.json" ]; then
        print_status "OK" "package-lock.json exists"
    else
        print_status "WARNING" "package-lock.json not found"
    fi
else
    print_status "WARNING" "Dependencies are not installed (run 'npm install')"
fi

# Check if .env file exists
echo -e "\n=== Environment Configuration ==="
if [ -f ".env" ]; then
    print_status "OK" ".env file exists"
else
    if [ -f "env.example" ]; then
        print_status "WARNING" ".env file not found, but env.example exists"
    else
        print_status "ERROR" "No environment configuration files found"
    fi
fi

# Check Docker status
echo -e "\n=== Docker Status ==="
if command -v docker &> /dev/null; then
    if docker info &> /dev/null; then
        print_status "OK" "Docker is running"
        DOCKER_VERSION=$(docker --version)
        print_status "INFO" "Docker version: $DOCKER_VERSION"
    else
        print_status "ERROR" "Docker is installed but not running"
    fi
else
    print_status "WARNING" "Docker is not installed"
fi

# Check Docker Compose status
if command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version)
    print_status "OK" "Docker Compose installed: $COMPOSE_VERSION"
else
    print_status "WARNING" "Docker Compose is not installed"
fi

# Check Kubernetes status
echo -e "\n=== Kubernetes Status ==="
if command -v kubectl &> /dev/null; then
    if kubectl cluster-info &> /dev/null 2>&1; then
        print_status "OK" "Kubernetes cluster is accessible"
        CLUSTER_INFO=$(kubectl cluster-info | head -n1)
        print_status "INFO" "Cluster: $CLUSTER_INFO"
    else
        print_status "WARNING" "kubectl is installed but cluster is not accessible"
    fi
else
    print_status "WARNING" "kubectl is not installed"
fi

# Check Terraform status
echo -e "\n=== Terraform Status ==="
if command -v terraform &> /dev/null; then
    TERRAFORM_VERSION=$(terraform version | head -n1)
    print_status "OK" "Terraform installed: $TERRAFORM_VERSION"
else
    print_status "WARNING" "Terraform is not installed"
fi

# Check application status
echo -e "\n=== Application Status ==="
if [ -f "src/app.js" ]; then
    print_status "OK" "Application source code exists"
else
    print_status "ERROR" "Application source code not found"
fi

# Check if application is running
if curl -s http://localhost:3000/health &> /dev/null; then
    print_status "OK" "Application is running and responding"
else
    print_status "WARNING" "Application is not responding on port 3000"
fi

# Check test files
echo -e "\n=== Testing Status ==="
if [ -f "src/test/app.test.js" ]; then
    print_status "OK" "Test files exist"
else
    print_status "WARNING" "Test files not found"
fi

# Check configuration files
echo -e "\n=== Configuration Files ==="
CONFIG_FILES=("jest.config.js" "jest.integration.config.js" ".eslintrc.js" ".prettierrc" "jsdoc.json" "Makefile")
for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_status "OK" "$file exists"
    else
        print_status "WARNING" "$file not found"
    fi
done

# Check if dist directory exists
echo -e "\n=== Build Status ==="
if [ -d "dist" ]; then
    print_status "OK" "Build directory exists"
else
    print_status "WARNING" "Build directory not found (run 'npm run build')"
fi

# Check if logs directory exists
if [ -d "logs" ]; then
    print_status "OK" "Logs directory exists"
else
    print_status "WARNING" "Logs directory not found"
fi

# Summary
echo -e "\n=== Summary ==="
print_status "INFO" "To start the project: ./start.sh"
print_status "INFO" "To run tests: npm test"
print_status "INFO" "To build: npm run build"
print_status "INFO" "To start development: npm run dev"
print_status "INFO" "To check health: curl http://localhost:3000/health"
print_status "INFO" "To view metrics: curl http://localhost:3000/metrics"
print_status "INFO" "To view API docs: http://localhost:3000/api-docs"

echo -e "\n🔍 Status check complete!"
