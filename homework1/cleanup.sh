#!/bin/bash

echo "Cleaning..."

kubectl delete deployment app-deployment
kubectl delete service app-service
kubectl delete daemonset log-agent
kubectl delete cronjob log-archiver
kubectl delete configmap app-config

kubectl wait --for=delete deployment/app-deployment --timeout=60s 2>/dev/null || true
kubectl wait --for=delete service/app-service --timeout=60s 2>/dev/null || true
kubectl wait --for=delete daemonset/log-agent --timeout=60s 2>/dev/null || true

eval $(minikube docker-env)
docker rmi logging-app:latest 2>/dev/null || true

eval $(minikube docker-env -u)

kubectl get pods | grep app-deployment | awk '{print $1}' | xargs kubectl delete pod --force --grace-period=0 2>/dev/null || true

echo "Cleanup complete!" 