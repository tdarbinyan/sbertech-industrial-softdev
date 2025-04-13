#!/bin/bash

MINIKUBE_IP=$(minikube ip)
SERVICE_PORT=30000
SERVICE_URL="http://${MINIKUBE_IP}:${SERVICE_PORT}"

echo "Testing service at ${SERVICE_URL}"

echo -e "\n1. Testing welcome endpoint:"
curl -s "${SERVICE_URL}/"
echo -e "\n"

echo -e "2. Testing status endpoint:"
curl -s "${SERVICE_URL}/status" | jq '.'
echo -e "\n"

echo -e "3. Testing log creation:"
for i in {1..3}; do
    echo "Creating log entry $i..."
    curl -s -X POST -H "Content-Type: application/json" \
        -d "{\"message\":\"test log $i\"}" \
        "${SERVICE_URL}/log" | jq '.'
    sleep 1
done
echo -e "\n"

echo -e "4. Testing logs retrieval:"
curl -s "${SERVICE_URL}/logs" | jq '.'
echo -e "\n"

echo -e "5. Checking log agent:"
kubectl logs -l app=log-agent --tail=5
echo -e "\n"

echo -e "6. Checking cronjob status:"
kubectl get cronjob log-archiver
echo -e "\n"

echo -e "7. Checking manual cronjob logs:"

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

echo "Testing completed!" 