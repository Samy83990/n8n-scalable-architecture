FROM n8nio/n8n:latest

ENV N8N_METRICS=true \
    N8N_DIAGNOSTICS_ENABLED=true \
    N8N_HIRING_BANNER_ENABLED=false \
    N8N_SECURE_COOKIE=false \
    N8N_INITIAL_OWNER_EMAIL=admin@example.com \
    N8N_INITIAL_OWNER_PASSWORD=AdminPassword123 \
    N8N_INITIAL_OWNER_FIRSTNAME=Admin \
    N8N_INITIAL_OWNER_LASTNAME=User

# Vérification de santé(healthcheck)
HEALTHCHECK --interval=30s --timeout=15s --retries=3 \
  CMD wget -q --spider http://localhost:5678/healthz || exit 1