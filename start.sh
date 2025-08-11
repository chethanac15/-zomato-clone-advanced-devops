#!/bin/bash

# Start script for Zomato Clone Advanced DevOps Project

set -e

echo "🚀 Starting Zomato Clone Advanced DevOps Project..."

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js 18 or higher."
    exit 1
fi

# Check Node.js version
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "❌ Node.js version 18 or higher is required. Current version: $(node -v)"
    exit 1
fi

echo "✅ Node.js version: $(node -v)"

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed. Please install npm."
    exit 1
fi

echo "✅ npm version: $(npm -v)"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "⚠️  Docker is not installed. Some features may not work."
else
    echo "✅ Docker version: $(docker --version)"
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "⚠️  Docker Compose is not installed. Some features may not work."
else
    echo "✅ Docker Compose version: $(docker-compose --version)"
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "⚠️  kubectl is not installed. Kubernetes features may not work."
else
    echo "✅ kubectl version: $(kubectl version --client --short)"
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "⚠️  Terraform is not installed. Infrastructure features may not work."
else
    echo "✅ Terraform version: $(terraform version | head -n1)"
fi

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
else
    echo "✅ Dependencies already installed"
fi

# Create necessary directories
echo "📁 Creating necessary directories..."
mkdir -p logs
mkdir -p dist
mkdir -p coverage
mkdir -p reports
mkdir -p results

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "⚠️  .env file not found. Creating from example..."
    if [ -f "env.example" ]; then
        cp env.example .env
        echo "✅ .env file created from env.example"
        echo "⚠️  Please update .env file with your actual configuration values"
    else
        echo "❌ env.example file not found. Please create a .env file manually."
    fi
fi

# Build the application
echo "🔨 Building application..."
npm run build

# Run tests
echo "🧪 Running tests..."
npm test

# Start the application
echo "🚀 Starting application..."
npm start
