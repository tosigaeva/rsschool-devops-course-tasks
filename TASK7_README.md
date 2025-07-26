# Task 7: Prometheus Deployment on K8s

## Overview

This task implements a comprehensive monitoring solution for the Kubernetes cluster using Prometheus and Grafana. The setup includes metrics collection, visualization, and alerting capabilities.

## Architecture

The monitoring stack consists of:

- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and alerting
- **Node Exporter**: Node-level metrics
- **Kube State Metrics**: Kubernetes cluster metrics
- **Alertmanager**: Alert routing and notification

## Components

### 1. Prometheus Stack

Located in `helm/prometheus-chart/`:
- `Chart.yaml`: Helm chart definition with Prometheus dependencies
- `values.yaml`: Configuration for Prometheus, Alertmanager, and Grafana

### 2. Grafana Configuration

Located in `helm/grafana-chart/`:
- `Chart.yaml`: Helm chart definition for Grafana
- `values.yaml`: Grafana configuration
- `templates/`: Kubernetes manifests for:
  - Data sources configuration
  - Alerting rules
  - Notification channels
  - Dashboard definitions

### 3. Deployment Scripts

- `deploy-monitoring.sh`: Automated deployment of the monitoring stack
- `test-monitoring.sh`: Testing and validation script

## Installation

### Prerequisites

- Kubernetes cluster with Helm 3.x
- kubectl configured to access the cluster
- Storage class `gp2` available (for AWS EKS)

### Deployment Steps

1. **Clone the repository and navigate to the project directory:**
   ```bash
   cd rsschool-devops-course-tasks
   ```

2. **Make scripts executable:**
   ```bash
   chmod +x deploy-monitoring.sh test-monitoring.sh
   ```

3. **Deploy the monitoring stack:**
   ```bash
   ./deploy-monitoring.sh
   ```

4. **Verify the deployment:**
   ```bash
   kubectl get all -n monitoring
   ```

5. **Test the setup:**
   ```bash
   ./test-monitoring.sh
   ```

## Configuration

### Prometheus Configuration

The Prometheus stack is configured with:

- **Retention**: 7 days
- **Storage**: 10Gi persistent volume
- **Scraping**: Kubernetes service discovery
- **Metrics**: Node and container metrics

### Grafana Configuration

Grafana is configured with:

- **Admin Password**: `admin123` (stored in secret)
- **Data Source**: Prometheus
- **Dashboards**: Kubernetes cluster and pod monitoring
- **SMTP**: Email notifications (configure your email in values.yaml)

### Alert Rules

The following alert rules are configured:

1. **High CPU Usage**: Triggers when pod CPU usage > 80%
2. **High Memory Usage**: Triggers when pod memory usage > 80%
3. **Node High CPU**: Triggers when node CPU usage > 80%
4. **Node High Memory**: Triggers when node memory usage > 80%
5. **Pod Restarting**: Triggers when pods restart frequently
6. **Node Down**: Triggers when node-exporter is down

### SMTP Configuration

To configure email alerts, update the SMTP settings in `helm/grafana-chart/values.yaml`:

```yaml
smtp:
  enabled: true
  host: "smtp.gmail.com:587"
  user: "your-email@gmail.com"
  password: "your-app-password"
  fromAddress: "your-email@gmail.com"
  fromName: "Grafana Alerts"
  startTLSPolicy: "MandatoryStartTLS"
  skipVerify: false
```

**Note**: For Gmail, you need to use an App Password instead of your regular password.

## Accessing the Monitoring Tools

### Prometheus

- **URL**: `http://<load-balancer-ip>:9090`
- **Features**: 
  - Query metrics
  - View targets
  - Check alert rules
  - Graph visualization

### Grafana

- **URL**: `http://<load-balancer-ip>:3000`
- **Credentials**: 
  - Username: `admin`
  - Password: `admin123`
- **Features**:
  - Pre-configured dashboards
  - Alert management
  - Notification channels

## Dashboards

### 1. Kubernetes Cluster Monitoring

Shows:
- Cluster CPU usage
- Cluster memory usage
- Node CPU usage
- Node memory usage

### 2. Kubernetes Pods Monitoring

Shows:
- Pod CPU usage
- Pod memory usage
- Pod restart counts

## Testing Alerts

### Generate Load for Testing

1. **Create a stress test pod:**
   ```bash
   kubectl run stress-test --image=busybox --command -- sh -c "while true; do echo stress; done"
   ```

2. **Generate CPU load:**
   ```bash
   kubectl exec stress-test -- sh -c "while true; do echo 'Generating CPU load...'; done"
   ```

3. **Generate memory load:**
   ```bash
   kubectl exec stress-test -- sh -c "while true; do echo 'Generating memory load...'; done"
   ```

### Verify Alerts

1. Access Grafana at `http://<load-balancer-ip>:3000`
2. Navigate to Alerting → Alert Rules
3. Check for firing alerts
4. Verify email notifications (if configured)

## Monitoring Metrics

### Key Metrics Collected

- **Node Metrics**:
  - CPU usage
  - Memory usage
  - Disk usage
  - Network I/O

- **Pod Metrics**:
  - Container CPU usage
  - Container memory usage
  - Pod restart count
  - Resource limits

- **Cluster Metrics**:
  - Node count
  - Pod count
  - Service count
  - Namespace count

### Useful Prometheus Queries

```promql
# Node CPU usage
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Node memory usage
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100

# Pod CPU usage
rate(container_cpu_usage_seconds_total{container!=""}[5m])

# Pod memory usage
container_memory_usage_bytes{container!=""}

# Pod restarts
increase(kube_pod_container_status_restarts_total[15m])
```

## Troubleshooting

### Common Issues

1. **Prometheus not collecting metrics:**
   ```bash
   kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus
   ```

2. **Grafana not accessible:**
   ```bash
   kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
   ```

3. **Alerts not firing:**
   - Check alert rules in Grafana
   - Verify Prometheus targets are up
   - Check notification channel configuration

4. **Storage issues:**
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
# Then visit http://localhost:9090/targets

# Check Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana

# Check Prometheus logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus

# Check alert rules
kubectl get prometheusrules -n monitoring
```

## Security Considerations

1. **Admin Password**: Change the default admin password in production
2. **Network Access**: Restrict access to monitoring endpoints
3. **RBAC**: Ensure proper RBAC configuration
4. **Secrets**: Store sensitive data in Kubernetes secrets

## Cleanup

To remove the monitoring stack:

```bash
# Delete the monitoring namespace
kubectl delete namespace monitoring

# Or use Helm to uninstall
helm uninstall prometheus -n monitoring
helm uninstall grafana -n monitoring
```

## Files Structure

```
rsschool-devops-course-tasks/
├── helm/
│   ├── prometheus-chart/
│   │   ├── Chart.yaml
│   │   └── values.yaml
│   └── grafana-chart/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── configmap-datasources.yaml
│           ├── configmap-alerting.yaml
│           ├── configmap-notification-channels.yaml
│           └── configmap-dashboards.yaml
├── deploy-monitoring.sh
├── test-monitoring.sh
└── TASK7_README.md
```

## Conclusion

This monitoring setup provides comprehensive visibility into the Kubernetes cluster with:

- ✅ Prometheus metrics collection
- ✅ Grafana visualization
- ✅ Automated alerting
- ✅ Email notifications
- ✅ Pre-configured dashboards
- ✅ Infrastructure as Code deployment

The solution is production-ready and can be extended with additional metrics, dashboards, and alert rules as needed. 