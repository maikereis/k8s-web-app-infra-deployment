# Web App Infrastructure Deployment

![Kubernetes](https://img.shields.io/badge/Platform-Minikube%20%2F%20Kubernetes-326CE5?logo=kubernetes&logoColor=white)
![Python](https://img.shields.io/badge/App-FastAPI-009688?logo=fastapi&logoColor=white)
![MongoDB](https://img.shields.io/badge/Database-MongoDB-47A248?logo=mongodb&logoColor=white)
![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D?logo=argo&logoColor=white)
![Prometheus](https://img.shields.io/badge/Metrics-Prometheus-E6522C?logo=prometheus&logoColor=white)
![Grafana](https://img.shields.io/badge/Dashboards-Grafana-F46800?logo=grafana&logoColor=white)
![Helm](https://img.shields.io/badge/Packaging-Helm-0F1689?logo=helm&logoColor=white)

Full observability stack with Python FastAPI, MongoDB, Kubernetes, ArgoCD, Prometheus, and Grafana.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ GitHub (CI/CD)                                          │
│ ├── web-app (Python code)                               │
│ └── web-app-infra (K8s manifests)                       │
└─────────────────────────────────────────────────────────┘
                         │
                         │ GitOps
                         ▼
┌─────────────────────────────────────────────────────────┐
│ Minikube Cluster                                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ Namespace:   │  │ Namespace:   │  │ Namespace:   │   │
│  │ argocd       │  │ app          │  │ monitoring   │   │
│  │              │  │              │  │              │   │
│  │ • ArgoCD     │  │ • Python API │  │ • Prometheus │   │
│  └──────────────┘  │ • MongoDB    │  │ • Grafana    │   │
│                    │ • Alertmgr   │  │              │   │
│                    └──────────────┘  └──────────────┘   │
│  ┌────────────────────────────────┐                     │
│  │  Namespace:                    │                     │
│  │  argocd-image-updater-system   │                     │
│  │                                │                     │
│  │  • Image Updater               │                     │
│  └────────────────────────────────┘                     │
└─────────────────────────────────────────────────────────┘
```

## Prerequisites

- **Docker** installed and running
- **Minikube** (v1.37.0)
- **kubectl client** (v1.34.2)
- **kubectl server** (v1.34.0)
- **Kustomize** (v5.7.1)
- **Helm** (v3.19.2)
- **Git** (2.43.0)
- **GitHub Personal Access Token** with permissions:
  - `repo` (access to private repositories)
  - `read:packages` (read images from GHCR)

## Initial Setup

### 1. Start Minikube

```bash
minikube start --cpus=4 --memory=8192
```

> **Note:** The monitoring stack is resource-intensive. Minimum recommended: 4 CPUs, 8GB RAM.

### 2. Verify Cluster

```bash
kubectl get nodes
```

---

## Monitoring Stack Installation

### 1. Add Helm Repository

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### 2. Install kube-prometheus-stack

```bash
kubectl create namespace monitoring

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

### 3. Wait for Pods to Come Up

```bash
kubectl get pods -n monitoring -w
```

---

## ArgoCD Installation

```bash
export GITHUB_USER=<user>
export GITHUB_REPO_PAT=<pat>
export GITHUB_DOCKER_PAT=<pat>
```

### 1. Create Namespace and Install

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 2. Wait for Pods to Come Up

```bash
kubectl get pods -n argocd -w
```

### 3. Install ArgoCD Image Updater

```bash
kubectl apply -n argocd-image-updater-system -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/config/install.yaml
```

---

## Credentials Configuration

### 1. Create Secret for GHCR (GitHub Container Registry)

```bash
kubectl create namespace app

#kubectl delete secret ghcr-pull-secret -n app

kubectl create secret docker-registry ghcr-pull-secret \
  --namespace app \
  --docker-server=ghcr.io \
  --docker-username=${GITHUB_USER} \
  --docker-password=${GITHUB_DOCKER_PAT}

#kubectl delete secret ghcr-credentials -n argocd

# Secret for ArgoCD Image Updater
kubectl create secret generic ghcr-credentials \
  --namespace argocd \
  --from-literal=credentials="${GITHUB_USER}:${GITHUB_REPO_PAT}"

#kubectl delete secret web-app-infra-repo -n argocd

# Secret for ArgoCD to access Git repository
kubectl create secret generic web-app-infra-repo \
  --namespace argocd \
  --from-literal=type=git \
  --from-literal=url=https://github.com/${GITHUB_USER}/web-app-infra.git \
  --from-literal=username=${GITHUB_USER} \
  --from-literal=password=${GITHUB_REPO_PAT}

kubectl label secret web-app-infra-repo -n argocd argocd.argoproj.io/secret-type=repository
```

### 2. Configure ArgoCD Image Updater

```bash
kubectl apply -f argocd/image-updater/configmap.yaml
kubectl rollout restart deployment argocd-image-updater-controller -n argocd-image-updater-system
```

---

## Application Deployment via ArgoCD

### 1. Apply AppProject and Application

```bash
kubectl apply -f argocd/appproject.yaml
kubectl apply -f argocd/application.yaml
```

### 2. Verify Synchronization

```bash
kubectl get application -n argocd
```

Status should change to `Synced` and `Healthy`.

### 3. Verify Application Pods

```bash
kubectl get pods -n app -w
```

Expected pods:
- `mongo-deployment-xxx` (1 pod)
- `webapp-deployment-xxx` (3 pods)

---

## Accessing Services

### 1. Python API (via NodePort)

```bash
# Get Minikube IP
minikube ip

# Access API
curl "http://$(minikube ip):30200/health"
curl "http://$(minikube ip):30200/docs"
curl "http://$(minikube ip):30200/metrics"
```

### 2. ArgoCD UI

In a separate terminal:

```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443
```

Access: `https://localhost:8080`

**Credentials:**
- Username: `admin`
- Password:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

### 3. Grafana

```bash
export POD_NAME=$(kubectl --namespace monitoring get pod -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=prometheus" -oname)
kubectl --namespace monitoring port-forward $POD_NAME 3000
```

Access: `http://localhost:3000`

**Credentials:**
- Username: `admin`
- Password:
```bash
kubectl --namespace monitoring get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```

### 4. Prometheus (optional)

```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

Access: `http://localhost:9090`

---

## Testing the Application

### Create Users (Generate Metrics)

```bash
MINIKUBE_IP=$(minikube ip)

# Create user
curl -X POST http://$MINIKUBE_IP:30200/users \
  -H "Content-Type: application/json" \
  -d '{"name":"John","email":"john@email.com"}'

# List users
curl "http://$MINIKUBE_IP:30200/users"

# View metrics
curl "http://$MINIKUBE_IP:30200/metrics"
```

---

## Creating a Grafana Dashboard

### 1. Access Grafana

`http://localhost:3000` → Login → **Create** → **Dashboard**

### 2. Add Panels

#### Panel 1: HTTP Requests by Endpoint

**Query:**
```promql
sum by (endpoint, status) (rate(http_requests_total[5m]))
```

**Config:**
- Title: "HTTP Requests/sec"
- Type: Time series
- Unit: requests/sec

#### Panel 2: P95 Latency

**Query:**
```promql
histogram_quantile(0.95, sum by (le, endpoint) (rate(http_request_duration_seconds_bucket[5m])))
```

**Config:**
- Title: "P95 Latency"
- Type: Time series
- Unit: seconds (s)

#### Panel 3: MongoDB Operations

**Query:**
```promql
sum by (operation, status) (rate(mongodb_operations_total[5m]))
```

**Config:**
- Title: "MongoDB Operations/sec"
- Type: Time series

#### Panel 4: Total Users

**Query:**
```promql
max(active_users_total)
```

**Config:**
- Title: "Registered Users"
- Type: Stat

### 3. Save Dashboard

Click **Save dashboard** (floppy disk icon at the top).

---

## Troubleshooting

### Pods in ImagePullBackOff

**Problem:** Pod cannot pull image from GHCR.

**Solution:**
```bash
# Check if secret exists
kubectl get secret ghcr-pull-secret -n app

# Recreate secret with correct token
kubectl delete secret ghcr-pull-secret -n app
kubectl create secret docker-registry ghcr-pull-secret \
  --namespace app \
  --docker-server=ghcr.io \
  --docker-username=${GITHUB_USER} \
  --docker-password=${GITHUB_DOCKER_PAT}

# Restart deployment
kubectl rollout restart deployment webapp-deployment -n app
```

### Metrics Not Showing in Grafana

**Check ServiceMonitor:**
```bash
kubectl get servicemonitor webapp-monitor -n app
```

**Check if Prometheus discovered the target:**
- Access Prometheus: `http://localhost:9090`
- **Status → Targets**
- Search for "webapp"
- Status should be **UP**

**Check Service has a port name:**
```bash
kubectl get service webapp-service -n app -o yaml | grep "name:"
```

Should show `name: http`.

### ArgoCD Not Syncing

**Check Application:**
```bash
kubectl get application webapp -n argocd
kubectl describe application webapp -n argocd
```

**Check ArgoCD logs:**
```bash
kubectl logs -n argocd deployment/argocd-repo-server
```

**Force manual sync:**
In the ArgoCD UI, click **Sync** → **Synchronize**.

---

## Useful Commands

### View all resources

```bash
kubectl get all -n app
kubectl get all -n argocd
kubectl get all -n monitoring
```

### Application logs

```bash
kubectl logs -n app -l app=webapp -f
kubectl logs -n app -l app=mongo -f
```

### Delete everything and start over

```bash
kubectl delete namespace app
kubectl delete namespace argocd
kubectl delete namespace monitoring
```

### Stop Minikube

```bash
minikube stop
```

### Delete cluster

```bash
minikube delete
```

---

## Repository Structure

```
web-app-infra/
├── README.md
├── .gitignore
├── app/
│   └── base/
│       ├── mongo/
│       │   ├── configmap.yaml
│       │   ├── deployment.yaml
│       │   ├── secret.yaml
│       │   └── service.yaml
│       ├── webapp/
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   └── servicemonitor.yaml
│       └── kustomization.yaml
├── argocd/
│   ├── application.yaml
│   ├── appproject.yaml
│   └── image-updater/
│       └── configmap.yaml
└── terraform/
    └── (AWS infrastructure — not used with Minikube)
```

---

## Tearing Everything Down

### Delete namespaces (removes everything inside them)
```bash
kubectl delete namespace app
kubectl delete namespace argocd
kubectl delete namespace monitoring
```

### Stop Minikube
```bash
minikube stop
```

### Delete the cluster completely (start from scratch)
```bash
minikube delete
```

---

## Useful Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
