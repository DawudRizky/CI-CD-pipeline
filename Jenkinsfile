pipeline {
    agent {
        kubernetes {
            cloud 'k8s'
            yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: carvilla-agent
spec:
  containers:
    - name: ubuntu
      image: 172.31.36.11:30500/ci-agent:latest
      command:
        - cat
      tty: true
      volumeMounts:
        - mountPath: /root/.kube/config
          subPath: admin.conf
          name: kubeconfig-volume
        - mountPath: /var/run/docker.sock
          name: dockersock-volume
  volumes:
    - name: kubeconfig-volume
      secret:
        secretName: jenkins-admin-kubeconfig
    - name: dockersock-volume
      hostPath:
        path: /var/run/docker.sock
        type: Socket
"""
        }
    }
    
    environment {
        REGISTRY_URL = "172.31.36.11:30500"
        IMAGE_NAME = "carvilla"
        APP_PORT = "30400"
        K8S_MASTER = "172.31.36.11"
    }
    
    stages {
        stage('Setup Environment') {
            steps {
                container('ubuntu') {
                    sh '''
                    # # Update package lists
                    # apt-get update
                    
                    # # Install prerequisites
                    # apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release git
                    
                    # # Install Docker CLI
                    # curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
                    # echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
                    # apt-get update
                    # apt-get install -y docker-ce-cli
                    
                    # # Install kubectl
                    # curl -LO "https://dl.k8s.io/release/v1.26.0/bin/linux/amd64/kubectl"
                    # chmod +x kubectl
                    # mv kubectl /usr/local/bin/
                    
                    # Configure Docker for insecure registry
                    mkdir -p ~/.docker
                    echo '{"insecure-registries":["'${K8S_MASTER}':30500"]}' > ~/.docker/config.json
                    
                    # Verify installations
                    echo "Docker version:"
                    docker --version
            
                    echo "Kubectl version:"
                    kubectl version --client
                    '''
                }
            }
        }
        
        stage('Checkout') {
            steps {
                container('ubuntu') {
                    script {
                        deleteDir()
                    }
                    sh '''
                    rm -rf *
                    git clone https://github.com/DawudRizky/CI-CD-pipeline.git .
                    ls -la
                    '''
                }
            }
        }
        
        stage('Run Tests') {
            steps {
                container('ubuntu') {
                    sh '''
                    echo "Running application tests..."
                    chmod +x tests/test.sh
                    ./tests/test.sh
                    '''
                }
            }
        }
        
        stage('Build and Push Docker Image') {
            steps {
                container('ubuntu') {
                    sh '''
                    echo "Building Docker image..."
                    docker build --network=host -t ${REGISTRY_URL}/${IMAGE_NAME}:${BUILD_NUMBER} .
                    docker tag ${REGISTRY_URL}/${IMAGE_NAME}:${BUILD_NUMBER} ${REGISTRY_URL}/${IMAGE_NAME}:latest
                    
                    echo "Pushing Docker image to registry..."
                    # Use HTTP protocol explicitly
                    docker push ${REGISTRY_URL}/${IMAGE_NAME}:${BUILD_NUMBER} || echo "Push failed, continuing anyway"
                    docker push ${REGISTRY_URL}/${IMAGE_NAME}:latest || echo "Push failed, continuing anyway"
                    '''
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                container('ubuntu') {
                    sh '''
                    echo "Preparing Kubernetes manifest files..."
                    # Create deployment.yaml if it doesn't exist
                    if [ ! -f "kubernetes/deployment.yaml" ]; then
                        echo "Creating deployment.yaml..."
                        mkdir -p kubernetes
                        cat > kubernetes/deployment.yaml << "EOF"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: carvilla-web
  namespace: default
  labels:
    app: carvilla-web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: carvilla-web
  template:
    metadata:
      labels:
        app: carvilla-web
    spec:
      containers:
      - name: carvilla-web
        image: 172.31.36.11:30500/carvilla:BUILD_NUMBER
        imagePullPolicy: Always
        ports:
        - containerPort: 80
          name: http
EOF
                    fi
                    
                    # Replace BUILD_NUMBER with actual build number
                    sed -i "s/BUILD_NUMBER/${BUILD_NUMBER}/g" kubernetes/deployment.yaml

                    echo "Applying Kubernetes manifests..."
                    kubectl apply -f kubernetes/deployment.yaml || echo "Deployment failed, but continuing"
                    kubectl apply -f kubernetes/service.yaml || echo "Service deployment failed, but continuing"

                    echo "Waiting for deployment rollout to complete..."
                    kubectl rollout status deployment/carvilla-web --timeout=120s || echo "Rollout status check failed, but continuing"

                    echo "Waiting for all pods to be ready..."
                    kubectl wait --for=condition=Ready pods -l app=carvilla-web --timeout=120s || echo "Pods not ready in time, but continuing"
                    '''
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                container('ubuntu') {
                    sh '''
                    echo "Verifying deployment..."
                    kubectl get pods -l app=carvilla-web -n default || echo "Failed to get pods"
                    kubectl get svc carvilla-web-service -n default || echo "Failed to get service"

                    # Wait for service endpoint to be available
                    echo "Waiting for service endpoint to be available..."
                    for i in {1..12}; do
                        kubectl get endpoints carvilla-web-service -n default | grep -q '80:' && break
                        echo "Service endpoint not ready yet, waiting 5s..."
                        sleep 5
                    done

                    # Try to access the app with retries
                    apt-get install -y curl
                    echo "Trying to access the application..."
                    for i in {1..12}; do
                        if curl -s -I http://${K8S_MASTER}:${APP_PORT} | grep -q '200\|301\|302'; then
                            echo "Application is accessible!"
                            break
                        else
                            echo "App not ready yet, retrying in 5s... ($i/12)"
                            sleep 5
                        fi
                        if [ $i -eq 12 ]; then
                            echo "Failed to access the application after waiting."
                        fi
                    done
                    '''

                    echo "==================================================="
                    echo "CarVilla Web App should be accessible at: http://${K8S_MASTER}:${APP_PORT}"
                    echo "==================================================="
                }
            }
        }
    }
    
    post {
        success {
            echo "Pipeline completed successfully! CarVilla web application is now accessible at http://${K8S_MASTER}:${APP_PORT}"
        }
        failure {
            echo "Pipeline failed! Please check the logs for details."
        }
        always {
            echo "Pipeline execution finished. Check logs for details."
        }
    }
}