#!/bin/bash

# 🚀 SETUPALICIA PROFESSIONAL - CONTROLE TOTAL VIA PORTAINER
# Instalador com deploy profissional via API do Portainer
# Autor: SetupAlicia - Versão Profissional
# Versão: 2.0 - Full Control Edition

set -e

# Função para log colorido
log_info() { echo -e "\033[34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[32m[SUCESSO]\033[0m $1"; }
log_warning() { echo -e "\033[33m[AVISO]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERRO]\033[0m $1"; }

# Incluir funções do Portainer Stack Manager
source_portainer_functions() {
    if [ -f "portainer_stack_manager.sh" ]; then
        source portainer_stack_manager.sh
    else
        # Baixar se não existir
        curl -sSL https://raw.githubusercontent.com/lonardonetto/setupalicia/main/portainer_stack_manager.sh -o portainer_stack_manager.sh
        source portainer_stack_manager.sh
    fi
}

# Função aprimorada de criação de admin com retorno de credenciais
create_portainer_admin_professional() {
    log_info "🔑 Configurando conta admin do Portainer (Professional Mode)..."
    
    # Gerar credenciais seguras
    PORTAINER_ADMIN_USER="admin"
    PORTAINER_ADMIN_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)
    
    # Aguardar Portainer estar acessível
    local max_attempts=30
    local attempt=0
    local portainer_url=""
    
    while [ $attempt -lt $max_attempts ]; do
        # Tentar HTTPS primeiro
        if curl -s "https://$DOMINIO_PORTAINER/api/status" --insecure --max-time 5 >/dev/null 2>&1; then
            portainer_url="https://$DOMINIO_PORTAINER"
            PORTAINER_URL_FINAL=$portainer_url
            log_success "✅ Portainer acessível via HTTPS!"
            break
        fi
        
        # Tentar HTTP caso SSL ainda não esteja pronto
        if curl -s "http://$DOMINIO_PORTAINER/api/status" --max-time 5 >/dev/null 2>&1; then
            portainer_url="http://$DOMINIO_PORTAINER"
            PORTAINER_URL_FINAL=$portainer_url
            log_warning "⚠️ Portainer acessível via HTTP (SSL pendente)"
            break
        fi
        
        # Tentar via IP direto
        local portainer_container=$(docker ps --filter "name=portainer_portainer" --format "{{.Names}}" | head -1)
        if [ ! -z "$portainer_container" ]; then
            local container_ip=$(docker inspect $portainer_container --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' | head -1)
            if [ ! -z "$container_ip" ] && curl -s "http://$container_ip:9000/api/status" --max-time 5 >/dev/null 2>&1; then
                portainer_url="http://$container_ip:9000"
                PORTAINER_URL_FINAL="https://$DOMINIO_PORTAINER"  # URL final será HTTPS
                log_info "📡 Usando IP interno temporariamente: $container_ip"
                break
            fi
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 2
    done
    
    if [ -z "$portainer_url" ]; then
        log_error "❌ Não foi possível acessar o Portainer"
        return 1
    fi
    
    # Verificar se já foi inicializado
    local init_check=$(curl -s "$portainer_url/api/users/admin/check" --insecure 2>/dev/null)
    
    if echo "$init_check" | grep -q "true"; then
        log_warning "⚠️ Portainer já inicializado - recuperando credenciais do .env"
        if [ -f .env ] && grep -q "PORTAINER_ADMIN_USER" .env; then
            PORTAINER_ADMIN_USER=$(grep "PORTAINER_ADMIN_USER=" .env | cut -d'=' -f2)
            PORTAINER_ADMIN_PASSWORD=$(grep "PORTAINER_ADMIN_PASSWORD=" .env | cut -d'=' -f2)
        fi
        return 0
    fi
    
    # Criar usuário admin via API
    log_info "📝 Criando usuário admin: $PORTAINER_ADMIN_USER"
    
    local response=$(curl -s -X POST \
        "$portainer_url/api/users/admin/init" \
        -H "Content-Type: application/json" \
        --insecure \
        -d "{
            \"Username\": \"$PORTAINER_ADMIN_USER\",
            \"Password\": \"$PORTAINER_ADMIN_PASSWORD\"
        }" 2>/dev/null)
    
    # Verificar sucesso
    if echo "$response" | grep -q -E "Username|jwt"; then
        log_success "✅ Conta admin criada automaticamente!"
        
        # Salvar credenciais no .env
        echo "" >> .env
        echo "# Portainer Admin (Auto-generated)" >> .env
        echo "PORTAINER_ADMIN_USER=$PORTAINER_ADMIN_USER" >> .env
        echo "PORTAINER_ADMIN_PASSWORD=$PORTAINER_ADMIN_PASSWORD" >> .env
        echo "PORTAINER_URL=$PORTAINER_URL_FINAL" >> .env
        
        return 0
    else
        log_error "❌ Falha ao criar conta admin"
        return 1
    fi
}

# Função para deployar stacks via Portainer API
deploy_all_stacks_via_portainer() {
    log_info "🚀 Iniciando deploy profissional via Portainer API..."
    
    # Fazer login no Portainer
    local JWT_TOKEN=$(portainer_login "$PORTAINER_URL_FINAL" "$PORTAINER_ADMIN_USER" "$PORTAINER_ADMIN_PASSWORD")
    if [ -z "$JWT_TOKEN" ]; then
        log_error "❌ Falha ao autenticar no Portainer"
        return 1
    fi
    
    # Obter endpoint ID
    local ENDPOINT_ID=$(get_swarm_endpoint_id "$PORTAINER_URL_FINAL" "$JWT_TOKEN")
    if [ -z "$ENDPOINT_ID" ]; then
        log_error "❌ Falha ao obter endpoint ID"
        return 1
    fi
    
    log_success "✅ Conectado ao Portainer! Deploy profissional iniciando..."
    
    # 1. Deploy PostgreSQL via Portainer
    echo ""
    echo "┌──────────────────────────────────────────────────────────────┐"
    echo "│          ETAPA 3/6 - POSTGRESQL (Via Portainer API)           │"
    echo "└──────────────────────────────────────────────────────────────┘"
    
    docker volume create postgres_data >/dev/null 2>&1
    deploy_postgres_via_portainer "$PORTAINER_URL_FINAL" "$JWT_TOKEN" "$ENDPOINT_ID" "$POSTGRES_PASSWORD"
    sleep 30  # Aguardar PostgreSQL estabilizar
    
    # 2. Deploy Redis via Portainer
    echo ""
    echo "┌──────────────────────────────────────────────────────────────┐"
    echo "│            ETAPA 4/6 - REDIS (Via Portainer API)              │"
    echo "└──────────────────────────────────────────────────────────────┘"
    
    docker volume create redis_data >/dev/null 2>&1
    deploy_redis_via_portainer "$PORTAINER_URL_FINAL" "$JWT_TOKEN" "$ENDPOINT_ID"
    sleep 20  # Aguardar Redis estabilizar
    
    # Criar bancos de dados
    log_info "🗃️ Criando bancos de dados..."
    for i in {1..30}; do
        postgres_container=$(docker ps --filter "name=postgres_postgres" --format "{{.Names}}" | head -1)
        if [ ! -z "$postgres_container" ]; then
            if docker exec $postgres_container pg_isready -U postgres >/dev/null 2>&1; then
                docker exec $postgres_container psql -U postgres -d postgres -c "CREATE DATABASE evolution;" 2>/dev/null || true
                docker exec $postgres_container psql -U postgres -d postgres -c "CREATE DATABASE n8n;" 2>/dev/null || true
                log_success "✅ Bancos de dados criados!"
                break
            fi
        fi
        echo "   Tentativa $i/30 - Aguardando PostgreSQL..."
        sleep 3
    done
    
    # 3. Deploy Evolution API via Portainer
    echo ""
    echo "┌──────────────────────────────────────────────────────────────┐"
    echo "│        ETAPA 5/6 - EVOLUTION API (Via Portainer API)          │"
    echo "└──────────────────────────────────────────────────────────────┘"
    
    docker volume create evolution_instances >/dev/null 2>&1
    docker volume create evolution_store >/dev/null 2>&1
    deploy_evolution_via_portainer "$PORTAINER_URL_FINAL" "$JWT_TOKEN" "$ENDPOINT_ID" \
        "$DOMINIO_EVOLUTION" "$EVOLUTION_API_KEY" "$POSTGRES_PASSWORD"
    
    # 4. Deploy N8N via Portainer
    echo ""
    echo "┌──────────────────────────────────────────────────────────────┐"
    echo "│             ETAPA 6/6 - N8N (Via Portainer API)               │"
    echo "└──────────────────────────────────────────────────────────────┘"
    
    docker volume create n8n_data >/dev/null 2>&1
    deploy_n8n_via_portainer "$PORTAINER_URL_FINAL" "$JWT_TOKEN" "$ENDPOINT_ID" \
        "$DOMINIO_N8N" "$WEBHOOK_N8N" "$N8N_KEY" "$POSTGRES_PASSWORD"
    
    log_success "✅ Todas as stacks deployadas com CONTROLE TOTAL!"
    
    # Salvar token para uso futuro
    echo "PORTAINER_JWT_TOKEN=$JWT_TOKEN" >> .env
    echo "PORTAINER_ENDPOINT_ID=$ENDPOINT_ID" >> .env
    
    return 0
}

# ============================================================================
# INÍCIO DA INSTALAÇÃO PROFISSIONAL
# ============================================================================

clear
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                   SETUP ALICIA PROFESSIONAL                   ║"
echo "║         Instalador com Controle Total via Portainer           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "📦 Versão 2.0 - Professional Edition"
echo "✨ Recursos exclusivos:"
echo "   • Deploy via Portainer API (controle total)"
echo "   • Criação automática de conta admin"
echo "   • Gerenciamento completo das stacks"
echo "   • SSL automático com Let's Encrypt"
echo ""

# Validação de parâmetros (igual ao original)
if [ $# -eq 0 ]; then
    read -p "📧 Digite seu email para SSL: " SSL_EMAIL
    read -p "🔄 Digite domínio N8N: " DOMINIO_N8N
    read -p "🐳 Digite domínio Portainer: " DOMINIO_PORTAINER
    read -p "🔗 Digite domínio Webhook: " WEBHOOK_N8N
    read -p "📱 Digite domínio Evolution: " DOMINIO_EVOLUTION
else
    SSL_EMAIL=$1
    DOMINIO_N8N=$2
    DOMINIO_PORTAINER=$3
    WEBHOOK_N8N=$4
    DOMINIO_EVOLUTION=$5
fi

# Incluir funções do Stack Manager
source_portainer_functions

# Gerar senhas e chaves
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-24)
N8N_KEY=$(openssl rand -hex 32)
EVOLUTION_API_KEY=$(openssl rand -hex 32)

# Salvar configuração inicial
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

# Obter IP do servidor
server_ip=$(curl -s ifconfig.me 2>/dev/null || hostname -I | cut -d' ' -f1)

# Instalar dependências
log_info "📦 Verificando dependências..."
if ! command -v docker &> /dev/null; then
    log_info "🐳 Instalando Docker..."
    curl -fsSL https://get.docker.com | bash
fi

if ! command -v jq &> /dev/null; then
    log_info "📊 Instalando jq..."
    apt-get update && apt-get install -y jq || yum install -y jq
fi

# Inicializar Docker Swarm
log_info "🐝 Inicializando Docker Swarm..."
if ! docker info | grep -q "Swarm: active"; then
    docker swarm init --advertise-addr $server_ip >/dev/null 2>&1 || true
fi

# Criar rede overlay
docker network create --driver=overlay network_public >/dev/null 2>&1 || true

# Função de aguardo (simplificada)
wait_service_ready() {
    local service_name=$1
    local max_wait=${2:-120}
    
    log_info "⏳ Aguardando $service_name..."
    for i in $(seq 1 $max_wait); do
        if docker ps --filter "name=$service_name" --format "{{.Names}}" | grep -q "$service_name"; then
            log_success "✅ $service_name está rodando!"
            return 0
        fi
        sleep 1
    done
    log_error "❌ Timeout aguardando $service_name"
    return 1
}

# ============================================================================
# ETAPA 1: TRAEFIK (Deploy direto - necessário antes do Portainer)
# ============================================================================
echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│               ETAPA 1/6 - INSTALANDO TRAEFIK                  │"
echo "└──────────────────────────────────────────────────────────────┘"
log_info "🔐 Configurando proxy SSL automático..."

cat > traefik.yaml <<EOF
version: '3.7'

services:
  traefik:
    image: traefik:v2.10
    command:
      - --api.dashboard=true
      - --api.insecure=false
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
      - --accesslog=true
      - --global.sendanonymoususage=false
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
        constraints:
          - node.role == manager
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      labels:
        - traefik.enable=true
        - traefik.http.middlewares.redirect-to-https.redirectscheme.scheme=https
        - traefik.http.middlewares.redirect-to-https.redirectscheme.permanent=true
        - traefik.http.routers.redirect-to-https.rule=hostregexp(\`{host:.+}\`)
        - traefik.http.routers.redirect-to-https.entrypoints=web
        - traefik.http.routers.redirect-to-https.middlewares=redirect-to-https
        - traefik.docker.network=network_public

volumes:
  traefik_letsencrypt:

networks:
  network_public:
    external: true
EOF

docker volume create traefik_letsencrypt >/dev/null 2>&1
docker stack deploy --prune --resolve-image always -c traefik.yaml traefik
wait_service_ready "traefik" 120

log_success "✅ Traefik instalado - Proxy SSL pronto!"

# ============================================================================
# ETAPA 2: PORTAINER (Deploy direto - necessário ter controle)
# ============================================================================
echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│              ETAPA 2/6 - INSTALANDO PORTAINER                 │"
echo "└──────────────────────────────────────────────────────────────┘"
log_info "🐳 Configurando interface de gerenciamento Docker..."

cat > portainer.yaml <<EOF
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
        constraints:
          - node.role == manager
      restart_policy:
        condition: on-failure
        delay: 10s
        max_attempts: 3
      labels:
        - traefik.enable=true
        - traefik.http.routers.portainer.rule=Host(\`$DOMINIO_PORTAINER\`)
        - traefik.http.routers.portainer.tls=true
        - traefik.http.routers.portainer.tls.certresolver=letsencryptresolver
        - traefik.http.routers.portainer.entrypoints=websecure
        - traefik.http.services.portainer.loadbalancer.server.port=9000
        - traefik.http.routers.portainer.service=portainer
        - traefik.http.routers.portainer-redirect.rule=Host(\`$DOMINIO_PORTAINER\`)
        - traefik.http.routers.portainer-redirect.entrypoints=web
        - traefik.http.routers.portainer-redirect.middlewares=redirect-to-https
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
      placement:
        constraints:
          - node.platform.os == linux

volumes:
  portainer_data:

networks:
  network_public:
    external: true
  agent_network:
    driver: overlay
    attachable: true
EOF

docker volume create portainer_data >/dev/null 2>&1
docker network create --driver=overlay agent_network >/dev/null 2>&1
docker stack deploy --prune --resolve-image always -c portainer.yaml portainer
wait_service_ready "portainer" 120

# Aguardar estabilizar
sleep 20

# Criar conta admin automaticamente
create_portainer_admin_professional

echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│           ✅ PORTAINER CONFIGURADO (PROFESSIONAL)             │"
echo "├──────────────────────────────────────────────────────────────┤"
echo "│ 🌐 URL: $PORTAINER_URL_FINAL                                  │"
echo "│ 👤 Usuário: $PORTAINER_ADMIN_USER                            │"
echo "│ 🔑 Senha: $PORTAINER_ADMIN_PASSWORD                           │"
echo "│ 📝 Credenciais salvas em .env                                │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""

# ============================================================================
# ETAPAS 3-6: DEPLOY VIA PORTAINER API (CONTROLE TOTAL)
# ============================================================================
deploy_all_stacks_via_portainer

# ============================================================================
# VERIFICAÇÃO FINAL
# ============================================================================
echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│                    VERIFICAÇÃO FINAL                          │"
echo "└──────────────────────────────────────────────────────────────┘"

log_info "📊 Verificando todos os serviços..."

# Verificar stacks no Portainer
echo ""
echo "🐳 STACKS NO PORTAINER (Controle Total):"
echo "----------------------------------------"
curl -s -X GET \
    "$PORTAINER_URL_FINAL/api/stacks" \
    -H "Authorization: Bearer $(grep PORTAINER_JWT_TOKEN .env | cut -d'=' -f2)" \
    --insecure 2>/dev/null | jq -r '.[] | "\(.Name) - Control: Full"' || echo "Use o Portainer para verificar"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║            🎉 INSTALAÇÃO PROFISSIONAL CONCLUÍDA!              ║"
echo "║                    CONTROLE TOTAL ATIVO                       ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│                    SERVIÇOS DISPONÍVEIS                       │"
echo "├──────────────────────────────────────────────────────────────┤"
echo "│ 🐳 Portainer: $PORTAINER_URL_FINAL (Full Control)            │"
echo "│ 🔄 N8N: https://$DOMINIO_N8N                                 │"
echo "│ 📱 Evolution API: https://$DOMINIO_EVOLUTION                 │"
echo "│ 🔗 Webhook N8N: https://$WEBHOOK_N8N                         │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│                     CREDENCIAIS MASTER                        │"
echo "├──────────────────────────────────────────────────────────────┤"
echo "│ 👤 Portainer Admin: $PORTAINER_ADMIN_USER                    │"
echo "│ 🔑 Portainer Senha: $PORTAINER_ADMIN_PASSWORD                │"
echo "│ 🔑 Evolution API Key: $EVOLUTION_API_KEY                     │"
echo "│ 🗿 PostgreSQL Password: $POSTGRES_PASSWORD                   │"
echo "│ 🔐 N8N Encryption Key: $N8N_KEY                              │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""
echo "✨ Vantagens da Instalação Profissional:"
echo "   ✅ Controle TOTAL das stacks no Portainer"
echo "   ✅ Possibilidade de editar configurações"
echo "   ✅ Deploy/Redeploy facilitado"
echo "   ✅ Backup e migração simplificados"
echo "   ✅ Logs centralizados no Portainer"
echo ""
echo "🎉 SetupAlicia Professional - Instalação Concluída com Sucesso!"
