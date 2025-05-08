#!/bin/bash

echo "Cleaning up..."

kubectl delete deployment app-deployment
kubectl delete service app-service
kubectl delete daemonset log-agent
kubectl delete cronjob log-archiver
kubectl delete configmap app-config

echo "Cleaning up Istio..."
kubectl delete virtualservice app-virtualservice
kubectl delete gateway app-gateway
kubectl delete destinationrule app-destinationrule
kubectl delete servicemonitor istio-servicemonitoring 2>/dev/null || true
kubectl label namespace default istio-injection- 2>/dev/null || true

echo "Cleaning up Prometheus..."
kubectl delete servicemonitor app-servicemonitor
helm uninstall prometheus -n monitoring 2>/dev/null || true

kubectl wait --for=delete deployment/app-deployment --timeout=60s 2>/dev/null || true
kubectl wait --for=delete service/app-service --timeout=60s 2>/dev/null || true
kubectl wait --for=delete daemonset/log-agent --timeout=60s 2>/dev/null || true
kubectl wait --for=delete virtualservice/app-virtualservice --timeout=60s 2>/dev/null || true
kubectl wait --for=delete gateway/app-gateway --timeout=60s 2>/dev/null || true
kubectl wait --for=delete destinationrule/app-destinationrule --timeout=60s 2>/dev/null || true

echo "Cleaning up Docker image..."
eval $(minikube docker-env)
docker rmi logging-app:latest 2>/dev/null || true
eval $(minikube docker-env -u)

echo "Force cleaning remaining pods..."
kubectl get pods | grep app-deployment | awk '{print $1}' | xargs kubectl delete pod --force --grace-period=0 2>/dev/null || true

if kubectl get namespace istio-system > /dev/null 2>&1; then
    echo "Uninstalling Istio..."
    istioctl uninstall --purge -y
    kubectl delete namespace istio-system
fi

echo "Cleaning up namespaces..."
kubectl delete namespace monitoring 2>/dev/null || true

echo "Cleanup complete!" 