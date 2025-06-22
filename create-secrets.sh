create_secrets() {
  local namespace=$1
  local suffix=$2
  
  echo "Création des secrets pour le namespace $namespace..."
  
  kubectl create namespace $namespace --dry-run=client -o yaml | kubectl apply -f -
  
  # Générer les valeurs une seule fois
  local ENCRYPTION_KEY=$(openssl rand -hex 24)
  local AUTH_PASSWORD=$(openssl rand -base64 12)
  local DB_PASSWORD=$(openssl rand -base64 16)
  
  # Secret avec préfixe pour les composants qui l'attendent
  kubectl -n $namespace create secret generic ${suffix}n8n-secrets \
    --from-literal=N8N_ENCRYPTION_KEY=${ENCRYPTION_KEY} \
    --from-literal=N8N_BASIC_AUTH_USER=admin \
    --from-literal=N8N_BASIC_AUTH_PASSWORD=${AUTH_PASSWORD} \
    --from-literal=DB_POSTGRESDB_USER=n8n \
    --from-literal=DB_POSTGRESDB_PASSWORD=${DB_PASSWORD} \
    --dry-run=client -o yaml | kubectl apply -f -
  
  # Secret sans préfixe pour PostgreSQL
  kubectl -n $namespace create secret generic n8n-secrets \
    --from-literal=N8N_ENCRYPTION_KEY=${ENCRYPTION_KEY} \
    --from-literal=N8N_BASIC_AUTH_USER=admin \
    --from-literal=N8N_BASIC_AUTH_PASSWORD=${AUTH_PASSWORD} \
    --from-literal=DB_POSTGRESDB_USER=n8n \
    --from-literal=DB_POSTGRESDB_PASSWORD=${DB_PASSWORD} \
    --dry-run=client -o yaml | kubectl apply -f -
  
  echo "Secrets créés pour $namespace"
}