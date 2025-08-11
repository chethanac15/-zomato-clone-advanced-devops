#!/bin/bash

# Zomato Clone - Advanced DevOps Project Deployment Script
# This script automates the complete deployment process including:
# - Infrastructure provisioning with Terraform
# - Kubernetes cluster setup
# - OpenKruise installation
# - Application deployment
# - Monitoring and security setup
# - Chaos engineering deployment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="zomato-clone-advanced"
ENVIRONMENT=${1:-staging}
CLOUD_PROVIDER=${2:-aws}
REGION=${3:-us-west-2}
CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}"

# Logging function
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

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check required tools
    local tools=("kubectl" "helm" "terraform" "docker" "aws" "git")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "$tool is not installed. Please install it first."
        fi
    done
    
    # Check Docker daemon
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running. Please start Docker first."
    fi
    
    # Check Kubernetes context
    if ! kubectl cluster-info &> /dev/null; then
        warn "No Kubernetes cluster context found. Will create one."
    fi
    
    log "Prerequisites check completed successfully."
}

# Build and push Docker images
build_images() {
    log "Building and pushing Docker images..."
    
    # Set Docker registry
    local registry="your-registry.com"
    local tag=$(git rev-parse --short HEAD)
    
    # Build application image
    log "Building Zomato application image..."
    docker build -t "${registry}/${PROJECT_NAME}:${tag}" .
    docker build -t "${registry}/${PROJECT_NAME}:latest" .
    
    # Build additional service images
    log "Building monitoring images..."
    docker build -f monitoring/prometheus/Dockerfile -t "${registry}/zomato-prometheus:${tag}" monitoring/prometheus/
    docker build -f monitoring/grafana/Dockerfile -t "${registry}/zomato-grafana:${tag}" monitoring/grafana/
    
    # Push images
    log "Pushing images to registry..."
    docker push "${registry}/${PROJECT_NAME}:${tag}"
    docker push "${registry}/${PROJECT_NAME}:latest"
    docker push "${registry}/zomato-prometheus:${tag}"
    docker push "${registry}/zomato-grafana:${tag}"
    
    log "Docker images built and pushed successfully."
}

# Provision infrastructure with Terraform
provision_infrastructure() {
    log "Provisioning infrastructure with Terraform..."
    
    cd terraform
    
    # Initialize Terraform
    log "Initializing Terraform..."
    terraform init
    
    # Plan deployment
    log "Planning Terraform deployment..."
    terraform plan \
        -var="environment=${ENVIRONMENT}" \
        -var="cloud_provider=${CLOUD_PROVIDER}" \
        -var="region=${REGION}" \
        -var="cluster_name=${CLUSTER_NAME}" \
        -out=tfplan
    
    # Apply deployment
    log "Applying Terraform configuration..."
    terraform apply tfplan
    
    # Get outputs
    log "Getting Terraform outputs..."
    export KUBECONFIG=$(terraform output -raw kubeconfig_path)
    export CLUSTER_ENDPOINT=$(terraform output -raw cluster_endpoint)
    
    cd ..
    
    log "Infrastructure provisioned successfully."
}

# Setup Kubernetes cluster
setup_kubernetes() {
    log "Setting up Kubernetes cluster..."
    
    # Wait for cluster to be ready
    log "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    # Create namespaces
    log "Creating namespaces..."
    kubectl apply -f k8s/namespace.yaml
    
    # Setup storage classes
    log "Setting up storage classes..."
    kubectl apply -f k8s/storage/
    
    # Setup RBAC
    log "Setting up RBAC..."
    kubectl apply -f k8s/rbac/
    
    log "Kubernetes cluster setup completed."
}

# Install OpenKruise
install_openkruise() {
    log "Installing OpenKruise..."
    
    # Install OpenKruise using Helm
    helm repo add openkruise https://openkruise.github.io/charts/
    helm repo update
    
    helm install openkruise openkruise/kruise \
        --namespace openkruise-system \
        --create-namespace \
        --set featureGates="AdvancedStatefulSet=true,SidecarSet=true,WorkloadSpread=true,PodUnavailableBudget=true" \
        --wait
    
    # Verify installation
    kubectl wait --for=condition=Ready pods -n openkruise-system --all --timeout=300s
    
    log "OpenKruise installed successfully."
}

# Install Istio
install_istio() {
    log "Installing Istio..."
    
    # Install Istio using Helm
    helm repo add istio https://istio-release.storage.googleapis.com/charts
    helm repo update
    
    # Install Istio base
    helm install istio-base istio/base \
        --namespace istio-system \
        --create-namespace \
        --wait
    
    # Install Istio discovery
    helm install istiod istio/istiod \
        --namespace istio-system \
        --wait
    
    # Install Istio ingress gateway
    helm install istio-ingress istio/gateway \
        --namespace istio-system \
        --wait
    
    # Enable automatic sidecar injection
    kubectl label namespace zomato-project istio-injection=enabled
    
    log "Istio installed successfully."
}

# Deploy monitoring stack
deploy_monitoring() {
    log "Deploying monitoring stack..."
    
    # Install Prometheus Operator
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
        --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
        --wait
    
    # Deploy custom Prometheus configuration
    kubectl apply -f monitoring/prometheus/
    
    # Deploy Grafana dashboards
    kubectl apply -f monitoring/grafana/
    
    # Install Jaeger for distributed tracing
    helm install jaeger jaegertracing/jaeger \
        --namespace monitoring \
        --set storage.type=memory \
        --wait
    
    # Install Elasticsearch and Kibana
    helm install elasticsearch elastic/elasticsearch \
        --namespace monitoring \
        --set replicas=1 \
        --set minimumMasterNodes=1 \
        --wait
    
    helm install kibana elastic/kibana \
        --namespace monitoring \
        --wait
    
    # Install Fluentd for log aggregation
    kubectl apply -f monitoring/fluentd/
    
    log "Monitoring stack deployed successfully."
}

# Deploy security tools
deploy_security() {
    log "Deploying security tools..."
    
    # Install OPA Gatekeeper
    helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
    helm repo update
    
    helm install gatekeeper gatekeeper/gatekeeper \
        --namespace security \
        --create-namespace \
        --wait
    
    # Apply security policies
    kubectl apply -f security/opa-gatekeeper-policies.yaml
    
    # Install Falco for runtime security
    helm repo add falcosecurity https://falcosecurity.github.io/charts
    helm repo update
    
    helm install falco falcosecurity/falco \
        --namespace security \
        --set falco.jsonOutput=true \
        --set falco.httpOutput.enabled=true \
        --wait
    
    # Install Trivy for vulnerability scanning
    kubectl apply -f security/trivy/
    
    # Setup network policies
    kubectl apply -f security/network-policies/
    
    log "Security tools deployed successfully."
}

# Deploy application
deploy_application() {
    log "Deploying Zomato application..."
    
    # Deploy database and cache
    kubectl apply -f k8s/applications/
    
    # Wait for database to be ready
    log "Waiting for database to be ready..."
    kubectl wait --for=condition=Ready pods -l app=postgres -n zomato-project --timeout=300s
    kubectl wait --for=condition=Ready pods -l app=redis -n zomato-project --timeout=300s
    
    # Deploy application
    kubectl apply -f k8s/applications/zomato-advanced-deployment.yaml
    
    # Wait for application to be ready
    log "Waiting for application to be ready..."
    kubectl wait --for=condition=Ready pods -l app=zomato-app -n zomato-project --timeout=300s
    
    # Deploy services
    kubectl apply -f k8s/services/
    
    # Deploy ingress
    kubectl apply -f k8s/ingress/
    
    log "Application deployed successfully."
}

# Setup ArgoCD
setup_argocd() {
    log "Setting up ArgoCD..."
    
    # Install ArgoCD
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    kubectl wait --for=condition=Ready pods -n argocd --all --timeout=300s
    
    # Get ArgoCD admin password
    local argocd_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    log "ArgoCD admin password: ${argocd_password}"
    
    # Create ArgoCD application
    kubectl apply -f k8s/argocd/
    
    log "ArgoCD setup completed."
}

# Deploy chaos engineering
deploy_chaos_engineering() {
    log "Deploying chaos engineering tools..."
    
    # Install Chaos Mesh
    helm repo add chaos-mesh https://charts.chaos-mesh.org
    helm repo update
    
    helm install chaos-mesh chaos-mesh/chaos-mesh \
        --namespace chaos-testing \
        --create-namespace \
        --set chaosDaemon.runtime=containerd \
        --set chaosDaemon.socketPath=/run/containerd/containerd.sock \
        --wait
    
    # Deploy chaos experiments
    kubectl apply -f testing/chaos/
    
    log "Chaos engineering tools deployed successfully."
}

# Run tests
run_tests() {
    log "Running tests..."
    
    # Run unit tests
    log "Running unit tests..."
    npm test
    
    # Run integration tests
    log "Running integration tests..."
    npm run test:integration
    
    # Run performance tests
    log "Running performance tests..."
    npm run test:performance
    
    # Run security tests
    log "Running security tests..."
    npm run security:audit
    
    log "All tests completed successfully."
}

# Setup CI/CD
setup_cicd() {
    log "Setting up CI/CD..."
    
    # Install Jenkins
    helm repo add jenkins https://charts.jenkins.io
    helm repo update
    
    helm install jenkins jenkins/jenkins \
        --namespace jenkins \
        --create-namespace \
        --set controller.serviceType=LoadBalancer \
        --set controller.resources.requests.memory=512Mi \
        --set controller.resources.requests.cpu=250m \
        --set controller.resources.limits.memory=2Gi \
        --set controller.resources.limits.cpu=1000m \
        --wait
    
    # Wait for Jenkins to be ready
    kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=jenkins -n jenkins --timeout=300s
    
    # Get Jenkins admin password
    local jenkins_password=$(kubectl exec --namespace jenkins -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password)
    log "Jenkins admin password: ${jenkins_password}"
    
    # Setup Jenkins pipeline
    kubectl apply -f jenkins/
    
    log "CI/CD setup completed."
}

# Verify deployment
verify_deployment() {
    log "Verifying deployment..."
    
    # Check all pods are running
    local failed_pods=$(kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded | grep -v "Completed\|Evicted")
    if [[ -n "$failed_pods" ]]; then
        warn "Some pods are not running:"
        echo "$failed_pods"
    else
        log "All pods are running successfully."
    fi
    
    # Check services
    kubectl get services --all-namespaces
    
    # Check ingress
    kubectl get ingress --all-namespaces
    
    # Test application endpoints
    log "Testing application endpoints..."
    
    # Get application URL
    local app_url=$(kubectl get ingress -n zomato-project -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')
    
    if [[ -n "$app_url" ]]; then
        log "Application URL: http://${app_url}"
        
        # Test health endpoint
        if curl -f "http://${app_url}/health" &> /dev/null; then
            log "Health check passed."
        else
            warn "Health check failed."
        fi
        
        # Test metrics endpoint
        if curl -f "http://${app_url}/metrics" &> /dev/null; then
            log "Metrics endpoint accessible."
        else
            warn "Metrics endpoint not accessible."
        fi
    fi
    
    log "Deployment verification completed."
}

# Display deployment information
display_info() {
    log "Deployment completed successfully!"
    echo
    echo "=== Deployment Information ==="
    echo "Project: ${PROJECT_NAME}"
    echo "Environment: ${ENVIRONMENT}"
    echo "Cloud Provider: ${CLOUD_PROVIDER}"
    echo "Region: ${REGION}"
    echo "Cluster: ${CLUSTER_NAME}"
    echo
    echo "=== Access Information ==="
    echo "Kubernetes Dashboard: kubectl proxy"
    echo "ArgoCD: kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "Grafana: kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80"
    echo "Prometheus: kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090"
    echo "Jaeger: kubectl port-forward svc/jaeger -n monitoring 16686:16686"
    echo "Kibana: kubectl port-forward svc/kibana-kibana -n monitoring 5601:5601"
    echo
    echo "=== Next Steps ==="
    echo "1. Access the application at the provided URL"
    echo "2. Monitor the application using Grafana dashboards"
    echo "3. Check security policies in OPA Gatekeeper"
    echo "4. Run chaos experiments to test resilience"
    echo "5. Set up alerts and notifications"
    echo
}

# Main deployment function
main() {
    log "Starting deployment of ${PROJECT_NAME} to ${ENVIRONMENT} environment..."
    
    # Check prerequisites
    check_prerequisites
    
    # Build and push images
    build_images
    
    # Provision infrastructure
    provision_infrastructure
    
    # Setup Kubernetes
    setup_kubernetes
    
    # Install OpenKruise
    install_openkruise
    
    # Install Istio
    install_istio
    
    # Deploy monitoring
    deploy_monitoring
    
    # Deploy security
    deploy_security
    
    # Deploy application
    deploy_application
    
    # Setup ArgoCD
    setup_argocd
    
    # Deploy chaos engineering
    deploy_chaos_engineering
    
    # Setup CI/CD
    setup_cicd
    
    # Run tests
    run_tests
    
    # Verify deployment
    verify_deployment
    
    # Display information
    display_info
    
    log "Deployment completed successfully!"
}

# Handle script arguments
case "${1:-}" in
    "staging"|"production"|"development")
        main
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [environment] [cloud_provider] [region]"
        echo "  environment: staging, production, or development (default: staging)"
        echo "  cloud_provider: aws, gcp, or azure (default: aws)"
        echo "  region: cloud region (default: us-west-2)"
        echo
        echo "Examples:"
        echo "  $0                    # Deploy to staging on AWS us-west-2"
        echo "  $0 production         # Deploy to production on AWS us-west-2"
        echo "  $0 staging gcp        # Deploy to staging on GCP us-west-2"
        echo "  $0 production azure   # Deploy to production on Azure us-west-2"
        ;;
    *)
        error "Invalid environment. Use 'staging', 'production', or 'development'"
        ;;
esac
