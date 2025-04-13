#!/bin/bash

eval $(minikube docker-env)

docker build -t logging-app:latest .

kubectl apply -f configmap.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f daemonset.yaml
kubectl apply -f cronjob.yaml

timeout 300 kubectl rollout status deployment app-deployment

if [ $? -ne 0 ]; then
    echo "Deployment timed out. Checking pod status..."
    kubectl get pods
    kubectl describe deployment app-deployment
    kubectl logs -l app=logging-app
    exit 1
fi

minikube service app-service --url

echo "Deployment complete!"
