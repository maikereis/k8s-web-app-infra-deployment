# Web App Infrastructure - Deployment Guide

Stack completa de observabilidade com Python FastAPI, MongoDB, Kubernetes, ArgoCD, Prometheus e Grafana.

## Arquitetura

```
┌─────────────────────────────────────────────────────────┐
│ GitHub (CI/CD)                                          │
│ ├── web-app (código Python)                             │
│ └── web-app-infra (manifestos K8s)                      │
└─────────────────────────────────────────────────────────┘
                         │
                         │ GitOps
                         ▼
┌─────────────────────────────────────────────────────────┐
│ Minikube Cluster                                        │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ Namespace:   │  │ Namespace:   │  │ Namespace:   │   │
│  │ argocd       │  │ app          │  │ monitoring   │   │
│  │              │  │              │  │              │   │
│  │ • ArgoCD     │  │ • Python API │  │ • Prometheus │   │
│  │ • Image      │  │ • MongoDB    │  │ • Grafana    │   │
│  │   Updater    │  │              │  │ • Alertmgr   │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## Pré-requisitos

- **Docker** instalado e rodando
- **Minikube** (v1.37.0)
- **kubectl client** (v1.34.2)
- **kubectl server** (v1.34.0)
- **Kustomize**: (v5.7.1)
- **Helm** (v3.19.2)
- **Git** (2.43.0)
- **GitHub Personal Access Token** com permissões:
  - `repo` (acesso a repositórios privados)
  - `read:packages` (ler imagens do GHCR)

## Setup Inicial

### 1. Iniciar Minikube

```bash
minikube start --cpus=4 --memory=8192
```

> **Nota:** Stack de monitoramento consome recursos. Mínimo recomendado: 4 CPUs, 8GB RAM.

### 2. Verificar Cluster

```bash
kubectl get nodes
```
---

## Instalação do Stack de Monitoramento

### 1. Adicionar Repositório Helm

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm repo update
```

### 2. Instalar kube-prometheus-stack

```bash
kubectl create namespace monitoring

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

### 3. Aguardar Pods Subirem

```bash
kubectl get pods -n monitoring -w
```

### 4. Accessar o grafana

Access grafana
```bash
export POD_NAME=$(kubectl --namespace monitoring get pod -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=prometheus" -oname)

kubectl --namespace monitoring port-forward $POD_NAME 3000
```

#### 5. Credenciais de login

Default user: admin

Get password
```
kubectl --namespace monitoring get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```


---

## Instalação do ArgoCD

### 1. Criar Namespace e Instalar

```bash
kubectl create namespace argocd

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 2. Aguardar Pods Subirem

```bash
kubectl get pods -n argocd -w
```

### 3. Instalar ArgoCD Image Updater

```bash
kubectl apply -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/config/install.yaml # will create argocd-image-updater-system namespace
```

---

## Configuração de Credenciais


### 1. Criar Secret para GHCR (GitHub Container Registry)

**IMPORTANTE:** Substitua `${GITHUB_PAT}` pelo seu token real.

```bash
kubectl create namespace app

kubectl create secret docker-registry ghcr-pull-secret \
  --namespace app \
  --docker-server=ghcr.io \
  --docker-username=${GITHUB_USER} \
  --docker-password=${GITHUB_PAT}

# Secret para o ArgoCD Image Updater
kubectl create secret generic ghcr-credentials \
  --namespace argocd \
  --from-literal=credentials="${GITHUB_USER}:${GITHUB_PAT}"

# Secret para o ArgoCD acessar repositório Git
kubectl create secret generic web-app-infra-repo \
  --namespace argocd \
  --from-literal=type=git \
  --from-literal=url=https://${GITHUB_USER}:${GITHUB_PAT}@github.com/${GITHUB_USER}/web-app-infra.git


kubectl label secret web-app-infra-repo -n argocd argocd.argoproj.io/secret-type=repository
```

### 2. Configurar ArgoCD Image Updater

```bash
kubectl apply -f argocd/image-updater/configmap.yaml

kubectl rollout restart deployment argocd-image-updater-controller -n argocd-image-updater-system
```

---

## Deploy da Aplicação via ArgoCD

### 1. Aplicar AppProject e Application

```bash
kubectl apply -f argocd/appproject.yaml

kubectl apply -f argocd/application.yaml
```

### 2. Verificar Sincronização

```bash
kubectl get application -n argocd
```

Status deve mudar para `Synced` e `Healthy`.

### 3. Verificar Pods da Aplicação

```bash
kubectl get pods -n app -w
```

Deve mostrar:
- `mongo-deployment-xxx` (1 pod)
- `webapp-deployment-xxx` (3 pods)

---

## Acessando os Serviços

### 1. API Python (via NodePort)

```bash
# Obter IP do Minikube
minikube ip

# Acessar API
curl "http://$(minikube ip):30200/health"
curl "http://$(minikube ip):30200/docs"
curl "http://$(minikube ip):30200/metrics"
```

### 2. ArgoCD UI

Em um terminal separado:

```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443
```

Acesse: `https://localhost:8080`

**Credenciais:**
- Username: `admin`
- Password: 
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

### 3. Grafana

Em outro terminal:

```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

Acesse: `http://localhost:3000`

**Credenciais:**
- Username: `admin`


kubectl get secret --namespace monitoring -l app.kubernetes.io/component=admin-secret -o jsonpath="{.items[0].data.admin-password}" | base64 --decode ; echo


### 4. Prometheus (opcional)

```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

Acesse: `http://localhost:9090`

---

## Testando a Aplicação

### Criar Usuários (Gerar Métricas)

```bash
MINIKUBE_IP=$(minikube ip)

# Criar usuário
curl -X POST http://$MINIKUBE_IP:30200/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Fulano","email":"fulano@email.com"}'

# Listar usuários
curl "http://$MINIKUBE_IP:30200/users"

# Ver métricas
curl "http://$MINIKUBE_IP:30200/metrics"
```

---

## Criando Dashboard no Grafana

### 1. Acessar Grafana

`http://localhost:3000` → Login → **Create** → **Dashboard**

### 2. Adicionar Painéis

#### Painel 1: HTTP Requests por Endpoint

**Query:**
```promql
sum by (endpoint, status) (rate(http_requests_total[5m]))
```

**Config:**
- Title: "HTTP Requests/sec"
- Type: Time series
- Unit: requests/sec

#### Painel 2: Latência P95

**Query:**
```promql
histogram_quantile(0.95, sum by (le, endpoint) (rate(http_request_duration_seconds_bucket[5m])))
```

**Config:**
- Title: "Latência P95"
- Type: Time series
- Unit: seconds (s)

#### Painel 3: Operações MongoDB

**Query:**
```promql
sum by (operation, status) (rate(mongodb_operations_total[5m]))
```

**Config:**
- Title: "Operações MongoDB/sec"
- Type: Time series

#### Painel 4: Total de Usuários

**Query:**
```promql
max(active_users_total)
```

**Config:**
- Title: "Usuários Cadastrados"
- Type: Stat

### 3. Salvar Dashboard

Clique em **Save dashboard** (ícone de disquete no topo).

---

## Troubleshooting

### Pods em ImagePullBackOff

**Problema:** Pod não consegue baixar imagem do GHCR.

**Solução:**
```bash
# Verificar se secret existe
kubectl get secret ghcr-pull-secret -n app

# Recriar secret com token correto
kubectl delete secret ghcr-pull-secret -n app
kubectl create secret docker-registry ghcr-pull-secret \
  --namespace app \
  --docker-server=ghcr.io \
  --docker-username=maikereis \
  --docker-password=${GITHUB_PAT}

# Reiniciar deployment
kubectl rollout restart deployment webapp-deployment -n app
```

### Métricas não aparecem no Grafana

**Verificar ServiceMonitor:**
```bash
kubectl get servicemonitor webapp-monitor -n app
```

**Verificar se Prometheus descobriu o target:**
- Acessar Prometheus: `http://localhost:9090`
- **Status → Targets**
- Procurar por "webapp"
- Status deve estar **UP**

**Verificar Service tem nome de porta:**
```bash
kubectl get service webapp-service -n app -o yaml | grep "name:"
```

Deve aparecer `name: http`.

### ArgoCD não sincroniza

**Verificar Application:**
```bash
kubectl get application webapp -n argocd
kubectl describe application webapp -n argocd
```

**Verificar logs do ArgoCD:**
```bash
kubectl logs -n argocd deployment/argocd-repo-server
```

**Forçar sync manual:**
Na UI do ArgoCD, clique em **Sync** → **Synchronize**.

---

## Comandos Úteis

### Ver todos os recursos

```bash
kubectl get all -n app
kubectl get all -n argocd
kubectl get all -n monitoring
```

### Logs da aplicação

```bash
kubectl logs -n app -l app=webapp -f
kubectl logs -n app -l app=mongo -f
```

### Deletar tudo e recomeçar

```bash
kubectl delete namespace app
kubectl delete namespace argocd
kubectl delete namespace monitoring

# Depois siga o guia desde o início
```

### Parar Minikube

```bash
minikube stop
```

### Deletar cluster

```bash
minikube delete
```

---

## Estrutura do Repositório

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
    └── (infraestrutura AWS - não usado no minikube)
```

---

## Destruindo tudo

### Deletar namespaces (isso deleta tudo dentro deles)
kubectl delete namespace app
kubectl delete namespace argocd
kubectl delete namespace monitoring

### Parar o minikube
minikube stop

### Deletar o cluster completamente (começa do zero)
minikube delete

## Recursos Úteis

- [Documentação ArgoCD](https://argo-cd.readthedocs.io/)
- [Documentação Prometheus](https://prometheus.io/docs/)
- [Documentação Grafana](https://grafana.com/docs/)
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)

---