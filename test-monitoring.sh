#!/bin/bash

set -e

echo "🧪 Testing Monitoring Setup..."

# Check if monitoring namespace exists
if ! kubectl get namespace monitoring >/dev/null 2>&1; then
    echo "❌ Monitoring namespace not found. Please deploy monitoring stack first."
    exit 1
fi

# Check if Prometheus is running
echo "🔍 Checking Prometheus status..."
if kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus | grep -q Running; then
    echo "✅ Prometheus is running"
else
    echo "❌ Prometheus is not running"
    exit 1
fi

# Check if Grafana is running
echo "📊 Checking Grafana status..."
if kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana | grep -q Running; then
    echo "✅ Grafana is running"
else
    echo "❌ Grafana is not running"
    exit 1
fi

# Get service URLs
echo "🌐 Getting service URLs..."
PROMETHEUS_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "localhost")
GRAFANA_URL=$(kubectl get svc -n monitoring grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "localhost")

echo "📊 Access URLs:"
echo "   Prometheus: http://$PROMETHEUS_URL:9090"
echo "   Grafana: http://$GRAFANA_URL:3000"
echo "   Grafana Admin Password: admin123"

# Test Prometheus metrics
echo "📈 Testing Prometheus metrics..."
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 &
PROMETHEUS_PID=$!
sleep 5

# Test basic metrics
if curl -s http://localhost:9090/api/v1/query?query=up | grep -q "result"; then
    echo "✅ Prometheus metrics are accessible"
else
    echo "❌ Prometheus metrics are not accessible"
fi

kill $PROMETHEUS_PID 2>/dev/null || true

# Create a test pod to generate load
echo "🚀 Creating test pod to generate load..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: stress-test
  namespace: default
spec:
  containers:
  - name: stress
    image: busybox
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo 'Generating load...'; sleep 1; done"]
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
EOF

# Wait for pod to be ready
kubectl wait --for=condition=ready pod stress-test --timeout=60s

echo "✅ Test pod created successfully"
echo ""
echo "🧪 To test alerts, you can:"
echo "   1. Access Grafana at http://$GRAFANA_URL:3000"
echo "   2. Go to Alerting section"
echo "   3. Check alert rules and contact points"
echo "   4. Create additional load with: kubectl exec stress-test -- sh -c 'while true; do echo stress; done'"
echo ""
echo "🔍 To check current metrics:"
echo "   kubectl get all -n monitoring"
echo "   kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus"
echo "   kubectl logs -n monitoring -l app.kubernetes.io/name=grafana" 