# Monitoring Stack Deployment Guide

## Quick Start

### 1. Prerequisites

- Kubernetes cluster (EKS, GKE, or local)
- Helm 3.x installed
- kubectl configured
- Storage class available (gp2 for AWS)

### 2. Deploy Monitoring Stack

```bash
# Clone the repository
git clone <your-repo-url>
cd rsschool-devops-course-tasks

# Make scripts executable
chmod +x deploy-monitoring.sh test-monitoring.sh generate-load.sh

# Deploy the monitoring stack
./deploy-monitoring.sh
```

### 3. Verify Deployment

```bash
# Check all resources
kubectl get all -n monitoring

# Test the setup
./test-monitoring.sh
```

### 4. Access Monitoring Tools

```bash
# Port forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Port forward Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/admin123)

## Configuration

### SMTP Setup for Alerts

1. **Update SMTP Secret:**
   ```bash
   # Create base64 encoded values
   echo -n "your-email@gmail.com" | base64
   echo -n "your-app-password" | base64
   
   # Update the secret
   kubectl edit secret grafana-smtp-secret -n monitoring
   ```

2. **Configure Grafana SMTP:**
   - Access Grafana UI
   - Go to Configuration → Notification channels
   - Add email notification channel
   - Test the configuration

### Customize Alert Rules

Edit `helm/grafana-chart/templates/configmap-alerting.yaml` to modify alert rules:

```yaml
# Example: Change CPU threshold from 80% to 70%
condition: avg(rate(container_cpu_usage_seconds_total{container!=""}[5m])) by (pod) > 0.7
```

## Testing

### Generate Load for Testing

```bash
# Generate load
./generate-load.sh

# Monitor alerts
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

### Verify Alerts

1. Access Grafana at http://localhost:3000
2. Navigate to Alerting → Alert Rules
3. Check for firing alerts
4. Verify email notifications

## Troubleshooting

### Common Issues

1. **Prometheus not collecting metrics:**
   ```bash
   kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus
   kubectl get endpoints -n monitoring
   ```

2. **Grafana not accessible:**
   ```bash
   kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
   kubectl get svc -n monitoring
   ```

3. **Storage issues:**
   ```bash
   kubectl get pvc -n monitoring
   kubectl describe pvc -n monitoring
   ```

### Useful Commands

```bash
# Check all monitoring resources
kubectl get all -n monitoring

# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Visit http://localhost:9090/targets

# Check Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana

# Check alert rules
kubectl get prometheusrules -n monitoring

# Check notification channels
kubectl get configmap grafana-notification-channels -n monitoring -o yaml
```

## Cleanup

```bash
# Remove monitoring stack
kubectl delete namespace monitoring

# Or use Helm
helm uninstall prometheus -n monitoring
helm uninstall grafana -n monitoring

# Remove load testing
kubectl delete namespace load-test
```

## Security Notes

1. **Change default passwords** in production
2. **Restrict network access** to monitoring endpoints
3. **Use RBAC** for proper access control
4. **Store secrets** in Kubernetes secrets
5. **Enable TLS** for external access

## Production Considerations

1. **High Availability**: Deploy multiple replicas
2. **Backup**: Configure backup for Prometheus data
3. **Scaling**: Adjust resource limits based on cluster size
4. **Security**: Implement proper authentication and authorization
5. **Monitoring**: Monitor the monitoring stack itself 