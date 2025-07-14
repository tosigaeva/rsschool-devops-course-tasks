resource "aws_instance" "bastion_host" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public_subnets[0].id
  vpc_security_group_ids = [
    aws_security_group.public.id,
    aws_security_group.private.id,
    aws_security_group.k3s.id
  ]
  key_name = aws_key_pair.my_key.key_name
  tags = {
    Name = "Bastion Host"
  }
}

resource "aws_instance" "control_node" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public_subnets[0].id
  vpc_security_group_ids = [
    aws_security_group.public.id,
    aws_security_group.private.id,
    aws_security_group.k3s.id
  ]
  key_name = aws_key_pair.my_key.key_name
  tags = {
    Name = "K3S Control node"
  }
  user_data = <<-EOF
              #!/bin/bash
              sudo su
              apt update && curl -sfL https://get.k3s.io | sh -

              # Wait for k3s to be ready
              while ! kubectl get nodes; do
                echo "Waiting for k3s to be ready..."
                sleep 10
              done

              # Setup kubeconfig
              mkdir -p ~/.kube
              sudo chmod 644 /etc/rancher/k3s/k3s.yaml
              sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
              sudo chown $(id -u):$(id -g) ~/.kube/config

              # Wait for node to be ready
              while [[ $(kubectl get nodes --no-headers 2>/dev/null | grep "Ready" | wc -l) -eq 0 ]]; do
                echo "Waiting for node to be ready..."
                sleep 10
              done

              # Create Jenkins namespace and resources
              kubectl create namespace jenkins

              # Create PV and PVC
              cat <<EOL | kubectl apply -f -
              apiVersion: v1
              kind: PersistentVolume
              metadata:
                name: jenkins-pv
              spec:
                capacity:
                  storage: 8Gi
                accessModes:
                  - ReadWriteOnce
                hostPath:
                  path: "/tmp/jenkins-volume"
              ---
              apiVersion: v1
              kind: PersistentVolumeClaim
              metadata:
                name: jenkins-pvc
                namespace: jenkins
              spec:
                accessModes:
                  - ReadWriteOnce
                resources:
                  requests:
                    storage: 8Gi
              EOL

              # Create RBAC resources with Helm labels and annotations
              cat <<EOL | kubectl apply -f -
              apiVersion: v1
              kind: ServiceAccount
              metadata:
                name: jenkins
                namespace: jenkins
                labels:
                  app.kubernetes.io/managed-by: Helm
                annotations:
                  meta.helm.sh/release-name: jenkins
                  meta.helm.sh/release-namespace: jenkins
              ---
              apiVersion: rbac.authorization.k8s.io/v1
              kind: ClusterRole
              metadata:
                name: jenkins
                labels:
                  app.kubernetes.io/managed-by: Helm
                annotations:
                  meta.helm.sh/release-name: jenkins
                  meta.helm.sh/release-namespace: jenkins
              rules:
                - apiGroups: ["*"]
                  resources: ["*"]
                  verbs: ["*"]
              ---
              apiVersion: rbac.authorization.k8s.io/v1
              kind: ClusterRoleBinding
              metadata:
                name: jenkins
                labels:
                  app.kubernetes.io/managed-by: Helm
                annotations:
                  meta.helm.sh/release-name: jenkins
                  meta.helm.sh/release-namespace: jenkins
              subjects:
                - kind: ServiceAccount
                  name: jenkins
                  namespace: jenkins
              roleRef:
                apiGroup: rbac.authorization.k8s.io
                kind: ClusterRole
                name: jenkins
              EOL

              curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
              echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
              sudo apt-get update -y
              sudo apt-get install -y helm

              mkdir -p /tmp/jenkins-volume
              chown -R 1000:1000 /tmp/jenkins-volume

              helm repo add jenkins https://charts.jenkins.io
              helm repo update

              while ! kubectl get namespace jenkins; do
                echo "Waiting for jenkins namespace..."
                sleep 5
              done

              helm install jenkins jenkins/jenkins --namespace jenkins \
                --set controller.serviceType=LoadBalancer \
                --set persistence.enabled=true \
                --set persistence.size=8Gi \
                --set persistence.existingClaim=jenkins-pvc \
                --set 'controller.installPlugins={cloudbees-credentials,git,workflow-aggregator,jacoco,configuration-as-code}'

              while [[ $(kubectl get pods -n jenkins -l app.kubernetes.io/component=jenkins-controller -o jsonpath='{.items[*].status.containerStatuses[*].ready}' 2>/dev/null) != "true" ]]; do
                echo "Waiting for Jenkins pod to be ready..."
                sleep 10
              done

              # Install NGINX Ingress Controller
              helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
              helm repo update
              helm install ingress-nginx ingress-nginx/ingress-nginx \
                --namespace ingress-nginx \
                --create-namespace \
                --set controller.service.type=LoadBalancer

              # Wait for ingress controller to be ready
              while [[ $(kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[*].status.containerStatuses[*].ready}' 2>/dev/null) != "true" ]]; do
                echo "Waiting for NGINX Ingress Controller to be ready..."
                sleep 10
              done
              EOF
}

resource "aws_instance" "agent_node" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.private_subnets[0].id
  vpc_security_group_ids = [
    aws_security_group.public.id,
    aws_security_group.private.id,
    aws_security_group.k3s.id
  ]
  key_name = aws_key_pair.my_key.key_name
  tags = {
    Name = "K3S Agent node"
  }
  depends_on = [aws_instance.control_node]
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "tls_private_key" "my_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "my_key" {
  key_name   = "SSH Private Key to connect to EC2 instances"
  public_key = tls_private_key.my_key.public_key_openssh
}
