# Guide de Test de Scalabilité n8n

## 🚀 Démarrage Rapide

### Option 1: Test Automatique

```bash
./test-scalability.sh
```

## 📋 Prérequis

- Kubernetes cluster (local ou cloud)
- kubectl configuré
- Docker installé

## 🎯 Objectifs des Tests

Valider que l'architecture n8n est capable de :

1. ✅ **Distribuer la charge** entre plusieurs workers
2. ✅ **Résister aux pannes** (auto-récupération)  
3. ✅ **Monter en charge** horizontalement
4. ✅ **Maintenir les performances** sous charge

### 1. Déploiement Initial

```bash
kubectl apply -k k8s/overlays/dev/
kubectl get pods -n n8n-dev

```**Screenshot**: Terminal montrant tous les pods `Running`

### 2. Interface n8n
```bash
kubectl port-forward -n n8n-dev svc/dev-n8n-api 8080:80

```**Screenshot**: Interface n8n sur http://localhost:8080

### 3. Workflows de Test
Créer dans l'interface n8n :
- Workflow 1: Schedule (15s) + HTTP Request  
- Workflow 2: Schedule (20s) + Data Processing
- Workflow 3: Schedule (30s) + API Calls

**Screenshot**: Liste des workflows actifs

### 4. Distribution de Charge
```bash
kubectl logs -n n8n-dev -l app=n8n-worker -f --prefix=true
```

### 5. Test de Résilience

```bash
# Supprimer un worker
kubectl delete pod -n n8n-dev $(kubectl get pods -n n8n-dev -l app=n8n-worker -o name | head -1)

# Observer la récupération
kubectl get pods -n n8n-dev -w

```**Screenshot**: Avant/après suppression d'un pod

### 6. Montée en Charge

```bash
kubectl scale deployment dev-n8n-worker --replicas=5 -n n8n-dev
kubectl get pods -n n8n-dev

```**Screenshot**: Passage de 2 à 5 workers

### 7. Métriques de Performance

```bash
kubectl top pods -n n8n-dev ```
**Screenshot**: Utilisation CPU/RAM des pods

### 8. Validation Finale

Interface n8n → Executions

**Screenshot**: Historique des exécutions réussies

## 🔧 Commandes Utiles

```bash
# État des pods
kubectl get pods -n n8n-dev -o wide

# Logs en temps réel
kubectl logs -n n8n-dev -l app=n8n-worker -f

# Métriques
kubectl top pods -n n8n-dev

# Scaling
kubectl scale deployment dev-n8n-worker --replicas=X -n n8n-dev

# Nettoyage
kubectl delete namespace n8n-dev
```

## 🎯 Critères de Validation

### ✅ Test Réussi Si

- Tous les pods passent à `Running`
- API répond sur `/healthz` (200 OK)
- Workflows s'exécutent en parallèle
- Suppression d'un worker → auto-récupération
- Scaling horizontal fonctionne
- Aucune perte de données

### ❌ Test Échoué Si

- Pods en `CrashLoopBackOff`
- API inaccessible
- Workflows ne s'exécutent pas
- Pas de récupération après panne
- Performance dégradée avec plus de workers

## 🐛 Troubleshooting

### Pods qui ne démarrent pas

```bash
kubectl describe pod -n n8n-dev <pod-name>
kubectl logs -n n8n-dev <pod-name>
```

### Secrets manquants

```bash
source create-secrets.sh
create_secrets "n8n-dev" "dev-"
```

### Port-forward qui ne fonctionne pas

```bash
kubectl get svc -n n8n-dev
kubectl port-forward -n n8n-dev svc/dev-n8n-api 8080:80
```
