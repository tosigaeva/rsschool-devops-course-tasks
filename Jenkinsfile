pipeline {
  agent {
    kubernetes {
      yaml '''
        apiVersion: v1
        kind: Pod
        metadata:
          labels:
            some-label: some-label-value
        spec:
          containers:
          - name: python
            image: python:3.9-slim
            command:
            - cat
            tty: true
          - name: docker
            image: docker:24.0.5
            command:
            - cat
            tty: true
            volumeMounts:
            - name: docker-socket
              mountPath: /var/run/docker.sock
          - name: sonarscanner
            image: sonarsource/sonar-scanner-cli
            command:
            - cat
            tty: true
          - name: helm
            image: alpine/helm:latest
            command:
            - cat
            tty: true
          - name: kubectl
            image: bitnami/kubectl:latest
            command:
            - cat
            tty: true
          volumes:
          - name: docker-socket
            hostPath:
              path: /var/run/docker.sock
      '''
      retries 2
    }
  }
  
  parameters {
    booleanParam(name: 'SHOULD_PUSH_TO_ECR', defaultValue: false, description: 'Set to true in build with params to push Docker image to ECR')
  }
  
  triggers {
    GenericTrigger(
      causeString: 'Triggered by GitHub Push',
      token: 'token',
      printPostContent: true,
      printContributedVariables: true,
      silentResponse: false
    )
  }
  
  environment {
    AWS_ACCOUNT_ID = '108782051436'
    AWS_REGION = 'eu-central-1'
    AWS_CREDENTIALS = 'aws-credentials'
    REPO_NAME = 'flask-app'
    IMAGE_TAG = 'latest'
    SONAR_PROJECT_KEY = "flask-app"
    SONAR_LOGIN = "sqp_3fca749f30de7b83ffa8301cea89d1543bad8ec9"
    SONAR_HOST_URL = "http://57.121.16.245:9000"
    KUBE_NAMESPACE = "default"
  }
  
  stages {
    stage('Checkout') {
      steps {
        container('python') {
          script {
            echo "Checking out repository..."
            checkout scm
            sh '''
              echo "Repository files:"
              ls -la
              echo "Flask app directory:"
              ls -la flask-app/
            '''
          }
        }
      }
    }
    
    stage('Install Dependencies') {
      steps {
        container('python') {
          script {
            echo "Installing Python dependencies..."
            sh '''
              cd flask-app
              pip install --no-cache-dir -r requirements.txt
              pip install pytest pytest-cov
            '''
          }
        }
      }
    }
    
    stage('Run Tests') {
      steps {
        container('python') {
          script {
            echo "Running unit tests..."
            sh '''
              cd flask-app
              python -m pytest test_app.py -v --cov=app --cov-report=term-missing --cov-report=xml
            '''
          }
        }
      }
    }
    
    stage('SonarQube Analysis') {
      steps {
        container('sonarscanner') {
          script {
            echo "Running SonarQube analysis..."
            sh '''
              cd flask-app
              sonar-scanner \
                -Dsonar.host.url=${SONAR_HOST_URL} \
                -Dsonar.login=${SONAR_LOGIN}
            '''
          }
        }
      }
    }
    
    stage('Install AWS CLI') {
      steps {
        container('docker') {
          script {
            echo "Installing AWS CLI..."
            sh '''
              apk add --no-cache python3 py3-pip
              pip3 install awscli
              aws --version
            '''
          }
        }
      }
    }
    
    stage('Build Docker Image') {
      steps {
        container('docker') {
          script {
            echo "Building Docker image..."
            sh '''
              cd flask-app
              docker build -t ${REPO_NAME}:${IMAGE_TAG} .
              docker images | grep ${REPO_NAME}
            '''
          }
        }
      }
    }
    
    stage('Push Docker Image to ECR') {
      when { expression { params.SHOULD_PUSH_TO_ECR == true } }
      steps {
        container('docker') {
          script {
            echo "Pushing Docker image to ECR..."
            withAWS(credentials: "${AWS_CREDENTIALS}", region: "${AWS_REGION}") {
              sh '''
                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}
                docker tag ${REPO_NAME}:${IMAGE_TAG} ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}:${IMAGE_TAG}
                docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}:${IMAGE_TAG}
              '''
            }
          }
        }
      }
    }
    
    stage('Create ECR Secret') {
      when { expression { params.SHOULD_PUSH_TO_ECR == true } }
      steps {
        container('docker') {
          script {
            echo "Creating ECR secret..."
            withAWS(credentials: "${AWS_CREDENTIALS}", region: "${AWS_REGION}") {
              sh '''
                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}
                kubectl create secret generic ecr-secret --namespace=${KUBE_NAMESPACE} --from-file=.dockerconfigjson=$HOME/.docker/config.json --dry-run=client -o json | kubectl apply -f -
              '''
            }
          }
        }
      }
    }
    
    stage('Deploy to Kubernetes with Helm') {
      when { expression { params.SHOULD_PUSH_TO_ECR == true } }
      steps {
        container('helm') {
          script {
            echo "Deploying to Kubernetes with Helm..."
            withAWS(credentials: "${AWS_CREDENTIALS}", region: "${AWS_REGION}") {
              sh '''
                helm upgrade --install ${REPO_NAME} ./helm/flask-app-chart \
                --set image.repository=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME} \
                --set image.tag=${IMAGE_TAG} \
                --set image.pullPolicy=Always \
                --namespace ${KUBE_NAMESPACE}
              '''
            }
          }
        }
      }
    }
    
    stage('Application Verification') {
      when { expression { params.SHOULD_PUSH_TO_ECR == true } }
      steps {
        container('kubectl') {
          script {
            echo "Verifying application deployment..."
            sh '''
              # Wait for deployment to be ready
              kubectl wait --for=condition=available --timeout=300s deployment/${REPO_NAME} -n ${KUBE_NAMESPACE}
              
              # Get the service URL
              SERVICE_URL=$(kubectl get service ${REPO_NAME} -n ${KUBE_NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
              
              if [ -n "$SERVICE_URL" ]; then
                echo "Service URL: $SERVICE_URL"
                
                # Wait for service to be accessible
                sleep 30
                
                # Test the main endpoint
                echo "Testing main endpoint..."
                curl -f http://$SERVICE_URL:8080/ || echo "Main endpoint test failed"
                
                # Test the health endpoint
                echo "Testing health endpoint..."
                curl -f http://$SERVICE_URL:8080/health || echo "Health endpoint test failed"
                
                # Test the info endpoint
                echo "Testing info endpoint..."
                curl -f http://$SERVICE_URL:8080/info || echo "Info endpoint test failed"
              else
                echo "Service URL not available yet"
              fi
            '''
          }
        }
      }
    }
  }
  
  post {
    success {
      script {
        echo "Pipeline completed successfully!"
        emailext(
          subject: 'Jenkins Pipeline Success - Flask App',
          body: "'${env.JOB_NAME}' (#${env.BUILD_NUMBER}) has completed successfully.\n\nReport: ${env.BUILD_URL}\n\nApplication deployed to Kubernetes cluster.",
          to: 'test@example.com'
        )
      }
    }
    failure {
      script {
        echo "Pipeline failed!"
        emailext(
          subject: 'Jenkins Pipeline Failure - Flask App',
          body: "'${env.JOB_NAME}' (#${env.BUILD_NUMBER}) failed.\n\nReport: ${env.BUILD_URL}\n\nPlease check the logs for more details.",
          to: 'test@example.com'
        )
      }
    }
    always {
      script {
        echo "Cleaning up workspace..."
        cleanWs()
      }
    }
  }
}
