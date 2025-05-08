#!/bin/bash

check_prerequisites() {
    if ! command -v istioctl &> /dev/null; then
        echo "istioctl is not installed, installing now"
        curl -L https://istio.io/downloadIstio | sh -
        sudo cp istio-*/bin/istioctl /usr/local/bin/
    fi

    if ! command -v helm &> /dev/null; then
        echo "helm is not installed, installing now"
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi
}

check_prerequisites

kubectl label namespace default istio-injection=enabled

if ! kubectl get namespace istio-system > /dev/null 2>&1; then
    echo "Installing Istio..."
    istioctl install --set profile=demo -y
fi

kubectl patch svc istio-ingressgateway -n istio-system --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/ports/-",
    "value": {
      "name": "http-envoy-prom",
      "protocol": "TCP",
      "port": 15090,
      "targetPort": 15090
    }
  }
]'

if ! kubectl get namespace monitoring > /dev/null 2>&1; then
    echo "Installing Prometheus stack..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    helm install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
        --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false
fi

eval $(minikube docker-env)
docker build -t logging-app:latest .

kubectl apply -f configmap.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f daemonset.yaml
kubectl apply -f cronjob.yaml
kubectl apply -f istio-gateway.yaml
kubectl apply -f istio-virtualservice.yaml
kubectl apply -f istio-destinationrule.yaml
kubectl apply -f prometheus-servicemonitor.yaml
kubectl apply -f istio-servicemonitor.yaml

timeout 300 kubectl rollout status deployment app-deployment

if [ $? -ne 0 ]; then
    echo "Deployment timed out. Checking pod status..."
    kubectl get pods
    kubectl describe deployment app-deployment
    kubectl logs -l app=logging-app
    exit 1
fi

echo "Deployment complete!"
