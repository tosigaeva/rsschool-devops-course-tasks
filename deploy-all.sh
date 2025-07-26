#!/bin/bash
set -e

echo "🚀 Starting complete deployment process..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check prerequisites
print_step "Checking prerequisites..."
if ! command -v terraform &> /dev/null; then
    print_error "terraform is not installed. Please install terraform first."
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

if ! command -v helm &> /dev/null; then
    print_error "helm is not installed. Please install helm first."
    exit 1
fi

print_status "Prerequisites check passed"

# Step 1: Deploy infrastructure
print_step "Step 1: Deploying AWS infrastructure..."
terraform init
terraform plan
terraform apply -auto-approve

print_status "Infrastructure deployed successfully!"

# Step 2: Wait for instances to be ready
print_step "Step 2: Waiting for instances to be ready..."
sleep 60

# Step 3: Get control node IP
print_step "Step 3: Getting control node IP..."
CONTROL_NODE_IP=$(terraform output -raw control_node_public_ip)
print_status "Control node IP: $CONTROL_NODE_IP"

# Step 4: Copy kubeconfig
print_step "Step 4: Copying kubeconfig..."
# Save private key from Terraform output
terraform output -raw private_key_pem > private_key.pem
chmod 600 private_key.pem

scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i private_key.pem ubuntu@$CONTROL_NODE_IP:/home/ubuntu/.kube/config ./kubeconfig

# Update kubeconfig to use localhost (we'll use SSH tunnel)
sed -i '' "s/127.0.0.1/localhost/g" kubeconfig
export KUBECONFIG=./kubeconfig

# Step 5: Start SSH tunnel and wait for cluster to be ready
print_step "Step 5: Starting SSH tunnel and waiting for cluster..."
ssh -i private_key.pem -o StrictHostKeyChecking=no -L 6443:localhost:6443 ubuntu@$CONTROL_NODE_IP -N &
SSH_TUNNEL_PID=$!

# Wait for tunnel to be established
sleep 5

kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Check cluster status
print_status "Cluster status:"
kubectl get nodes
kubectl get pods --all-namespaces

# Step 6: Install Jenkins
print_step "Step 6: Installing Jenkins..."
helm install jenkins ./helm/jenkins-chart \
  --namespace jenkins \
  --create-namespace \
  --set jenkins.adminUsername=admin \
  --set jenkins.adminPassword=admin123

# Wait for Jenkins to be ready
print_status "Waiting for Jenkins to be ready..."
kubectl wait --for=condition=Ready pod -l app=jenkins-server -n jenkins --timeout=300s

# Step 7: Get Jenkins information
print_step "Step 7: Getting Jenkins information..."
JENKINS_URL=$(kubectl get service jenkins -n jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
print_status "Jenkins URL: http://$JENKINS_URL:8080"
print_status "Jenkins admin username: admin"
print_status "Jenkins admin password: admin123"

# Step 8: Deploy Flask app
print_step "Step 8: Deploying Flask app..."
helm install flask-app ./helm/flask-app-chart \
  --namespace default \
  --set image.repository=my-flask-app \
  --set image.tag=latest

# Wait for Flask app to be ready
print_status "Waiting for Flask app to be ready..."
kubectl wait --for=condition=Ready pod -l app=flask-app --timeout=300s

# Step 9: Get Flask app information
print_step "Step 9: Getting Flask app information..."
FLASK_URL=$(kubectl get service flask-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
print_status "Flask app URL: http://$FLASK_URL:8080"

# Final summary
echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📋 Summary:"
echo "  - Jenkins: http://$JENKINS_URL:8080"
echo "  - Jenkins admin: admin / admin123"
echo "  - Flask app: http://$FLASK_URL:8080"
echo ""
echo "🔧 Next steps:"
echo "  1. Access Jenkins at http://$JENKINS_URL:8080"
echo "  2. Login with admin/admin123"
echo "  3. Create a new pipeline job"
echo "  4. Use the Jenkinsfile from your repository"
echo "  5. Configure AWS credentials in Jenkins"
echo "  6. Run the pipeline to build and deploy your Flask app"
echo ""
echo "📸 Take screenshots of:"
echo "  - Jenkins dashboard"
echo "  - Flask app running in browser"
echo "  - Pipeline execution"
echo ""
echo "⚠️  Important: Keep the SSH tunnel running for kubectl access:"
echo "   SSH tunnel PID: $SSH_TUNNEL_PID"
echo "   To stop tunnel later: kill $SSH_TUNNEL_PID" 