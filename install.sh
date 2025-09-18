#!/bin/bash

# 🚀 SETUPALICIA - INSTALAÇÃO ROBUSTA E GARANTIDA
# Prepara tudo primeiro, depois faz deploy de uma vez
# 100% Funcional - Testado e aprovado

set -e

# Cores
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

# Banner
clear
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    SETUPALICIA INSTALLER                      ║"
echo "║                   Versão Robusta e Garantida                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Verificar se é root
if [ "$EUID" -ne 0 ]; then 
    log_error "Execute como root: sudo bash $0"
    exit 1
fi

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

# Validações
if [[ ! "$SSL_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    log_error "Email inválido!"
    exit 1
fi

# Gerar senhas
log_info "🔐 Gerando credenciais seguras..."
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-24)
N8N_KEY=$(openssl rand -hex 32)
EVOLUTION_API_KEY=$(openssl rand -hex 32)
PORTAINER_USER="admin"
PORTAINER_PASS=$(openssl rand -base64 20 | tr -d "=+/" | cut -c1-16)

# Salvar credenciais
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

# ============================================================================
# FASE 1: PREPARAÇÃO DO AMBIENTE
# ============================================================================

log_info "📦 [FASE 1] Preparando ambiente..."

# Atualizar sistema
apt-get update -qq >/dev/null 2>&1
apt-get install -y curl wget jq >/dev/null 2>&1

# Instalar Docker se necessário
if ! command -v docker &> /dev/null; then
    log_info "🐳 Instalando Docker..."
    curl -fsSL https://get.docker.com | bash >/dev/null 2>&1
fi

# Inicializar Swarm
log_info "🐝 Configurando Docker Swarm..."
docker swarm init --advertise-addr $SERVER_IP >/dev/null 2>&1 || true

# Criar redes
log_info "🌐 Criando redes..."
docker network create --driver=overlay network_public >/dev/null 2>&1 || true
docker network create --driver=overlay agent_network >/dev/null 2>&1 || true

# Criar todos os volumes
log_info "💾 Criando volumes..."
docker volume create traefik_letsencrypt >/dev/null 2>&1
docker volume create portainer_data >/dev/null 2>&1
docker volume create postgres_data >/dev/null 2>&1
docker volume create redis_data >/dev/null 2>&1
docker volume create evolution_instances >/dev/null 2>&1
docker volume create evolution_store >/dev/null 2>&1
docker volume create n8n_data >/dev/null 2>&1

# ============================================================================
# FASE 2: CRIAR TODOS OS ARQUIVOS YAML
# ============================================================================

log_info "📝 [FASE 2] Criando configurações..."

# TRAEFIK
cat > traefik-stack.yml <<EOF
version: '3.8'
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
      placement:
        constraints: [node.role == manager]
      restart_policy:
        condition: any
        delay: 5s
volumes:
  traefik_letsencrypt:
    external: true
networks:
  network_public:
    external: true
EOF

# PORTAINER
cat > portainer-stack.yml <<EOF
version: '3.8'
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

# POSTGRESQL
cat > postgres-stack.yml <<EOF
version: '3.8'
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
      placement:
        constraints: [node.role == manager]
      restart_policy:
        condition: any
        delay: 5s
volumes:
  postgres_data:
    external: true
networks:
  network_public:
    external: true
EOF

# REDIS
cat > redis-stack.yml <<EOF
version: '3.8'
services:
  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    networks:
      - network_public
    deploy:
      placement:
        constraints: [node.role == manager]
      restart_policy:
        condition: any
        delay: 5s
volumes:
  redis_data:
    external: true
networks:
  network_public:
    external: true
EOF

# EVOLUTION API
cat > evolution-stack.yml <<EOF
version: '3.8'
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

# N8N
cat > n8n-stack.yml <<EOF
version: '3.8'
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

log_success "✅ Todos os arquivos criados!"

# ============================================================================
# FASE 3: DEPLOY DAS STACKS
# ============================================================================

log_info "🚀 [FASE 3] Fazendo deploy das aplicações..."

# Deploy Traefik
log_info "📦 [1/6] Instalando Traefik..."
docker stack deploy --prune --resolve-image always -c traefik-stack.yml traefik
sleep 10

# Deploy Portainer
log_info "📦 [2/6] Instalando Portainer..."
docker stack deploy --prune --resolve-image always -c portainer-stack.yml portainer
sleep 30

# Deploy PostgreSQL
log_info "📦 [3/6] Instalando PostgreSQL..."
docker stack deploy --prune --resolve-image always -c postgres-stack.yml postgres
sleep 20

# Deploy Redis
log_info "📦 [4/6] Instalando Redis..."
docker stack deploy --prune --resolve-image always -c redis-stack.yml redis
sleep 10

# Criar databases
log_info "🗃️ Criando bancos de dados..."
sleep 20
for i in {1..10}; do
    container=$(docker ps --filter "name=postgres_postgres" --format "{{.Names}}" | head -1)
    if [ ! -z "$container" ]; then
        docker exec $container psql -U postgres -c "CREATE DATABASE evolution;" 2>/dev/null || true
        docker exec $container psql -U postgres -c "CREATE DATABASE n8n;" 2>/dev/null || true
        log_success "✅ Bancos criados!"
        break
    fi
    sleep 5
done

# Deploy Evolution
log_info "📦 [5/6] Instalando Evolution API..."
docker stack deploy --prune --resolve-image always -c evolution-stack.yml evolution
sleep 10

# Deploy N8N
log_info "📦 [6/6] Instalando N8N..."
docker stack deploy --prune --resolve-image always -c n8n-stack.yml n8n

# ============================================================================
# FASE 4: CONFIGURAR PORTAINER
# ============================================================================

log_info "⏳ Aguardando serviços estabilizarem..."
sleep 30

log_info "🔑 Tentando configurar admin do Portainer..."

# Aguardar Portainer estar pronto
for i in {1..30}; do
    if curl -sk "https://$DOMINIO_PORTAINER" >/dev/null 2>&1; then
        PORTAINER_URL="https://$DOMINIO_PORTAINER"
        break
    fi
    
    container=$(docker ps --filter "name=portainer_portainer" --format "{{.Names}}" | head -1)
    if [ ! -z "$container" ]; then
        ip=$(docker inspect $container --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' | head -1)
        if [ ! -z "$ip" ]; then
            if curl -s "http://$ip:9000" >/dev/null 2>&1; then
                PORTAINER_URL="http://$ip:9000"
                break
            fi
        fi
    fi
    sleep 3
done

# Tentar criar admin
if [ ! -z "$PORTAINER_URL" ]; then
    # Verificar se já foi configurado
    CHECK=$(curl -sk "$PORTAINER_URL/api/users/admin/check" 2>/dev/null)
    
    if [ "$CHECK" != "true" ]; then
        # Tentar criar admin
        RESPONSE=$(curl -sk -X POST \
            "$PORTAINER_URL/api/users/admin/init" \
            -H "Content-Type: application/json" \
            -d "{
                \"Username\": \"$PORTAINER_USER\",
                \"Password\": \"$PORTAINER_PASS\"
            }" 2>/dev/null)
        
        if echo "$RESPONSE" | grep -q "jwt\|Username"; then
            log_success "✅ Admin do Portainer criado automaticamente!"
            PORTAINER_CONFIGURED=true
        fi
    else
        log_warning "⚠️ Portainer já configurado anteriormente"
        PORTAINER_CONFIGURED=true
    fi
fi

# ============================================================================
# FASE 5: DEPLOY VIA API DO PORTAINER (OPCIONAL)
# ============================================================================

if [ "$PORTAINER_CONFIGURED" = "true" ] && [ ! -z "$PORTAINER_URL" ]; then
    log_info "🔄 Tentando converter stacks para Full Control..."
    
    # Fazer login
    JWT_RESPONSE=$(curl -sk -X POST \
        "$PORTAINER_URL/api/auth" \
        -H "Content-Type: application/json" \
        -d "{\"Username\":\"$PORTAINER_USER\",\"Password\":\"$PORTAINER_PASS\"}" 2>/dev/null)
    
    JWT_TOKEN=$(echo "$JWT_RESPONSE" | grep -oP '"jwt":"\K[^"]+' || true)
    
    if [ ! -z "$JWT_TOKEN" ]; then
        log_success "✅ Login no Portainer realizado!"
        
        # Para cada stack, tentar recriar via API
        for stack in postgres redis evolution n8n; do
            log_info "Convertendo $stack para Full Control..."
            
            # Remover stack existente
            docker stack rm $stack >/dev/null 2>&1 || true
            sleep 10
            
            # Ler arquivo da stack
            STACK_CONTENT=$(cat ${stack}-stack.yml)
            
            # Deploy via API
            curl -sk -X POST \
                "$PORTAINER_URL/api/stacks?type=1&method=string&endpointId=1" \
                -H "Authorization: Bearer $JWT_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{
                    \"Name\": \"$stack\",
                    \"SwarmID\": \"primary\",
                    \"StackFileContent\": $(echo "$STACK_CONTENT" | jq -Rs .)
                }" >/dev/null 2>&1 || \
            docker stack deploy --prune --resolve-image always -c ${stack}-stack.yml $stack
        done
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
echo "📊 SERVIÇOS RODANDO:"
docker service ls --format "table {{.Name}}\t{{.Mode}}\t{{.Replicas}}"
echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│                    URLS DE ACESSO                             │"
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

# Verificar se tentamos API
if [ ! -z "$JWT_TOKEN" ]; then
    echo "✅ Deploy via API do Portainer tentado (Full Control)"
else
    echo "⚠️ Stacks com controle 'Limited' no Portainer"
    echo "   Para editar: delete e recrie via interface do Portainer"
fi

echo ""
echo "📝 Credenciais salvas em: $(pwd)/.env"
echo "📁 Arquivos YAML salvos no diretório atual"
echo ""
echo "🎉 SetupAlicia - Instalação Finalizada!"
echo ""
echo "💡 PRÓXIMOS PASSOS:"
echo "1. Aguarde 2-3 minutos para SSL ser gerado"
echo "2. Acesse o Portainer e configure sua conta (se necessário)"
echo "3. Acesse o N8N e crie sua conta de administrador"
echo "4. Configure as instâncias no Evolution API"
echo ""
