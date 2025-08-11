# Makefile for Zomato Clone Advanced DevOps Project

.PHONY: help install test test-watch test-coverage lint lint-fix build run run-prod docker-build docker-run docker-stop docker-clean k8s-deploy k8s-delete k8s-logs terraform-init terraform-plan terraform-apply terraform-destroy monitoring-setup monitoring-delete security-audit security-scan jenkins-setup argocd-setup clean logs health metrics quick-start deploy dev-env prod-env

# Default target
help:
	@echo "Zomato Clone Advanced DevOps Project - Available Commands:"
	@echo ""
	@echo "Development:"
	@echo "  install        Install Node.js dependencies"
	@echo "  test          Run all tests"
	@echo "  test-watch    Run tests in watch mode"
	@echo "  test-coverage Run tests with coverage report"
	@echo "  lint          Run ESLint"
	@echo "  lint-fix      Fix ESLint issues"
	@echo "  build         Build the application"
	@echo "  run           Run the application in development mode"
	@echo "  run-prod      Run the application in production mode"
	@echo ""
	@echo "Docker:"
	@echo "  docker-build  Build Docker image"
	@echo "  docker-run    Run with Docker Compose"
	@echo "  docker-stop   Stop Docker Compose services"
	@echo "  docker-clean  Clean up Docker resources"
	@echo ""
	@echo "Kubernetes:"
	@echo "  k8s-deploy    Deploy to Kubernetes"
	@echo "  k8s-delete    Delete from Kubernetes"
	@echo "  k8s-logs      View application logs"
	@echo ""
	@echo "Infrastructure:"
	@echo "  terraform-init    Initialize Terraform"
	@echo "  terraform-plan    Plan Terraform changes"
	@echo "  terraform-apply   Apply Terraform changes"
	@echo "  terraform-destroy Destroy Terraform resources"
	@echo ""
	@echo "Monitoring:"
	@echo "  monitoring-setup   Setup monitoring stack"
	@echo "  monitoring-delete  Delete monitoring stack"
	@echo ""
	@echo "Security:"
	@echo "  security-audit     Run security audit"
	@echo "  security-scan      Run vulnerability scan"
	@echo ""
	@echo "CI/CD:"
	@echo "  jenkins-setup      Setup Jenkins"
	@echo "  argocd-setup       Setup ArgoCD"
	@echo ""
	@echo "Utilities:"
	@echo "  clean          Clean build artifacts"
	@echo "  logs           View application logs"
	@echo "  health         Check application health"
	@echo "  metrics        View application metrics"
	@echo ""
	@echo "Quick Actions:"
	@echo "  quick-start    Quick start with Docker"
	@echo "  dev-env        Setup development environment"
	@echo "  deploy         Full deployment"
	@echo "  prod-env       Production environment setup"

# Development commands
install:
	@echo "Installing dependencies..."
	npm install

test:
	@echo "Running tests..."
	npm test

test-watch:
	@echo "Running tests in watch mode..."
	npm run test:watch

test-coverage:
	@echo "Running tests with coverage..."
	npm run test:coverage

lint:
	@echo "Running ESLint..."
	npm run lint

lint-fix:
	@echo "Fixing ESLint issues..."
	npm run lint:fix

build:
	@echo "Building application..."
	npm run build:prod

run:
	@echo "Starting development server..."
	npm run dev

run-prod:
	@echo "Starting production server..."
	npm start

# Docker commands
docker-build:
	@echo "Building Docker image..."
	docker build -t zomato-clone:latest .

docker-run:
	@echo "Starting services with Docker Compose..."
	docker-compose up -d

docker-stop:
	@echo "Stopping Docker Compose services..."
	docker-compose down

docker-clean:
	@echo "Cleaning up Docker resources..."
	docker-compose down -v --remove-orphans
	docker system prune -f

# Kubernetes commands
k8s-deploy:
	@echo "Deploying to Kubernetes..."
	kubectl apply -f k8s/

k8s-delete:
	@echo "Deleting from Kubernetes..."
	kubectl delete -f k8s/

k8s-logs:
	@echo "Viewing application logs..."
	kubectl logs -f deployment/zomato-app -n zomato-project

# Terraform commands
terraform-init:
	@echo "Initializing Terraform..."
	cd terraform && terraform init

terraform-plan:
	@echo "Planning Terraform changes..."
	cd terraform && terraform plan

terraform-apply:
	@echo "Applying Terraform changes..."
	cd terraform && terraform apply -auto-approve

terraform-destroy:
	@echo "Destroying Terraform resources..."
	cd terraform && terraform destroy -auto-approve

# Monitoring commands
monitoring-setup:
	@echo "Setting up monitoring stack..."
	kubectl apply -f monitoring/

monitoring-delete:
	@echo "Deleting monitoring stack..."
	kubectl delete -f monitoring/

# Security commands
security-audit:
	@echo "Running security audit..."
	npm run security:audit

security-scan:
	@echo "Running vulnerability scan..."
	trivy image zomato-clone:latest

# CI/CD commands
jenkins-setup:
	@echo "Setting up Jenkins..."
	kubectl apply -f jenkins/

argocd-setup:
	@echo "Setting up ArgoCD..."
	kubectl apply -f k8s/argocd/

# Utility commands
clean:
	@echo "Cleaning build artifacts..."
	rm -rf node_modules coverage dist build logs
	rm -f .app.pid

logs:
	@echo "Viewing application logs..."
	tail -f logs/app.log

health:
	@echo "Checking application health..."
	curl -f http://localhost:3000/health || echo "Application is not running"

metrics:
	@echo "Viewing application metrics..."
	curl -f http://localhost:3000/metrics || echo "Metrics endpoint not accessible"

# Quick start
quick-start: install docker-run
	@echo "Quick start completed!"
	@echo "Application should be available at http://localhost:3000"

# Full deployment
deploy: install docker-build k8s-deploy monitoring-setup
	@echo "Full deployment completed!"

# Development environment
dev-env: install docker-run
	@echo "Development environment started!"
	@echo "Run 'make run' to start the application"

# Production environment
prod-env: install docker-build k8s-deploy monitoring-setup argocd-setup
	@echo "Production environment deployed!"
