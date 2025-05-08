#!/bin/bash

NODE_IP=$(minikube ip)
NODE_PORT=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')

if [ -z "$NODE_PORT" ] || [ -z "$NODE_IP" ]; then
    echo "Failed to determine NodePort or Node IP"
    exit 1
fi

GATEWAY_URL="http://${NODE_IP}:${NODE_PORT}"

# Configuration
BASE_URL="$GATEWAY_URL"
METRICS_ENDPOINT="/metrics"
LOGS_ENDPOINT="/logs"
STATUS_ENDPOINT="/status"
WELCOME_ENDPOINT="/"

echo "Testing service through Istio gateway at ${BASE_URL}"

echo -e "\n1. Testing welcome endpoint:"
curl -s "${BASE_URL}/"
echo -e "\n"

echo -e "2. Testing status endpoint:"
curl -s "${BASE_URL}/status" | jq '.'
echo -e "\n"

echo -e "3. Testing log creation with concurrent requests:"
for i in {1..10}; do
    (
        echo "Creating log entry $i..."
        curl -s -X POST -H "Content-Type: application/json" \
            -d "{\"message\":\"test log $i\"}" \
            "${BASE_URL}/log" | jq '.'
    ) &
done
wait
echo -e "\n"

echo -e "4. Testing logs retrieval:"
curl -s "${BASE_URL}/logs" | jq '.'
echo -e "\n"

echo -e "5. Testing Istio routing (404 for unknown route):"
curl -s -w "\nStatus Code: %{http_code}\n" "${BASE_URL}/wrong"
echo -e "\n"

echo -e "6. Checking log agent:"
kubectl logs -l app=log-agent --tail=5
echo -e "\n"

echo -e "7. Checking cronjob status:"
kubectl get cronjob log-archiver
echo -e "\n"

echo -e "8. Checking manual cronjob logs:"
kubectl delete job manual-archive --ignore-not-found
kubectl create job --from=cronjob/log-archiver manual-archive

echo "Waiting 10s..."
sleep 10

POD_NAME=$(kubectl get pods -l job-name=manual-archive -o name)
if [ -n "$POD_NAME" ]; then
    echo "Archive job pod: $POD_NAME"
    kubectl logs $POD_NAME
else
    echo "No archive pod found"
fi

echo -e "\n9. Checking Prometheus metrics:"
echo "Querying Prometheus for application metrics..."
PROM_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath="{.items[0].metadata.name}")

echo "Application metrics:"
APP_METRICS=$(kubectl exec -n monitoring $PROM_POD -c prometheus -- wget -qO- 'http://localhost:9090/api/v1/query?query=log_requests_total' | jq -r '.data.result[] | "\(.metric.job): \(.value[1])"')
if [ -n "$APP_METRICS" ]; then
    echo "Log requests total: $APP_METRICS"
else
    echo "No application metrics found yet"
fi

echo -e "\n10. Checking Istio metrics:"
echo "Querying Prometheus for Istio metrics..."

echo "Istio request metrics:"
ISTIO_REQUESTS=$(kubectl exec -n monitoring $PROM_POD -c prometheus -- wget -qO- \
  'http://localhost:9090/api/v1/query?query=istio_requests_total' \
  | jq -r '.data.result[] | "\(.metric.destination_service): \(.value[1])"')
if [ -n "$ISTIO_REQUESTS" ]; then
    echo "Total requests:"
    echo "$ISTIO_REQUESTS"
else
    echo "No Istio request metrics found yet"
fi

echo -e "\nIstio response codes:"
ISTIO_CODES=$(kubectl exec -n monitoring $PROM_POD -c prometheus -- wget -qO- \
  'http://localhost:9090/api/v1/query?query=istio_requests_total' \
  | jq -r '.data.result[] | select(.metric.response_code != null) | "\(.metric.destination_service) - \(.metric.response_code): \(.value[1])"')
if [ -n "$ISTIO_CODES" ]; then
    echo "Response codes:"
    echo "$ISTIO_CODES"
else
    echo "No Istio response code metrics found yet"
fi

echo -e "\nTesting completed!" 