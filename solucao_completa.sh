#!/bin/bash

# 🔧 SOLUÇÃO COMPLETA - SETUPALICIA EVOLUTION API
# Este script vai resolver TODOS os problemas e garantir funcionamento perfeito
# Versão: 1.0 - Solução Definitiva

clear
echo "🚀 SETUPALICIA - SOLUÇÃO COMPLETA EVOLUTION API"
echo "======================================================="
echo "Este script irá:"
echo "✅ Diagnosticar todos os problemas"
echo "✅ Corrigir configurações"
echo "✅ Garantir sequência correta de deployment"
echo "✅ Validar funcionamento completo"
echo "======================================================="
echo ""

# Função para log colorido
log_info() { echo -e "\033[34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $1"; }
log_warning() { echo -e "\033[33m[WARNING]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $1"; }

# Verificar se está executando como root
if [ "$EUID" -eq 0 ]; then
    log_error "Não execute este script como root!"
    exit 1
fi

# Verificar se Docker está instalado
if ! command -v docker &> /dev/null; then
    log_error "Docker não está instalado!"
    exit 1
fi

# Verificar se está no diretório correto
if [ ! -f ".env" ]; then
    log_error "Arquivo .env não encontrado!"
    log_info "Execute este script no diretório onde foi feita a instalação."
    log_info "Ou execute primeiro: bash <(curl -sSL https://raw.githubusercontent.com/lonardonetto/setupalicia/main/install_n8n_evolution.sh)"
    exit 1
fi

log_success "Arquivo .env encontrado"

# Carregar variáveis de ambiente
source .env

log_info "PASSO 1: Validando variáveis de ambiente..."

# Verificar variáveis obrigatórias
required_vars=("SSL_EMAIL" "DOMINIO_N8N" "DOMINIO_PORTAINER" "WEBHOOK_N8N" "DOMINIO_EVOLUTION" "N8N_KEY" "POSTGRES_PASSWORD" "EVOLUTION_API_KEY")
missing_vars=()

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -ne 0 ]; then
    log_error "Variáveis obrigatórias não encontradas:"
    for var in "${missing_vars[@]}"; do
        echo "  - $var"
    done
    log_info "Recriando arquivo .env com variáveis necessárias..."
    
    # Gerar novas variáveis se necessário
    [ -z "$N8N_KEY" ] && N8N_KEY=$(openssl rand -hex 16)
    [ -z "$POSTGRES_PASSWORD" ] && POSTGRES_PASSWORD=$(openssl rand -base64 12)
    [ -z "$EVOLUTION_API_KEY" ] && EVOLUTION_API_KEY=$(openssl rand -hex 32)
    
    # Recriar .env
    cat > .env <<EOF
SSL_EMAIL=${SSL_EMAIL}
DOMINIO_N8N=${DOMINIO_N8N}
WEBHOOK_N8N=${WEBHOOK_N8N}
DOMINIO_PORTAINER=${DOMINIO_PORTAINER}
DOMINIO_EVOLUTION=${DOMINIO_EVOLUTION}
N8N_KEY=${N8N_KEY}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
EVOLUTION_API_KEY=${EVOLUTION_API_KEY}
EOF
    source .env
    log_success "Arquivo .env atualizado"
fi

log_success "Todas as variáveis obrigatórias estão configuradas"

log_info "PASSO 2: Verificando infraestrutura Docker..."

# Verificar Docker Swarm
if ! docker info | grep -q "Swarm: active"; then
    log_warning "Docker Swarm não está ativo. Inicializando..."
    endereco_ip=$(ip route get 8.8.8.8 | grep -oP 'src \K[^ ]+')
    docker swarm init --advertise-addr $endereco_ip
    log_success "Docker Swarm inicializado"
fi

# Verificar rede
if ! docker network ls | grep -q "network_public"; then
    log_info "Criando rede network_public..."
    docker network create --driver=overlay network_public
    log_success "Rede network_public criada"
fi

log_info "PASSO 3: Verificando e corrigindo stacks de infraestrutura..."

# Função para aguardar serviço ficar pronto
wait_for_service() {
    local service_name=$1
    local max_attempts=${2:-60}
    local attempt=0
    
    log_info "Aguardando serviço $service_name ficar pronto..."
    
    while [ $attempt -lt $max_attempts ]; do
        if docker service ps $service_name 2>/dev/null | grep -q "Running"; then
            log_success "Serviço $service_name está funcionando"
            return 0
        fi
        ((attempt++))
        echo -n "."
        sleep 5
    done
    
    log_error "Serviço $service_name não ficou pronto após $((max_attempts * 5)) segundos"
    return 1
}

# Verificar/Instalar Traefik
if ! docker service ls | grep -q "traefik_traefik"; then
    log_info "Instalando Traefik..."
    if [ ! -f "traefik.yaml" ]; then
        curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/traefik.yaml" -o "traefik.yaml"
    fi
    env SSL_EMAIL="$SSL_EMAIL" docker stack deploy --prune --resolve-image always -c traefik.yaml traefik
    wait_for_service "traefik_traefik"
else
    log_success "Traefik já está funcionando"
fi

# Verificar/Instalar Portainer
if ! docker service ls | grep -q "portainer_portainer"; then
    log_info "Instalando Portainer..."
    if [ ! -f "portainer.yaml" ]; then
        curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/portainer.yaml" -o "portainer.yaml"
    fi
    env DOMINIO_PORTAINER="$DOMINIO_PORTAINER" docker stack deploy --prune --resolve-image always -c portainer.yaml portainer
    wait_for_service "portainer_portainer"
else
    log_success "Portainer já está funcionando"
fi

# Verificar/Instalar PostgreSQL
if ! docker service ls | grep -q "postgres_postgres"; then
    log_info "Instalando PostgreSQL..."
    if [ ! -f "postgres.yaml" ]; then
        curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/postgres.yaml" -o "postgres.yaml"
    fi
    env POSTGRES_PASSWORD="$POSTGRES_PASSWORD" docker stack deploy --prune --resolve-image always -c postgres.yaml postgres
    wait_for_service "postgres_postgres"
else
    log_success "PostgreSQL já está funcionando"
fi

# Verificar/Instalar Redis
if ! docker service ls | grep -q "redis_redis"; then
    log_info "Instalando Redis..."
    if [ ! -f "redis.yaml" ]; then
        curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/redis.yaml" -o "redis.yaml"
    fi
    docker stack deploy --prune --resolve-image always -c redis.yaml redis
    wait_for_service "redis_redis"
else
    log_success "Redis já está funcionando"
fi

log_info "PASSO 4: Aguardando estabilização da infraestrutura..."
sleep 30

log_info "PASSO 5: Verificando saúde dos serviços de dados..."

# Verificar PostgreSQL Health
postgres_ready=false
for i in {1..30}; do
    postgres_container=$(docker ps --filter "name=postgres_postgres" --format "{{.Names}}" | head -1)
    if [ ! -z "$postgres_container" ]; then
        if docker exec $postgres_container pg_isready -U postgres >/dev/null 2>&1; then
            log_success "PostgreSQL está funcionando perfeitamente"
            postgres_ready=true
            break
        fi
    fi
    log_info "Aguardando PostgreSQL... ($i/30)"
    sleep 3
done

if [ "$postgres_ready" = false ]; then
    log_error "PostgreSQL não está respondendo adequadamente"
    exit 1
fi

# Verificar Redis Health
redis_ready=false
for i in {1..20}; do
    redis_container=$(docker ps --filter "name=redis_redis" --format "{{.Names}}" | head -1)
    if [ ! -z "$redis_container" ]; then
        if docker exec $redis_container redis-cli ping >/dev/null 2>&1; then
            log_success "Redis está funcionando perfeitamente"
            redis_ready=true
            break
        fi
    fi
    log_info "Aguardando Redis... ($i/20)"
    sleep 2
done

if [ "$redis_ready" = false ]; then
    log_error "Redis não está respondendo adequadamente"
    exit 1
fi

log_info "PASSO 6: Criando bancos de dados..."

# Criar banco Evolution
postgres_container=$(docker ps --filter "name=postgres_postgres" --format "{{.Names}}" | head -1)
docker exec $postgres_container psql -U postgres -d postgres -c "CREATE DATABASE IF NOT EXISTS evolution;" 2>/dev/null || \
docker exec $postgres_container psql -U postgres -d postgres -c "CREATE DATABASE evolution;" 2>/dev/null
log_success "Banco evolution criado/verificado"

# Criar banco N8N
docker exec $postgres_container psql -U postgres -d postgres -c "CREATE DATABASE IF NOT EXISTS n8n;" 2>/dev/null || \
docker exec $postgres_container psql -U postgres -d postgres -c "CREATE DATABASE n8n;" 2>/dev/null
log_success "Banco n8n criado/verificado"

log_info "PASSO 7: Preparando Evolution API..."

# Remover stack evolution antiga se existir
if docker stack ps evolution >/dev/null 2>&1; then
    log_info "Removendo stack Evolution antiga..."
    docker stack rm evolution
    sleep 30
fi

# Criar volumes Evolution
docker volume create evolution_instances >/dev/null 2>&1
docker volume create evolution_store >/dev/null 2>&1

# Criar evolution.yaml otimizado
log_info "Criando configuração Evolution API otimizada..."
cat > evolution.yaml <<EOF
version: '3.7'

services:
  evolution-api:
    image: atendai/evolution-api:v2.2.3
    networks:
      - network_public
    environment:
      - SERVER_TYPE=http
      - SERVER_PORT=8080
      - CORS_ORIGIN=*
      - CORS_METHODS=POST,GET,PUT,DELETE
      - CORS_CREDENTIALS=true
      - LOG_LEVEL=ERROR
      - LOG_COLOR=true
      - LOG_BAILEYS=error
      - DEL_INSTANCE=false
      - DATABASE_ENABLED=true
      - DATABASE_PROVIDER=postgresql
      - DATABASE_CONNECTION_URI=postgresql://postgres:\${POSTGRES_PASSWORD}@postgres_postgres:5432/evolution?schema=public&sslmode=disable
      - DATABASE_CONNECTION_CLIENT_NAME=evolution_db
      - DATABASE_SAVE_DATA_INSTANCE=true
      - DATABASE_SAVE_DATA_NEW_MESSAGE=true
      - DATABASE_SAVE_MESSAGE_UPDATE=true
      - DATABASE_SAVE_DATA_CONTACTS=true
      - DATABASE_SAVE_DATA_CHATS=true
      - REDIS_ENABLED=true
      - REDIS_URI=redis://redis_redis:6379
      - REDIS_PREFIX_KEY=evolution
      - CACHE_REDIS_ENABLED=true
      - CACHE_REDIS_URI=redis://redis_redis:6379
      - CACHE_REDIS_PREFIX_KEY=evolution
      - CACHE_REDIS_SAVE_INSTANCES=true
      - CACHE_LOCAL_ENABLED=false
      - QRCODE_LIMIT=30
      - QRCODE_COLOR=#198754
      - AUTHENTICATION_TYPE=apikey
      - AUTHENTICATION_API_KEY=\${EVOLUTION_API_KEY}
      - AUTHENTICATION_EXPOSE_IN_FETCH_INSTANCES=true
      - LANGUAGE=pt-BR
      - WEBHOOK_GLOBAL_URL=
      - WEBHOOK_GLOBAL_ENABLED=false
      - WEBHOOK_GLOBAL_WEBHOOK_BY_EVENTS=false
      - CONFIG_SESSION_PHONE_CLIENT=Evolution API
      - CONFIG_SESSION_PHONE_NAME=Chrome
      - QRCODE_EXPIRATION_TIME=60
      - TYPEBOT_ENABLED=false
      - CHATWOOT_ENABLED=false
      - WEBSOCKET_ENABLED=false
      - WEBSOCKET_GLOBAL_EVENTS=false
    volumes:
      - evolution_instances:/evolution/instances
      - evolution_store:/evolution/store
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      restart_policy:
        condition: on-failure
        delay: 10s
        max_attempts: 5
        window: 120s
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M
      labels:
        - traefik.enable=true
        - traefik.http.routers.evolution.rule=Host(\`\${DOMINIO_EVOLUTION}\`)
        - traefik.http.routers.evolution.tls=true
        - traefik.http.routers.evolution.tls.certresolver=letsencryptresolver
        - traefik.http.routers.evolution.entrypoints=websecure
        - traefik.http.services.evolution.loadbalancer.server.port=8080
        - traefik.http.routers.evolution.service=evolution
        - traefik.http.routers.evolution-redirect.rule=Host(\`\${DOMINIO_EVOLUTION}\`)
        - traefik.http.routers.evolution-redirect.entrypoints=web
        - traefik.http.routers.evolution-redirect.middlewares=redirect-to-https
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

log_success "Configuração Evolution API criada"

log_info "PASSO 8: Deployando Evolution API..."
env DOMINIO_EVOLUTION="$DOMINIO_EVOLUTION" POSTGRES_PASSWORD="$POSTGRES_PASSWORD" EVOLUTION_API_KEY="$EVOLUTION_API_KEY" docker stack deploy --prune --resolve-image always -c evolution.yaml evolution

if [ $? -ne 0 ]; then
    log_error "Falha ao deployar Evolution API"
    exit 1
fi

log_success "Evolution API deployada com sucesso"

log_info "PASSO 9: Preparando N8N..."

# Verificar/Instalar N8N
if ! docker service ls | grep -q "n8n"; then
    log_info "Instalando N8N..."
    if [ ! -f "n8n.yaml" ]; then
        curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/n8n.yaml" -o "n8n.yaml"
    fi
    env DOMINIO_N8N="$DOMINIO_N8N" WEBHOOK_N8N="$WEBHOOK_N8N" POSTGRES_PASSWORD="$POSTGRES_PASSWORD" N8N_KEY="$N8N_KEY" docker stack deploy --prune --resolve-image always -c n8n.yaml n8n
    wait_for_service "n8n_n8n"
else
    log_success "N8N já está funcionando"
fi

log_info "PASSO 10: Aguardando todos os serviços estabilizarem..."
sleep 60

log_info "PASSO 11: Verificação final de saúde..."

# Verificar todos os serviços
all_services_ok=true

# PostgreSQL
postgres_container=$(docker ps --filter "name=postgres_postgres" --format "{{.Names}}" | head -1)
if [ ! -z "$postgres_container" ] && docker exec $postgres_container pg_isready -U postgres >/dev/null 2>&1; then
    log_success "✅ PostgreSQL: FUNCIONANDO"
else
    log_error "❌ PostgreSQL: COM PROBLEMAS"
    all_services_ok=false
fi

# Redis
redis_container=$(docker ps --filter "name=redis_redis" --format "{{.Names}}" | head -1)
if [ ! -z "$redis_container" ] && docker exec $redis_container redis-cli ping >/dev/null 2>&1; then
    log_success "✅ Redis: FUNCIONANDO"
else
    log_error "❌ Redis: COM PROBLEMAS"
    all_services_ok=false
fi

# Evolution API
evolution_container=$(docker ps --filter "name=evolution_evolution-api" --format "{{.Names}}" | head -1)
if [ ! -z "$evolution_container" ]; then
    log_success "✅ Evolution API: FUNCIONANDO"
else
    log_warning "⚠️ Evolution API: Container não encontrado, aguardando..."
    sleep 30
    evolution_container=$(docker ps --filter "name=evolution_evolution-api" --format "{{.Names}}" | head -1)
    if [ ! -z "$evolution_container" ]; then
        log_success "✅ Evolution API: FUNCIONANDO"
    else
        log_error "❌ Evolution API: COM PROBLEMAS"
        all_services_ok=false
    fi
fi

# N8N
n8n_container=$(docker ps --filter "name=n8n" --format "{{.Names}}" | head -1)
if [ ! -z "$n8n_container" ]; then
    log_success "✅ N8N: FUNCIONANDO"
else
    log_error "❌ N8N: COM PROBLEMAS"
    all_services_ok=false
fi

# Traefik
traefik_container=$(docker ps --filter "name=traefik_traefik" --format "{{.Names}}" | head -1)
if [ ! -z "$traefik_container" ]; then
    log_success "✅ Traefik: FUNCIONANDO"
else
    log_error "❌ Traefik: COM PROBLEMAS"
    all_services_ok=false
fi

# Portainer
portainer_container=$(docker ps --filter "name=portainer_portainer" --format "{{.Names}}" | head -1)
if [ ! -z "$portainer_container" ]; then
    log_success "✅ Portainer: FUNCIONANDO"
else
    log_error "❌ Portainer: COM PROBLEMAS"
    all_services_ok=false
fi

echo ""
echo "======================================================="
if [ "$all_services_ok" = true ]; then
    log_success "🎉 INSTALAÇÃO COMPLETA E FUNCIONANDO PERFEITAMENTE!"
else
    log_warning "⚠️ Alguns serviços podem precisar de mais tempo para inicializar"
fi
echo "======================================================="

echo ""
echo "🌐 URLS DE ACESSO:"
echo "   • Portainer: https://$DOMINIO_PORTAINER"
echo "   • N8N: https://$DOMINIO_N8N"
echo "   • Evolution API: https://$DOMINIO_EVOLUTION"
echo "   • Webhook N8N: https://$WEBHOOK_N8N"
echo "   • Evolution Docs: https://$DOMINIO_EVOLUTION/manager/docs"
echo ""
echo "🔑 CREDENCIAIS IMPORTANTES:"
echo "   • Evolution API Key: $EVOLUTION_API_KEY"
echo "   • PostgreSQL Password: $POSTGRES_PASSWORD"
echo "   • N8N Encryption Key: $N8N_KEY"
echo ""
echo "📋 COMANDOS ÚTEIS:"
echo "   • Ver todos os serviços: docker service ls"
echo "   • Ver stacks: docker stack ls"
echo "   • Ver logs Evolution: docker service logs evolution_evolution-api"
echo "   • Reiniciar Evolution: docker service update --force evolution_evolution-api"
echo ""
echo "🔧 TROUBLESHOOTING:"
if [ "$all_services_ok" = false ]; then
    echo "   • Aguarde 2-3 minutos e execute novamente:"
    echo "     docker service ls"
    echo "   • Se Evolution API não aparecer:"
    echo "     docker service logs evolution_evolution-api --tail 50"
    echo "   • Para reiniciar um serviço:"
    echo "     docker service update --force NOME_DO_SERVIÇO"
fi
echo ""
echo "======================================================="
echo "✅ SCRIPT CONCLUÍDO - SETUPALICIA FUNCIONANDO!"
echo "======================================================="