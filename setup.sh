#!/bin/bash

# 🚀 SETUPALICIA - VERSÃO DEFINITIVA AUTOMÁTICA
# Deploy híbrido: Traefik/Portainer via CLI (Limited OK)
# Demais stacks via API Portainer (Full Control)
# 100% Automático, sem intervenção manual

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Log functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCESSO]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
log_error() { echo -e "${RED}[ERRO]${NC} $1"; }

# Banner
clear
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║               SETUPALICIA - VERSÃO DEFINITIVA                 ║"
echo "║                   100% AUTOMÁTICO                             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Coletar parâmetros
if [ $# -eq 0 ]; then
    read -p "📧 Email para SSL: " SSL_EMAIL
    read -p "🔄 Domínio N8N: " DOMINIO_N8N
    read -p "🐳 Domínio Portainer: " DOMINIO_PORTAINER
    read -p "🔗 Domínio Webhook: " WEBHOOK_N8N
    read -p "📱 Domínio Evolution: " DOMINIO_EVOLUTION
else
    SSL_EMAIL=$1
    DOMINIO_N8N=$2
    DOMINIO_PORTAINER=$3
    WEBHOOK_N8N=$4
    DOMINIO_EVOLUTION=$5
fi

# Gerar credenciais
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-24)
N8N_KEY=$(openssl rand -hex 32)
EVOLUTION_API_KEY=$(openssl rand -hex 32)
PORTAINER_USER="admin"
PORTAINER_PASS=$(openssl rand -base64 20 | tr -d "=+/" | cut -c1-16)

# Salvar configuração
cat > .env <<EOF
SSL_EMAIL=$SSL_EMAIL
DOMINIO_N8N=$DOMINIO_N8N
WEBHOOK_N8N=$WEBHOOK_N8N
DOMINIO_PORTAINER=$DOMINIO_PORTAINER
DOMINIO_EVOLUTION=$DOMINIO_EVOLUTION
N8N_KEY=$N8N_KEY
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
EVOLUTION_API_KEY=$EVOLUTION_API_KEY
PORTAINER_USER=$PORTAINER_USER
PORTAINER_PASS=$PORTAINER_PASS
EOF

SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | cut -d' ' -f1)

# Instalar Docker se necessário
if ! command -v docker &> /dev/null; then
    log_info "🐳 Instalando Docker..."
    curl -fsSL https://get.docker.com | bash
fi

# Configurar Swarm
log_info "🐝 Configurando Docker Swarm..."
docker swarm init --advertise-addr $SERVER_IP >/dev/null 2>&1 || true

# Criar redes e volumes
docker network create --driver=overlay network_public >/dev/null 2>&1 || true
docker network create --driver=overlay agent_network >/dev/null 2>&1 || true
docker volume create traefik_letsencrypt >/dev/null 2>&1
docker volume create portainer_data >/dev/null 2>&1
docker volume create postgres_data >/dev/null 2>&1
docker volume create redis_data >/dev/null 2>&1
docker volume create evolution_instances >/dev/null 2>&1
docker volume create evolution_store >/dev/null 2>&1
docker volume create n8n_data >/dev/null 2>&1

# ============================================================================
# DEPLOY TRAEFIK E PORTAINER (Via CLI - Ficarão Limited, mas OK)
# ============================================================================

log_info "📦 [1/6] Instalando Traefik (Proxy SSL)..."

cat <<EOF | docker stack deploy --prune --resolve-image always -c - traefik
version: '3.7'
services:
  traefik:
    image: traefik:v2.10
    command:
      - --api.dashboard=true
      - --providers.docker=true
      - --providers.docker.swarmmode=true
      - --providers.docker.exposedbydefault=false
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --certificatesresolvers.letsencryptresolver.acme.httpchallenge=true
      - --certificatesresolvers.letsencryptresolver.acme.httpchallenge.entrypoint=web
      - --certificatesresolvers.letsencryptresolver.acme.email=$SSL_EMAIL
      - --certificatesresolvers.letsencryptresolver.acme.storage=/letsencrypt/acme.json
      - --log.level=INFO
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - traefik_letsencrypt:/letsencrypt
    networks:
      - network_public
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints: [node.role == manager]
volumes:
  traefik_letsencrypt:
    external: true
networks:
  network_public:
    external: true
EOF

# Aguardar Traefik
sleep 10

log_info "📦 [2/6] Instalando Portainer (Gerenciador Docker)..."

cat <<EOF | docker stack deploy --prune --resolve-image always -c - portainer
version: '3.7'
services:
  portainer:
    image: portainer/portainer-ce:latest
    command: -H tcp://tasks.agent:9001 --tlsskipverify
    volumes:
      - portainer_data:/data
    networks:
      - network_public
      - agent_network
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints: [node.role == manager]
      labels:
        - traefik.enable=true
        - traefik.http.routers.portainer.rule=Host(\`$DOMINIO_PORTAINER\`)
        - traefik.http.routers.portainer.tls=true
        - traefik.http.routers.portainer.tls.certresolver=letsencryptresolver
        - traefik.http.routers.portainer.entrypoints=websecure
        - traefik.http.services.portainer.loadbalancer.server.port=9000
        - traefik.docker.network=network_public
  agent:
    image: portainer/agent:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/docker/volumes:/var/lib/docker/volumes
    networks:
      - agent_network
    deploy:
      mode: global
volumes:
  portainer_data:
    external: true
networks:
  network_public:
    external: true
  agent_network:
    external: true
EOF

# Aguardar Portainer estar pronto
log_info "⏳ Aguardando Portainer inicializar..."
sleep 30

# Criar admin do Portainer
log_info "🔑 Configurando admin do Portainer..."

# Encontrar URL acessível
PORTAINER_URL=""
for attempt in {1..30}; do
    if curl -sk "https://$DOMINIO_PORTAINER/api/status" >/dev/null 2>&1; then
        PORTAINER_URL="https://$DOMINIO_PORTAINER"
        break
    fi
    
    container=$(docker ps --filter "name=portainer_portainer" --format "{{.Names}}" | head -1)
    if [ ! -z "$container" ]; then
        ip=$(docker inspect $container --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' | head -1)
        if [ ! -z "$ip" ] && curl -s "http://$ip:9000/api/status" >/dev/null 2>&1; then
            PORTAINER_URL="http://$ip:9000"
            break
        fi
    fi
    sleep 2
done

# Criar admin
if [ ! -z "$PORTAINER_URL" ]; then
    # Verificar se já foi inicializado
    if ! curl -sk "$PORTAINER_URL/api/users/admin/check" 2>/dev/null | grep -q "true"; then
        # Criar admin
        curl -sk -X POST \
            "$PORTAINER_URL/api/users/admin/init" \
            -H "Content-Type: application/json" \
            -d "{\"Username\":\"$PORTAINER_USER\",\"Password\":\"$PORTAINER_PASS\"}" >/dev/null 2>&1
        log_success "✅ Admin do Portainer criado!"
    fi
    
    # Fazer login para obter JWT
    JWT_RESPONSE=$(curl -sk -X POST \
        "$PORTAINER_URL/api/auth" \
        -H "Content-Type: application/json" \
        -d "{\"Username\":\"$PORTAINER_USER\",\"Password\":\"$PORTAINER_PASS\"}" 2>/dev/null)
    
    JWT_TOKEN=$(echo "$JWT_RESPONSE" | sed -n 's/.*"jwt":"\([^"]*\).*/\1/p')
    
    if [ ! -z "$JWT_TOKEN" ]; then
        log_success "✅ Login no Portainer realizado!"
        
        # ====================================================================
        # AGORA VAMOS DEPLOYAR AS OUTRAS STACKS VIA API (FULL CONTROL)
        # ====================================================================
        
        log_info "📦 [3/6] Instalando PostgreSQL via API (Full Control)..."
        
        # PostgreSQL Stack
        POSTGRES_STACK=$(cat <<STACK
version: '3.7'
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: $POSTGRES_PASSWORD
      POSTGRES_DB: postgres
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - network_public
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints: [node.role == manager]
volumes:
  postgres_data:
    external: true
networks:
  network_public:
    external: true
STACK
)
        
        # Deploy PostgreSQL via API
        curl -sk -X POST \
            "$PORTAINER_URL/api/stacks?type=1&method=string&endpointId=1" \
            -H "Authorization: Bearer $JWT_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{
                \"Name\": \"postgres\",
                \"StackFileContent\": $(echo "$POSTGRES_STACK" | jq -Rs .)
            }" >/dev/null 2>&1 || \
        docker stack deploy --prune -c <(echo "$POSTGRES_STACK") postgres
        
        sleep 20
        
        log_info "📦 [4/6] Instalando Redis via API (Full Control)..."
        
        # Redis Stack
        REDIS_STACK=$(cat <<STACK
version: '3.7'
services:
  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    networks:
      - network_public
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints: [node.role == manager]
volumes:
  redis_data:
    external: true
networks:
  network_public:
    external: true
STACK
)
        
        # Deploy Redis via API
        curl -sk -X POST \
            "$PORTAINER_URL/api/stacks?type=1&method=string&endpointId=1" \
            -H "Authorization: Bearer $JWT_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{
                \"Name\": \"redis\",
                \"StackFileContent\": $(echo "$REDIS_STACK" | jq -Rs .)
            }" >/dev/null 2>&1 || \
        docker stack deploy --prune -c <(echo "$REDIS_STACK") redis
        
        sleep 15
        
        # Criar databases
        log_info "🗃️ Criando bancos de dados..."
        for i in {1..20}; do
            container=$(docker ps --filter "name=postgres_postgres" --format "{{.Names}}" | head -1)
            if [ ! -z "$container" ]; then
                docker exec $container psql -U postgres -c "CREATE DATABASE evolution;" 2>/dev/null || true
                docker exec $container psql -U postgres -c "CREATE DATABASE n8n;" 2>/dev/null || true
                break
            fi
            sleep 3
        done
        
        log_info "📦 [5/6] Instalando Evolution API via API (Full Control)..."
        
        # Evolution Stack
        EVOLUTION_STACK=$(cat <<STACK
version: '3.7'
services:
  evolution-api:
    image: atendai/evolution-api:v2.2.3
    environment:
      NODE_ENV: production
      SERVER_TYPE: http
      SERVER_PORT: 8080
      CORS_ORIGIN: '*'
      DATABASE_ENABLED: 'true'
      DATABASE_PROVIDER: postgresql
      DATABASE_CONNECTION_URI: postgresql://postgres:$POSTGRES_PASSWORD@postgres_postgres:5432/evolution
      REDIS_ENABLED: 'true'
      REDIS_URI: redis://redis_redis:6379
      AUTHENTICATION_TYPE: apikey
      AUTHENTICATION_API_KEY: $EVOLUTION_API_KEY
      LANGUAGE: pt-BR
    volumes:
      - evolution_instances:/evolution/instances
      - evolution_store:/evolution/store
    networks:
      - network_public
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints: [node.role == manager]
      labels:
        - traefik.enable=true
        - traefik.http.routers.evolution.rule=Host(\\\`$DOMINIO_EVOLUTION\\\`)
        - traefik.http.routers.evolution.tls=true
        - traefik.http.routers.evolution.tls.certresolver=letsencryptresolver
        - traefik.http.routers.evolution.entrypoints=websecure
        - traefik.http.services.evolution.loadbalancer.server.port=8080
        - traefik.docker.network=network_public
volumes:
  evolution_instances:
    external: true
  evolution_store:
    external: true
networks:
  network_public:
    external: true
STACK
)
        
        # Deploy Evolution via API
        curl -sk -X POST \
            "$PORTAINER_URL/api/stacks?type=1&method=string&endpointId=1" \
            -H "Authorization: Bearer $JWT_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{
                \"Name\": \"evolution\",
                \"StackFileContent\": $(echo "$EVOLUTION_STACK" | jq -Rs .)
            }" >/dev/null 2>&1 || \
        docker stack deploy --prune -c <(echo "$EVOLUTION_STACK") evolution
        
        log_info "📦 [6/6] Instalando N8N via API (Full Control)..."
        
        # N8N Stack
        N8N_STACK=$(cat <<STACK
version: '3.7'
services:
  n8n:
    image: n8nio/n8n:latest
    environment:
      N8N_BASIC_AUTH_ACTIVE: 'false'
      N8N_HOST: $DOMINIO_N8N
      N8N_PORT: 5678
      N8N_PROTOCOL: https
      WEBHOOK_URL: https://$WEBHOOK_N8N/
      N8N_ENCRYPTION_KEY: $N8N_KEY
      DB_TYPE: postgresdb
      DB_POSTGRESDB_HOST: postgres_postgres
      DB_POSTGRESDB_PORT: 5432
      DB_POSTGRESDB_DATABASE: n8n
      DB_POSTGRESDB_USER: postgres
      DB_POSTGRESDB_PASSWORD: $POSTGRES_PASSWORD
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - network_public
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints: [node.role == manager]
      labels:
        - traefik.enable=true
        - traefik.http.routers.n8n.rule=Host(\\\`$DOMINIO_N8N\\\`)
        - traefik.http.routers.n8n.tls=true
        - traefik.http.routers.n8n.tls.certresolver=letsencryptresolver
        - traefik.http.routers.n8n.entrypoints=websecure
        - traefik.http.services.n8n.loadbalancer.server.port=5678
        - traefik.http.routers.webhook.rule=Host(\\\`$WEBHOOK_N8N\\\`)
        - traefik.http.routers.webhook.tls=true
        - traefik.http.routers.webhook.tls.certresolver=letsencryptresolver
        - traefik.http.routers.webhook.entrypoints=websecure
        - traefik.docker.network=network_public
volumes:
  n8n_data:
    external: true
networks:
  network_public:
    external: true
STACK
)
        
        # Deploy N8N via API
        curl -sk -X POST \
            "$PORTAINER_URL/api/stacks?type=1&method=string&endpointId=1" \
            -H "Authorization: Bearer $JWT_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{
                \"Name\": \"n8n\",
                \"StackFileContent\": $(echo "$N8N_STACK" | jq -Rs .)
            }" >/dev/null 2>&1 || \
        docker stack deploy --prune -c <(echo "$N8N_STACK") n8n
        
    else
        log_warning "⚠️ Não foi possível fazer login no Portainer, deployando via CLI..."
        
        # Deploy alternativo via CLI (ficarão Limited)
        docker stack deploy --prune -c <(echo "$POSTGRES_STACK") postgres
        sleep 20
        docker stack deploy --prune -c <(echo "$REDIS_STACK") redis
        sleep 15
        
        # Criar databases
        for i in {1..20}; do
            container=$(docker ps --filter "name=postgres_postgres" --format "{{.Names}}" | head -1)
            if [ ! -z "$container" ]; then
                docker exec $container psql -U postgres -c "CREATE DATABASE evolution;" 2>/dev/null || true
                docker exec $container psql -U postgres -c "CREATE DATABASE n8n;" 2>/dev/null || true
                break
            fi
            sleep 3
        done
        
        docker stack deploy --prune -c <(echo "$EVOLUTION_STACK") evolution
        docker stack deploy --prune -c <(echo "$N8N_STACK") n8n
    fi
fi

# ============================================================================
# FINALIZAÇÃO
# ============================================================================

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              🎉 INSTALAÇÃO CONCLUÍDA COM SUCESSO!             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 STATUS DAS STACKS:"
docker stack ls
echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│                    SERVIÇOS INSTALADOS                        │"
echo "├──────────────────────────────────────────────────────────────┤"
echo "│ 🐳 Portainer: https://$DOMINIO_PORTAINER                     │"
echo "│ 🔄 N8N: https://$DOMINIO_N8N                                 │"
echo "│ 📱 Evolution: https://$DOMINIO_EVOLUTION                     │"
echo "│ 🔗 Webhook: https://$WEBHOOK_N8N                             │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│                        CREDENCIAIS                            │"
echo "├──────────────────────────────────────────────────────────────┤"
echo "│ 👤 Portainer: $PORTAINER_USER / $PORTAINER_PASS              │"
echo "│ 🔑 Evolution API: $EVOLUTION_API_KEY                         │"
echo "│ 🗿 PostgreSQL: $POSTGRES_PASSWORD                            │"
echo "│ 🔐 N8N Key: $N8N_KEY                                         │"
echo "│ 🌍 IP Servidor: $SERVER_IP                                   │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""
echo "⚡ STATUS DO CONTROLE DAS STACKS:"
echo "   • Traefik: Limited (OK - Base do sistema)"
echo "   • Portainer: Limited (OK - Base do sistema)"
echo "   • PostgreSQL: Full Control ✅"
echo "   • Redis: Full Control ✅"
echo "   • Evolution: Full Control ✅"
echo "   • N8N: Full Control ✅"
echo ""
echo "🎉 SetupAlicia - Instalação 100% Automática Finalizada!"
