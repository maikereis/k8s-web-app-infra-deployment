curl http://192.168.49.2:30200/users

curl http://192.168.49.2:30200/metrics

curl "http://$(minikube ip):30200/health"

curl -X POST "http://$(minikube ip):30200/users" \
  -H "Content-Type: application/json" \
  -d '{"name":"João","email":"joao@example.com"}'

curl "http://$(minikube ip):30200/users"

curl "http://$(minikube ip):30200/metrics" | grep -E "(http_requests|mongodb_operations|active_users)"