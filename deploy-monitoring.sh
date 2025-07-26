#!/bin/bash

set -e

echo "🚀 Deploying Monitoring Stack (Prometheus + Grafana)..."

# Add Helm repositories
echo "📦 Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Create monitoring namespace
echo "📁 Creating monitoring namespace..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Deploy Prometheus
echo "🔍 Deploying Prometheus..."
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values helm/prometheus-chart/values.yaml \
  --wait \
  --timeout=10m

# Deploy Grafana (if not already deployed with Prometheus)
echo "📊 Deploying Grafana..."
helm upgrade --install grafana grafana/grafana \
  --namespace monitoring \
  --create-namespace \
  --values helm/grafana-chart/values.yaml \
  --wait \
  --timeout=10m

# Wait for all pods to be ready
echo "⏳ Waiting for all pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s

# Get service URLs
echo "🌐 Getting service URLs..."
PROMETHEUS_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
GRAFANA_URL=$(kubectl get svc -n monitoring grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "✅ Monitoring stack deployed successfully!"
echo ""
echo "📊 Access URLs:"
echo "   Prometheus: http://$PROMETHEUS_URL:9090"
echo "   Grafana: http://$GRAFANA_URL:3000"
echo "   Grafana Admin Password: admin123"
echo ""
echo "🔍 Check deployment status:"
echo "   kubectl get all -n monitoring" 