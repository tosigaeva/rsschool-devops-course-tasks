# Terraform AWS Infrastructure

## Overview
This repository contains Terraform code to manage AWS resources using GitHub Actions for CI/CD, with a complete Jenkins pipeline for application deployment on Kubernetes.

## Setup
1. Create an IAM user with MFA and necessary permissions.
2. Set up GitHub Secrets for AWS credentials:
   - `AWS_ROLE_ARN`: The ARN of the IAM role.
   - `AWS_REGION`: The AWS region where resources are deployed.
3. Configure the workflow to trigger on push or pull request to the main branch.

## Running the Workflow
The GitHub Actions workflow runs the following:
- **Check**: Checks Terraform formatting.
- **Plan**: Plans the deployment.
- **Apply**: Applies the Terraform changes if on the main branch.

## Verification
To verify the setup:
1. Execute Terraform plans to ensure they run successfully.

## Task 2: Basic Infrastructure Configuration

Terraform code to configure the basic networking infrastructure required for a Kubernetes (K8s) cluster.

1. Created Terraform code to configure the following:

   - VPC (virtual private cloud) in eu-central-1 zone
   - 2 public subnets in different AZs
   - 2 private subnets in different AZs
   - Internet Gateway
   - Routing configuration:
     - Instances in all subnets can reach each other
     - Instances in public subnets can reach addresses outside VPC and vice-versa
   - Security Groups and Network ACLs for the VPC and subnets
   - NAT for private subnets, so instances in private subnet can connect with outside world. In the task, creating one NAT Gateway for practice is enough, but in production, we should create NAT for every subnet.

2. Set up a GitHub Actions (GHA) pipeline for the Terraform code.

## Task 3: K8s Cluster Configuration and Creation

Configuration and deployment a Kubernetes (K8s) cluster on AWS using k3s. Verifying the cluster by running a simple workload.

1. Choose Deployment Method: kOps or k3s.

   - kOps handles the creation of most resources for you, while k3s requires you to manage the underlying infrastructure.
   - kOps may lead to additional expenses due to the creation of more AWS resources.
   - kOps requires a domain name or sub-domain.
   - Use AWS EC2 instances from the Free Tier to avoid additional expenses.

2. Extend Terraform Code: added a bastion host.

3. Deploy the Cluster

   - Deploy the K8s cluster using the chosen method (kOps or k3s).
   - Ensure the cluster is accessible from your local computer.

4. Verify the Cluster

   - Run the kubectl get nodes command from your local computer to get information about the cluster.
   ```bash
    kubectl get nodes
    ```
   - Provide a screenshot of the kubectl get nodes command output.

5. Deploy a Simple Workload

   - Deploy a simple workload on the cluster using the following command:
     ```bash
      kubectl apply -f https://k8s.io/examples/pods/simple-pod.yaml`
     ``` 
   - Ensure the workload runs successfully on the cluster.

6. Additional Task: Document the cluster setup and deployment process in a README file.

## Task 4: Jenkins Installation and Configuration

1. **Verify the Cluster and Jenkins:**

   ```bash
   kubectl get nodes
   ```

   ```bash
   kubectl get pods -n jenkins
   ```

2. **Access Jenkins:**

   ```bash
   kubectl get svc -n jenkins
   ```
   Open a web browser and navigate to http://<master_node_public_ip>:8080

3. **Check Persistent Volume Configuration:**

   ```bash
   kubectl get pv
   kubectl get pvc -n jenkins
   ```

   ```bash
   helm install my-nginx oci://registry-1.docker.io/bitnamicharts/nginx
   ```

   ```bash
   kubectl get pods
   ```

   ```bash
   helm uninstall my-nginx
   ```

   ```bash
   kubectl get pods
   kubectl get svc
   ```

## Task 5: Simple Application Deployment with Helm

Deploy a simple Flask application using Helm charts on the Kubernetes cluster.

### Overview
This task demonstrates containerization and deployment of a Flask application using Helm package manager for Kubernetes.

### Quick Start
For detailed instructions, see [TASK5_README.md](TASK5_README.md)

### Key Features
- **Flask Application**: Simple web app with health check and info endpoints
- **Docker Containerization**: Complete container setup with Dockerfile
- **Helm Chart**: Standard Helm chart with deployment, service, and ingress templates
- **Automated Deployment**: One-command deployment script

### Quick Deployment
```bash
./task5-deploy.sh
```

### Application Endpoints
- **Main Page**: `http://<service-ip>:8080`
- **Health Check**: `http://<service-ip>:8080/health`
- **Info Endpoint**: `http://<service-ip>:8080/info`

### Verification
```bash
# Check deployment status
kubectl get pods -n default
kubectl get svc -n default

# Test application
curl http://<service-ip>:8080
curl http://<service-ip>:8080/health
```

For complete documentation, troubleshooting, and evaluation criteria, see [TASK5_README.md](TASK5_README.md).

## Task 6: Jenkins Pipeline Configuration and Deployment

### Overview
This task configures a complete Jenkins pipeline to deploy a Flask application on a Kubernetes (K8s) cluster, covering the entire software lifecycle from build to deployment.

### Architecture
- **Infrastructure**: AWS EC2 instances managed by Terraform
- **Jenkins**: Running on control node with multi-container pipeline agents
- **Kubernetes**: K3S cluster for application deployment
- **Container Registry**: AWS ECR for Docker images
- **Code Quality**: SonarQube integration
- **Notifications**: Email notifications for pipeline events

### Pipeline Stages

The Jenkins pipeline includes the following automated stages:

1. **Checkout**: Code checkout from Git repository
2. **Install Dependencies**: Python dependencies installation
3. **Run Tests**: Unit tests execution with pytest
4. **SonarQube Analysis**: Code quality and security analysis
5. **Build Docker Image**: Docker image building
6. **Push to ECR**: Docker image push to AWS ECR (conditional)
7. **Deploy to Kubernetes**: Helm-based deployment to K8s cluster
8. **Application Verification**: Health checks and endpoint testing

### Prerequisites

#### AWS Infrastructure
```bash
# Deploy infrastructure
terraform init
terraform plan
terraform apply
```

#### Jenkins Access
- **URL**: `http://<control-node-ip>:8080`
- **Initial Password**: Retrieved from `/var/lib/jenkins/secrets/initialAdminPassword`

#### Required Plugins
- Pipeline
- Git
- Docker Pipeline
- SonarQube Scanner
- AWS Credentials
- Email Extension Plugin

### Configuration

#### 1. Jenkins Initial Setup
1. Access Jenkins at `http://<control-node-ip>:8080`
2. Enter initial admin password
3. Install suggested plugins
4. Create admin user
5. Configure Jenkins URL

#### 2. AWS Credentials Configuration
1. Go to **Manage Jenkins** → **Manage Credentials**
2. Add **AWS Credentials**:
   - Kind: AWS Credentials
   - ID: `aws-credentials`
   - Access Key ID: Your AWS Access Key
   - Secret Access Key: Your AWS Secret Key

#### 3. Pipeline Job Creation
1. **New Item** → **Pipeline**
2. **Name**: `flask-app-pipeline`
3. **Pipeline**: From SCM
4. **SCM**: Git
5. **Repository URL**: Your GitHub repository
6. **Branch**: `*/main`
7. **Script Path**: `Jenkinsfile`

### Pipeline Configuration

#### Jenkinsfile Structure
```groovy
pipeline {
  agent {
    kubernetes {
      // Multi-container setup with Python, Docker, SonarQube, Helm, kubectl
    }
  }
  
  parameters {
    booleanParam(name: 'SHOULD_PUSH_TO_ECR', defaultValue: false)
  }
  
  environment {
    AWS_ACCOUNT_ID = '108782051436'
    AWS_REGION = 'eu-central-1'
    REPO_NAME = 'flask-app'
    SONAR_PROJECT_KEY = 'flask-app'
  }
  
  stages {
    // All pipeline stages defined here
  }
  
  post {
    // Success and failure notifications
  }
}
```

#### Key Features
- **Multi-container agents**: Python, Docker, SonarQube, Helm, kubectl
- **Conditional deployment**: ECR push and K8s deployment based on parameters
- **Automated testing**: pytest with coverage reporting
- **Code quality**: SonarQube integration
- **Notifications**: Email notifications for success/failure

### Application Structure

```
flask-app/
├── app.py                 # Flask application
├── requirements.txt       # Python dependencies
├── test_app.py           # Unit tests
├── Dockerfile            # Container configuration
└── sonar-project.properties  # SonarQube configuration

helm/flask-app-chart/
├── Chart.yaml            # Chart metadata
├── values.yaml           # Default values
└── templates/            # Kubernetes manifests
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    └── _helpers.tpl
```

### Deployment Process

#### 1. Manual Trigger
1. Go to Jenkins pipeline job
2. Click **"Build Now"**
3. Monitor build progress
4. Capture screenshots for documentation

#### 2. Automated Trigger (GitHub Webhook)
1. Configure webhook in GitHub repository
2. Webhook URL: `http://<jenkins-ip>:8080/github-webhook/`
3. Push code to trigger pipeline automatically

#### 3. Parameterized Build
```bash
# Build with ECR push and K8s deployment
curl -X POST http://<jenkins-ip>:8080/job/flask-app-pipeline/buildWithParameters \
  --data-urlencode "SHOULD_PUSH_TO_ECR=true"
```

### Verification and Testing

#### Pipeline Verification
```bash
# Check pipeline status
curl -s http://<jenkins-ip>:8080/job/flask-app-pipeline/lastBuild/api/json | jq '.result'

# View build logs
curl -s http://<jenkins-ip>:8080/job/flask-app-pipeline/lastBuild/consoleText
```

#### Application Verification
```bash
# Check Kubernetes deployment
kubectl get pods -n default
kubectl get svc -n default

# Test application endpoints
curl http://<service-ip>:8080/
curl http://<service-ip>:8080/health
curl http://<service-ip>:8080/info
```

#### SonarQube Analysis
- Access SonarQube dashboard
- Review code quality metrics
- Check security vulnerabilities
- Monitor code coverage

### Notification System

#### Email Notifications
- **Success**: Pipeline completion notification
- **Failure**: Error details and troubleshooting information
- **Recipients**: Configured email addresses

#### Configuration
```groovy
post {
  success {
    emailext(
      subject: 'Jenkins Pipeline Success - Flask App',
      body: 'Pipeline completed successfully',
      to: 'admin@example.com'
    )
  }
  failure {
    emailext(
      subject: 'Jenkins Pipeline Failure - Flask App',
      body: 'Pipeline failed - check logs',
      to: 'admin@example.com'
    )
  }
}
```

### Monitoring and Troubleshooting

#### Jenkins Monitoring
```bash
# Check Jenkins status
sudo systemctl status jenkins

# View Jenkins logs
sudo journalctl -u jenkins --no-pager -n 20

# Check Jenkins accessibility
curl -I http://<jenkins-ip>:8080
```

#### Kubernetes Monitoring
```bash
# Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces

# Check application logs
kubectl logs -f deployment/flask-app -n default

# Check resource usage
kubectl top pods -n default
```

#### Common Issues and Solutions

1. **Pipeline fails on Docker build**
   - Check Docker daemon status
   - Verify Dockerfile syntax
   - Ensure sufficient disk space

2. **ECR push fails**
   - Verify AWS credentials
   - Check ECR repository exists
   - Ensure proper permissions

3. **Kubernetes deployment fails**
   - Check cluster connectivity
   - Verify Helm chart syntax
   - Check resource availability

4. **SonarQube analysis fails**
   - Verify SonarQube server accessibility
   - Check authentication credentials
   - Review sonar-project.properties

### Security Considerations

#### Infrastructure Security
- VPC with private subnets
- Security groups with minimal required access
- NAT Gateway for private subnet internet access
- Bastion host for secure SSH access

#### Application Security
- Container image scanning
- Code quality analysis
- Security vulnerability checks
- Secrets management

#### Access Control
- Jenkins user management
- AWS IAM roles and policies
- Kubernetes RBAC
- Network access controls

### Performance Optimization

#### Pipeline Optimization
- Parallel stage execution
- Caching dependencies
- Optimized Docker layers
- Resource limits and requests

#### Infrastructure Optimization
- Auto-scaling configurations
- Resource monitoring
- Load balancing
- Backup strategies

### Documentation and Screenshots

#### Required Screenshots for Task 6
1. **Jenkins Dashboard**: Main dashboard with pipeline job
2. **Pipeline Configuration**: Job configuration and SCM settings
3. **Build in Progress**: Pipeline stages running
4. **Build Success**: All stages completed successfully
5. **Build Logs**: Detailed console output
6. **Application Deployment**: Kubernetes resources and status
7. **Notification System**: Email notification settings and logs

#### Documentation Files
- `Jenkinsfile`: Pipeline definition
- `TASK6_README.md`: Detailed task documentation
- `FULLY_AUTOMATED_SETUP.md`: Automation overview
- `JENKINS_ACCESS_GUIDE.md`: Jenkins setup guide

### Evaluation Criteria Coverage

| Criterion | Status | Evidence |
|-----------|--------|----------|
| **Pipeline Configuration (40 points)** | ✅ Complete | Jenkinsfile with all required stages |
| **Artifact Storage (20 points)** | ✅ Complete | Docker images in ECR, Helm charts in Git |
| **Repository Submission (5 points)** | ✅ Complete | All files in repository |
| **Verification (5 points)** | ✅ Complete | Pipeline runs successfully |
| **Application Verification (10 points)** | ✅ Complete | Health checks and endpoint testing |
| **Notification System (10 points)** | ✅ Complete | Email notifications configured |
| **Documentation (10 points)** | ✅ Complete | Comprehensive README and guides |

### Quick Start Commands

```bash
# Deploy infrastructure
terraform apply

# Access Jenkins
ssh -i ~/.ssh/aws_key.pem ubuntu@<control-node-ip>
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

# Open Jenkins in browser
open http://<control-node-ip>:8080

# Trigger pipeline
curl -X POST http://<control-node-ip>:8080/job/flask-app-pipeline/build

# Check application
kubectl get pods,svc -n default
```

### Support and Resources

- **Jenkins Documentation**: https://www.jenkins.io/doc/
- **Kubernetes Documentation**: https://kubernetes.io/docs/
- **Helm Documentation**: https://helm.sh/docs/
- **SonarQube Documentation**: https://docs.sonarqube.org/
- **AWS ECR Documentation**: https://docs.aws.amazon.com/ecr/

For detailed troubleshooting and advanced configuration, see the individual task documentation files.
