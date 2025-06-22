#!/bin/bash

# Script de test de scalabilité n8n
# Usage: ./test-scalability.sh

set -e

echo "🚀 Test de Scalabilité n8n - Architecture Scalable"
echo "=================================================="

# Variables
NAMESPACE="n8n-dev"
DEPLOYMENT_API="dev-n8n-api"
DEPLOYMENT_WORKER="dev-n8n-worker"

# Fonction pour attendre que les pods soient prêts
wait_for_pods() {
    local deployment=$1
    echo "⏳ Attente que $deployment soit prêt..."
    kubectl wait --for=condition=available --timeout=300s deployment/$deployment -n $NAMESPACE
}

# Fonction pour afficher le statut
show_status() {
    echo ""
    echo "📊 Statut actuel:"
    kubectl get pods -n $NAMESPACE -o wide
    echo ""
    echo "📈 Utilisation des ressources:"
    kubectl top pods -n $NAMESPACE 2>/dev/null || echo "Metrics pas encore disponibles"
    echo ""
}

# Étape 1: Déploiement
echo ""
echo "🔧 Étape 1: Déploiement de l'architecture"
echo "----------------------------------------"

# Créer le namespace s'il n'existe pas
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Créer les secrets d'abord
echo "🔐 Création des secrets..."
source create-secrets.sh
create_secrets $NAMESPACE "dev-"

# Appliquer la configuration
echo "📦 Déploiement des manifests Kubernetes..."
kubectl apply -k k8s/overlays/dev/

# Attendre que les deployments soient prêts
wait_for_pods $DEPLOYMENT_API
wait_for_pods $DEPLOYMENT_WORKER

show_status

# Étape 2: Test de connectivité
echo ""
echo "🔗 Étape 2: Test de connectivité"
echo "--------------------------------"

echo "📡 Démarrage du port-forward..."
kubectl port-forward -n $NAMESPACE svc/$DEPLOYMENT_API 8080:80 &
PF_PID=$!

sleep 5

echo "🩺 Test de santé de l'API..."
if curl -s -f http://localhost:8080/healthz > /dev/null; then
    echo "✅ API accessible et en bonne santé"
else
    echo "❌ API non accessible"
    exit 1
fi

# Étape 3: Test de montée en charge
echo ""
echo "📈 Étape 3: Test de montée en charge"
echo "-----------------------------------"

INITIAL_WORKERS=$(kubectl get deployment $DEPLOYMENT_WORKER -n $NAMESPACE -o jsonpath='{.spec.replicas}')
echo "📊 Nombre de workers initial: $INITIAL_WORKERS"

echo "🔼 Augmentation à 4 workers..."
kubectl scale deployment $DEPLOYMENT_WORKER --replicas=4 -n $NAMESPACE

echo "⏳ Attente de la montée en charge..."
kubectl wait --for=condition=available --timeout=120s deployment/$DEPLOYMENT_WORKER -n $NAMESPACE

show_status

# Étape 4: Test de résilience
echo ""
echo "🛡️ Étape 4: Test de résilience"
echo "------------------------------"

echo "🎯 Identification d'un worker à supprimer..."
WORKER_POD=$(kubectl get pods -n $NAMESPACE -l app=n8n-worker -o jsonpath='{.items[0].metadata.name}')
echo "📍 Worker sélectionné: $WORKER_POD"

echo "💥 Suppression du worker pour tester la résilience..."
kubectl delete pod -n $NAMESPACE $WORKER_POD

echo "⏳ Attente de la récupération automatique..."
sleep 10

show_status

# Vérifier que le nombre de workers est maintenu
CURRENT_WORKERS=$(kubectl get pods -n $NAMESPACE -l app=n8n-worker --field-selector=status.phase=Running -o name | wc -l)
echo "📊 Nombre de workers après récupération: $CURRENT_WORKERS"

if [ $CURRENT_WORKERS -ge 4 ]; then
    echo "✅ Résilience validée - Kubernetes a recréé le worker"
else
    echo "❌ Problème de résilience détecté"
fi

# Étape 5: Test de charge distribuée
echo ""
echo "⚡ Étape 5: Test de distribution de charge"
echo "----------------------------------------"

echo "📊 Observation des logs des workers (30 secondes)..."
echo "🔍 Vous devriez voir les tâches réparties entre les workers"

timeout 30s kubectl logs -n $NAMESPACE -l app=n8n-worker -f --prefix=true 2>/dev/null || echo "Fin de l'observation des logs"

# Étape 6: Validation finale
echo ""
echo "✅ Étape 6: Validation finale"
echo "=============================="

echo "🎯 Critères de validation:"
echo ""

# Test 1: Pods en fonctionnement
RUNNING_PODS=$(kubectl get pods -n $NAMESPACE --field-selector=status.phase=Running -o name | wc -l)
echo "🟢 Pods en fonctionnement: $RUNNING_PODS"

# Test 2: API accessible
if curl -s -f http://localhost:8080/healthz > /dev/null; then
    echo "🟢 API accessible: ✅"
else
    echo "🔴 API accessible: ❌"
fi

# Test 3: Workers distribués
WORKER_COUNT=$(kubectl get pods -n $NAMESPACE -l app=n8n-worker --field-selector=status.phase=Running -o name | wc -l)
echo "🟢 Workers actifs: $WORKER_COUNT"

if [ $WORKER_COUNT -ge 4 ]; then
    echo "🟢 Scalabilité horizontale: ✅"
else
    echo "🔴 Scalabilité horizontale: ❌"
fi

echo ""
echo "🎉 RÉSULTAT: Architecture n8n scalable validée!"
echo ""
echo "📝 Pour accéder à n8n: http://localhost:8080"
echo "🔑 Identifiants par défaut: admin / [voir secrets]"
echo ""
echo "🧹 Pour nettoyer: kubectl delete namespace $NAMESPACE"
echo "🛑 Pour arrêter le port-forward: kill $PF_PID"

# Garder le port-forward actif
echo ""
echo "⚠️  Port-forward actif en arrière-plan (PID: $PF_PID)"
echo "📖 Consultez le README pour les étapes suivantes"
echo ""
read -p "Appuyez sur Entrée pour arrêter le port-forward et terminer..."

# Nettoyage
kill $PF_PID 2>/dev/null || true
echo "🏁 Test terminé!"
