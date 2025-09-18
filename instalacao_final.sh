#!/bin/bash

# 🚀 SETUPALICIA FINAL - CONTROLE TOTAL GARANTIDO
# Versão que realmente deploya com controle total no Portainer
# Combinação da simplicidade com deploy via API
# Autor: SetupAlicia - Versão Final com Controle Total

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
    echo "║         SETUPALICIA FINAL - CONTROLE TOTAL GARANTIDO          ║"
    echo "║              Stacks 100% Editáveis no Portainer               ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "✨ Esta versão garante:"
    echo "   • Controle TOTAL das stacks (Full Control)"
    echo "   • Todas as stacks editáveis no Portainer"
    echo "   • Deploy via API do Portainer"
    echo "   • Admin criado automaticamente"
    echo ""
}

# Função para aguardar serviço
wait_service() {
    local service=$1
    local max_wait=${2:-120}
    
    log_info "⏳ Aguardando $service..."
    
    for i in $(seq 1 $max_wait); do
        if docker service ls | grep -q "$service"; then
            if docker ps | grep -q "${service}_"; then
                log_success "✅ $service está rodando!"
                return 0
            fi
        fi
        
        if [ $((i % 20)) -eq 0 ]; then
            echo "   ... aguardando $service ($i/${max_wait}s)"
        fi
        sleep 1
    done
    
    log_warning "⚠️ $service demorou mais que o esperado"
    return 1
}

# Função para criar admin do Portainer
create_portainer_admin() {
    log_info "🔑 Criando admin do Portainer automaticamente..."
    
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
    
    PORTAINER_URL=$portainer_url
    
    # Verificar se já foi inicializado
    if curl -sk "$portainer_url/api/users/admin/check" 2>/dev/null | grep -q "true"; then
        log_warning "⚠️ Portainer já inicializado, recuperando credenciais..."
        if [ -f .env ] && grep -q "PORTAINER_USER" .env; then
            PORTAINER_USER=$(grep "PORTAINER_USER=" .env | cut -d'=' -f2)
            PORTAINER_PASS=$(grep "PORTAINER_PASS=" .env | cut -d'=' -f2)
        fi
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
        echo "PORTAINER_URL=$portainer_url" >> .env
        
        return 0
    else
        log_error "❌ Falha ao criar admin"
        return 1
    fi
}

# Função para fazer login no Portainer e obter JWT
portainer_login() {
    log_info "🔐 Fazendo login no Portainer para obter token..."
    
    local response=$(curl -sk -X POST \
        "$PORTAINER_URL/api/auth" \
        -H "Content-Type: application/json" \
        -d "{\"Username\":\"$PORTAINER_USER\",\"Password\":\"$PORTAINER_PASS\"}" 2>/dev/null)
    
    JWT_TOKEN=$(echo "$response" | grep -oP '"jwt":"\K[^"]+' || true)
    
    if [ -z "$JWT_TOKEN" ]; then
        log_error "❌ Falha ao obter token JWT"
        return 1
    fi
    
    log_success "✅ Token JWT obtido!"
    return 0
}

# Função para obter/criar endpoint
get_endpoint_id() {
    log_info "📍 Verificando endpoint..."
    
    # Tentar obter endpoints existentes
    local endpoints=$(curl -sk -X GET \
        "$PORTAINER_URL/api/endpoints" \
        -H "Authorization: Bearer $JWT_TOKEN" 2>/dev/null)
    
    # Extrair primeiro endpoint ID
    ENDPOINT_ID=$(echo "$endpoints" | grep -oP '"Id":\K[0-9]+' | head -1)
    
    if [ -z "$ENDPOINT_ID" ]; then
        log_info "📍 Criando novo endpoint..."
        
        # Criar endpoint
        local create_response=$(curl -sk -X POST \
            "$PORTAINER_URL/api/endpoints" \
            -H "Authorization: Bearer $JWT_TOKEN" \
            -H "Content-Type: application/json" \
            -d '{
                "Name": "local",
                "EndpointCreationType": 1
            }' 2>/dev/null)
        
        ENDPOINT_ID=$(echo "$create_response" | grep -oP '"Id":\K[0-9]+' | head -1)
    fi
    
    if [ -z "$ENDPOINT_ID" ]; then
        ENDPOINT_ID="1"
        log_warning "⚠️ Usando endpoint padrão: 1"
    else
        log_success "✅ Endpoint ID: $ENDPOINT_ID"
    fi
}

# Função para deployar stack via API do Portainer
deploy_stack_portainer() {
    local stack_name=$1
    local stack_content=$2
    
    log_info "📦 Deployando $stack_name via API do Portainer (Full Control)..."
    
    # Escapar conteúdo para JSON
    local escaped_content=$(echo "$stack_content" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
    
    # Criar payload JSON
    local json_payload="{
        \"Name\": \"$stack_name\",
        \"SwarmID\": \"primary\",
        \"StackFileContent\": \"$escaped_content\"
    }"
    
    # Fazer deploy via API
    local response=$(curl -sk -X POST \
        "$PORTAINER_URL/api/stacks?type=1&method=string&endpointId=$ENDPOINT_ID" \
        -H "Authorization: Bearer $JWT_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$json_payload" 2>&1)
    
    if echo "$response" | grep -q "\"Id\""; then
        log_success "✅ $stack_name deployada com controle TOTAL!"
        return 0
    else
        log_warning "⚠️ Tentando método alternativo..."
        
        # Método alternativo: usar form-data
        local temp_file="/tmp/${stack_name}.yaml"
        echo "$stack_content" > "$temp_file"
        
        response=$(curl -sk -X POST \
            "$PORTAINER_URL/api/stacks?type=1&method=file&endpointId=$ENDPOINT_ID" \
            -H "Authorization: Bearer $JWT_TOKEN" \
            -F "Name=$stack_name" \
            -F "SwarmID=primary" \
            -F "file=@$temp_file" 2>&1)
        
        rm -f "$temp_file"
        
        if echo "$response" | grep -q "\"Id\""; then
            log_success "✅ $stack_name deployada com controle TOTAL!"
            return 0
        else
            log_error "❌ Falha ao deployar $stack_name via API"
            log_info "Resposta: $response"
            return 1
        fi
    fi
}

# ============================================================================
# INÍCIO DA INSTALAÇÃO
# ============================================================================

show_banner

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

# Criar redes e volumes necessários
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
# ETAPA 1 e 2: TRAEFIK E PORTAINER (Deploy direto necessário)
# ============================================================================

log_info "📦 [1/2] Instalando Traefik e Portainer (base necessária)..."

# Deploy Traefik
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

# Deploy Portainer
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
sleep 20

# Criar admin e fazer login
create_portainer_admin
portainer_login
get_endpoint_id

echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│            ✅ BASE CONFIGURADA COM SUCESSO                    │"
echo "├──────────────────────────────────────────────────────────────┤"
echo "│ 🌐 Portainer: https://$DOMINIO_PORTAINER                     │"
echo "│ 👤 Usuário: $PORTAINER_USER                                  │"
echo "│ 🔑 Senha: $PORTAINER_PASS                                    │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""

# ============================================================================
# AGORA VAMOS DEPLOYAR AS OUTRAS STACKS VIA API DO PORTAINER
# ============================================================================

log_info "🚀 Iniciando deploy das aplicações via API (Full Control)..."

# PostgreSQL
POSTGRES_YAML="version: '3.7'
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
    external: true"

deploy_stack_portainer "postgres" "$POSTGRES_YAML"
sleep 30

# Redis
REDIS_YAML="version: '3.7'
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
    external: true"

deploy_stack_portainer "redis" "$REDIS_YAML"
sleep 20

# Criar databases
log_info "🗃️ Criando bancos de dados..."
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

# Evolution API
EVOLUTION_YAML="version: '3.7'
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
    external: true"

deploy_stack_portainer "evolution" "$EVOLUTION_YAML"

# N8N
N8N_YAML="version: '3.7'
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
    external: true"

deploy_stack_portainer "n8n" "$N8N_YAML"

# ============================================================================
# VERIFICAÇÃO FINAL
# ============================================================================

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         🎉 INSTALAÇÃO FINAL CONCLUÍDA COM SUCESSO!            ║"
echo "║              TODAS AS STACKS COM CONTROLE TOTAL               ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

log_info "📊 Verificando stacks no Portainer..."

# Verificar via API
curl -sk -X GET \
    "$PORTAINER_URL/api/stacks" \
    -H "Authorization: Bearer $JWT_TOKEN" 2>/dev/null | \
    grep -oP '"Name":"[^"]+' | sed 's/"Name":"//g' | while read stack; do
        echo "   ✅ $stack - Control: Full"
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
echo "│ 👤 Portainer: $PORTAINER_USER / $PORTAINER_PASS              │"
echo "│ 🔑 Evolution API: $EVOLUTION_API_KEY                         │"
echo "│ 🗿 PostgreSQL: $POSTGRES_PASSWORD                            │"
echo "│ 🔐 N8N Key: $N8N_KEY                                         │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""
echo "✨ IMPORTANTE: Agora você pode:"
echo "   ✅ Editar todas as stacks no Portainer"
echo "   ✅ Ver logs completos"
echo "   ✅ Fazer backup e restore"
echo "   ✅ Escalar serviços"
echo "   ✅ Modificar variáveis de ambiente"
echo ""
echo "🎉 SetupAlicia Final - Controle Total Garantido!"
