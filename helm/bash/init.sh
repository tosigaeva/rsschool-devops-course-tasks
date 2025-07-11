#!/bin/bash

curl -sfL https://get.k3s.io | sh -
sudo chmod 644 /etc/rancher/k3s/k3s.yaml

kubectl create namespace jenkins

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

cat <<EOL | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins
  namespace: jenkins
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: jenkins
rules:
  - apiGroups: ["*"]
     resources: ["*"]
    verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: jenkins
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
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install -y helm

helm repo add jenkins https://charts.jenkins.io
helm repo update

mkdir -p /tmp/jenkins-volume
chown -R 1000:1000 /tmp/jenkins-volume

helm install jenkins jenkins/jenkins --namespace jenkins \
  --set controller.serviceType=LoadBalancer \
  --set persistence.enabled=true \
  --set persistence.size=8Gi \
  --set persistence.existingClaim=jenkins-pvc \
  --set controller.installPlugins="cloudbees-credentials,git,workflow-aggregator,jacoco,jacoco,configuration-as-code"

sudo systemctl status k3s
kubectl get all -n kube-system

kubectl get nodes

# deploy simple workload
kubectl apply -f https://k8s.io/examples/pods/simple-pod.yaml

# Install autocompletion in kubectl
#    https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#enable-shell-autocompletion
sudo apt install -y bash-completion
echo 'source <(kubectl completion bash)' >>~/.bashrc
source ~/.bashrc
kubectl get pods

exit 0
