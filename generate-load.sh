#!/bin/bash

set -e

echo "🚀 Generating Load for Monitoring Tests..."

# Create a namespace for load testing
echo "📁 Creating load-test namespace..."
kubectl create namespace load-test --dry-run=client -o yaml | kubectl apply -f -

# Create CPU stress pod
echo "🔥 Creating CPU stress pod..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: cpu-stress
  namespace: load-test
spec:
  containers:
  - name: stress
    image: busybox
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo 'CPU stress test'; done"]
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
EOF

# Create memory stress pod
echo "💾 Creating memory stress pod..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: memory-stress
  namespace: load-test
spec:
  containers:
  - name: stress
    image: busybox
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo 'Memory stress test'; done"]
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "200m"
EOF

# Create a pod that will restart frequently
echo "🔄 Creating restarting pod..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: restarting-pod
  namespace: load-test
spec:
  containers:
  - name: restart
    image: busybox
    command: ["/bin/sh"]
    args: ["-c", "echo 'Restarting pod'; sleep 10; exit 1"]
    resources:
      requests:
        memory: "32Mi"
        cpu: "50m"
      limits:
        memory: "64Mi"
        cpu: "100m"
  restartPolicy: Always
EOF

# Wait for pods to be ready
echo "⏳ Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod cpu-stress -n load-test --timeout=60s
kubectl wait --for=condition=ready pod memory-stress -n load-test --timeout=60s

echo "✅ Load generation pods created successfully!"
echo ""
echo "🧪 Load testing pods:"
echo "   - cpu-stress: Generates CPU load"
echo "   - memory-stress: Generates memory load"
echo "   - restarting-pod: Pod that restarts frequently"
echo ""
echo "📊 Monitor the load:"
echo "   1. Check Prometheus targets: kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
echo "   2. Access Grafana: kubectl port-forward -n monitoring svc/grafana 3000:3000"
echo "   3. Check alert rules in Grafana Alerting section"
echo ""
echo "🔍 Check pod status:"
echo "   kubectl get pods -n load-test"
echo ""
echo "🧹 Cleanup when done:"
echo "   kubectl delete namespace load-test" 