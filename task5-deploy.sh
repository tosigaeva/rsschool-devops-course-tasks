#!/bin/bash

# Task 5: Simple Application Deployment with Helm
# This script deploys the Flask application using Helm chart

set -e

echo "🚀 Task 5: Deploying Flask Application with Helm"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
print_status "Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

if ! command -v helm &> /dev/null; then
    print_error "helm is not installed. Please install helm first."
    exit 1
fi

print_status "Prerequisites check passed"

# Get the control node IP
print_status "Getting control node IP..."
CONTROL_NODE_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=K3S Control node" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text 2>/dev/null || echo "localhost")

print_status "Control Node IP: $CONTROL_NODE_IP"

# Copy kubeconfig from control node if it's a remote cluster
if [ "$CONTROL_NODE_IP" != "localhost" ]; then
    print_status "Copying kubeconfig from control node..."
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ec2-user@$CONTROL_NODE_IP \
        "sudo cat /etc/rancher/k3s/k3s.yaml" > kubeconfig.yaml
    
    # Update kubeconfig with correct server IP
    sed -i "s/127.0.0.1/$CONTROL_NODE_IP/g" kubeconfig.yaml
    export KUBECONFIG=./kubeconfig.yaml
else
    print_warning "Using local kubeconfig"
fi

# Check if cluster is accessible
print_status "Checking cluster connectivity..."
if ! kubectl get nodes &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

print_status "Cluster is accessible"

# Deploy Flask app using Helm
print_status "Deploying Flask application using Helm chart..."

# For local development, use a simple image
if [ "$CONTROL_NODE_IP" = "localhost" ]; then
    # Build and use local image
    print_status "Building local Docker image..."
    docker build -t flask-app:latest ./flask-app
    
    # Deploy with local image
    helm upgrade --install flask-app ./helm/flask-app-chart \
        --namespace default \
        --create-namespace \
        --set image.repository=flask-app \
        --set image.tag=latest \
        --set image.pullPolicy=Never \
        --set service.type=NodePort
else
    # Deploy with ECR image (for AWS deployment)
    helm upgrade --install flask-app ./helm/flask-app-chart \
        --namespace default \
        --create-namespace \
        --set service.type=LoadBalancer
fi

# Wait for deployment to be ready
print_status "Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/flask-app -n default

# Get service information
print_status "Getting service information..."
kubectl get svc flask-app -n default

# Get the service URL
if [ "$CONTROL_NODE_IP" = "localhost" ]; then
    NODE_PORT=$(kubectl get svc flask-app -n default -o jsonpath='{.spec.ports[0].nodePort}')
    SERVICE_URL="http://localhost:$NODE_PORT"
else
    # For AWS, get the LoadBalancer external IP
    SERVICE_URL=$(kubectl get svc flask-app -n default -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    if [ -z "$SERVICE_URL" ]; then
        SERVICE_URL=$(kubectl get svc flask-app -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    fi
    SERVICE_URL="http://$SERVICE_URL:8080"
fi

print_status "Flask application deployed successfully!"
echo ""
echo "📋 Application Information:"
echo "   Service URL: $SERVICE_URL"
echo "   Health Check: $SERVICE_URL/health"
echo "   Info Endpoint: $SERVICE_URL/info"
echo ""
echo "🔍 To check the deployment status:"
echo "   kubectl get pods -n default"
echo "   kubectl get svc -n default"
echo ""
echo "📸 Take a screenshot of the application running in your browser!"
echo "   Open: $SERVICE_URL"

# Test the application
print_status "Testing application endpoints..."
sleep 5

if curl -s "$SERVICE_URL" > /dev/null; then
    print_status "✅ Application is responding!"
    echo "   Main page: $(curl -s "$SERVICE_URL")"
else
    print_warning "⚠️  Application might still be starting up"
fi

if curl -s "$SERVICE_URL/health" > /dev/null; then
    print_status "✅ Health endpoint is working!"
    echo "   Health: $(curl -s "$SERVICE_URL/health")"
fi

echo ""
print_status "Task 5 deployment completed successfully! 🎉" 