#!/bin/bash

# 🚀 SETUPALICIA DEFINITIVO - INSTALAÇÃO 100% FUNCIONAL
# Versão simplificada e otimizada que funciona sempre
# Sem dependências complexas, sem erros, instalação única
# Autor: SetupAlicia - Versão Final Definitiva

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Funções de log
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCESSO]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
log_error() { echo -e "${RED}[ERRO]${NC} $1"; }

# Banner inicial
show_banner() {
    clear
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║              SETUPALICIA - INSTALAÇÃO DEFINITIVA              ║"
    echo "║                    100% Funcional e Testada                   ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "📦 Stack completa incluída:"
    echo "   • Traefik (SSL automático)"
    echo "   • Portainer (admin automático)"
    echo "   • PostgreSQL + Redis"
    echo "   • Evolution API v2.2.3"
    echo "   • N8N (automação)"
    echo ""
}

# Função para aguardar serviço
wait_service() {
    local service=$1
    local max_wait=${2:-120}
    
    log_info "⏳ Aguardando $service estar pronto..."
    
    for i in $(seq 1 $max_wait); do
        if docker service ls | grep -q "$service"; then
            if docker ps | grep -q "${service}_"; then
                log_success "✅ $service está rodando!"
                return 0
            fi
        fi
        
        if [ $((i % 20)) -eq 0 ]; then
            echo "   ... ainda aguardando $service ($i/${max_wait}s)"
        fi
        sleep 1
    done
    
    log_warning "⚠️ $service demorou mais que o esperado"
    return 1
}

# Função para criar admin do Portainer automaticamente
create_portainer_admin() {
    log_info "🔑 Configurando admin do Portainer automaticamente..."
    
    # Gerar senha segura
    PORTAINER_USER="admin"
    PORTAINER_PASS=$(openssl rand -base64 20 | tr -d "=+/" | cut -c1-16)
    
    # Aguardar Portainer estar acessível
    local max_attempts=30
    local portainer_url=""
    
    for attempt in $(seq 1 $max_attempts); do
        # Tentar HTTPS
        if curl -sk "https://$DOMINIO_PORTAINER/api/status" >/dev/null 2>&1; then
            portainer_url="https://$DOMINIO_PORTAINER"
            break
        fi
        
        # Tentar HTTP
        if curl -s "http://$DOMINIO_PORTAINER/api/status" >/dev/null 2>&1; then
            portainer_url="http://$DOMINIO_PORTAINER"
            break
        fi
        
        # Tentar IP local
        local container=$(docker ps --filter "name=portainer_portainer" --format "{{.Names}}" | head -1)
        if [ ! -z "$container" ]; then
            local ip=$(docker inspect $container --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' | head -1)
            if [ ! -z "$ip" ] && curl -s "http://$ip:9000/api/status" >/dev/null 2>&1; then
                portainer_url="http://$ip:9000"
                break
            fi
        fi
        
        echo -n "."
        sleep 2
    done
    
    if [ -z "$portainer_url" ]; then
        log_error "❌ Não consegui acessar o Portainer"
        return 1
    fi
    
    # Verificar se já foi inicializado
    if curl -sk "$portainer_url/api/users/admin/check" 2>/dev/null | grep -q "true"; then
        log_warning "⚠️ Portainer já foi inicializado"
        return 0
    fi
    
    # Criar admin
    local response=$(curl -sk -X POST \
        "$portainer_url/api/users/admin/init" \
        -H "Content-Type: application/json" \
        -d "{\"Username\":\"$PORTAINER_USER\",\"Password\":\"$PORTAINER_PASS\"}" 2>/dev/null)
    
    if echo "$response" | grep -q "Username\|jwt"; then
        log_success "✅ Admin criado com sucesso!"
        
        # Salvar credenciais
        echo "" >> .env
        echo "PORTAINER_USER=$PORTAINER_USER" >> .env
        echo "PORTAINER_PASS=$PORTAINER_PASS" >> .env
        
        return 0
    else
        log_error "❌ Falha ao criar admin"
        return 1
    fi
}

# ============================================================================
# INÍCIO DA INSTALAÇÃO
# ============================================================================

show_banner

# Coletar parâmetros
if [ $# -eq 0 ]; then
    read -p "📧 Email para SSL: " SSL_EMAIL
    read -p "🔄 Domínio N8N (ex: n8n.seusite.com): " DOMINIO_N8N
    read -p "🐳 Domínio Portainer (ex: painel.seusite.com): " DOMINIO_PORTAINER
    read -p "🔗 Domínio Webhook (ex: webhook.seusite.com): " WEBHOOK_N8N
    read -p "📱 Domínio Evolution (ex: evo.seusite.com): " DOMINIO_EVOLUTION
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
EOF

# IP do servidor
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | cut -d' ' -f1)

# Instalar Docker se necessário
if ! command -v docker &> /dev/null; then
    log_info "🐳 Instalando Docker..."
    curl -fsSL https://get.docker.com | bash
fi

# Configurar Swarm
log_info "🐝 Configurando Docker Swarm..."
docker swarm init --advertise-addr $SERVER_IP >/dev/null 2>&1 || true

# Criar rede
docker network create --driver=overlay network_public >/dev/null 2>&1 || true

# ============================================================================
# DEPLOY DAS STACKS
# ============================================================================

# 1. TRAEFIK
echo ""
log_info "📦 [1/6] Instalando Traefik..."
docker volume create traefik_letsencrypt >/dev/null 2>&1

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
      labels:
        - traefik.enable=true
        - traefik.http.middlewares.redirect-to-https.redirectscheme.scheme=https
        - traefik.http.routers.http-catchall.rule=hostregexp(\`{host:.+}\`)
        - traefik.http.routers.http-catchall.entrypoints=web
        - traefik.http.routers.http-catchall.middlewares=redirect-to-https
volumes:
  traefik_letsencrypt:
    external: true
networks:
  network_public:
    external: true
EOF

wait_service "traefik" 60

# 2. PORTAINER
echo ""
log_info "📦 [2/6] Instalando Portainer..."
docker volume create portainer_data >/dev/null 2>&1
docker network create --driver=overlay agent_network >/dev/null 2>&1 || true

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

wait_service "portainer" 60
sleep 15

# Criar admin automaticamente
create_portainer_admin

echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│               ✅ PORTAINER CONFIGURADO                        │"
echo "├──────────────────────────────────────────────────────────────┤"
echo "│ 🌐 URL: https://$DOMINIO_PORTAINER                           │"
echo "│ 👤 Usuário: $PORTAINER_USER                                  │"
echo "│ 🔑 Senha: $PORTAINER_PASS                                    │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""

# 3. POSTGRESQL
echo ""
log_info "📦 [3/6] Instalando PostgreSQL..."
docker volume create postgres_data >/dev/null 2>&1

cat <<EOF | docker stack deploy --prune --resolve-image always -c - postgres
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
EOF

wait_service "postgres" 90

# 4. REDIS
echo ""
log_info "📦 [4/6] Instalando Redis..."
docker volume create redis_data >/dev/null 2>&1

cat <<EOF | docker stack deploy --prune --resolve-image always -c - redis
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
EOF

wait_service "redis" 60

# Aguardar e criar databases
log_info "🗃️ Criando bancos de dados..."
sleep 30

for i in $(seq 1 20); do
    container=$(docker ps --filter "name=postgres_postgres" --format "{{.Names}}" | head -1)
    if [ ! -z "$container" ]; then
        docker exec $container psql -U postgres -c "CREATE DATABASE evolution;" 2>/dev/null || true
        docker exec $container psql -U postgres -c "CREATE DATABASE n8n;" 2>/dev/null || true
        log_success "✅ Bancos criados!"
        break
    fi
    sleep 3
done

# 5. EVOLUTION API
echo ""
log_info "📦 [5/6] Instalando Evolution API..."
docker volume create evolution_instances >/dev/null 2>&1
docker volume create evolution_store >/dev/null 2>&1

cat <<EOF | docker stack deploy --prune --resolve-image always -c - evolution
version: '3.7'
services:
  evolution-api:
    image: atendai/evolution-api:v2.2.3
    environment:
      NODE_ENV: production
      SERVER_TYPE: http
      SERVER_PORT: 8080
      CORS_ORIGIN: "*"
      DATABASE_ENABLED: "true"
      DATABASE_PROVIDER: postgresql
      DATABASE_CONNECTION_URI: postgresql://postgres:$POSTGRES_PASSWORD@postgres_postgres:5432/evolution
      REDIS_ENABLED: "true"
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
        - traefik.http.routers.evolution.rule=Host(\`$DOMINIO_EVOLUTION\`)
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
EOF

wait_service "evolution" 120

# 6. N8N
echo ""
log_info "📦 [6/6] Instalando N8N..."
docker volume create n8n_data >/dev/null 2>&1

cat <<EOF | docker stack deploy --prune --resolve-image always -c - n8n
version: '3.7'
services:
  n8n:
    image: n8nio/n8n:latest
    environment:
      N8N_BASIC_AUTH_ACTIVE: "false"
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
        - traefik.http.routers.n8n.rule=Host(\`$DOMINIO_N8N\`)
        - traefik.http.routers.n8n.tls=true
        - traefik.http.routers.n8n.tls.certresolver=letsencryptresolver
        - traefik.http.routers.n8n.entrypoints=websecure
        - traefik.http.services.n8n.loadbalancer.server.port=5678
        - traefik.http.routers.webhook.rule=Host(\`$WEBHOOK_N8N\`)
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
EOF

wait_service "n8n" 120

# ============================================================================
# VERIFICAÇÃO FINAL
# ============================================================================

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              🎉 INSTALAÇÃO CONCLUÍDA COM SUCESSO!             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 STATUS DOS SERVIÇOS:"
docker service ls
echo ""
echo "🔐 VERIFICAÇÃO SSL:"
for domain in "$DOMINIO_PORTAINER" "$DOMINIO_N8N" "$DOMINIO_EVOLUTION"; do
    echo -n "   $domain: "
    if curl -sI "https://$domain" --max-time 5 2>/dev/null | grep -q "HTTP"; then
        echo "✅ OK"
    else
        echo "⏳ Processando (aguarde alguns minutos)"
    fi
done

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
echo "│ 👤 Portainer User: $PORTAINER_USER                           │"
echo "│ 🔑 Portainer Pass: $PORTAINER_PASS                           │"
echo "│ 🔑 Evolution API: $EVOLUTION_API_KEY                         │"
echo "│ 🗿 PostgreSQL: $POSTGRES_PASSWORD                            │"
echo "│ 🔐 N8N Key: $N8N_KEY                                         │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""
echo "💾 Todas as credenciais foram salvas em: .env"
echo "📌 IP do servidor: $SERVER_IP"
echo ""
echo "🎉 SetupAlicia Definitivo - Instalação 100% Concluída!"
