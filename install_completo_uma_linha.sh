#!/bin/bash

# 🚀 INSTALAÇÃO COMPLETA EM UM COMANDO ÚNICO
# Instalador Definitivo: N8N + Evolution API + Traefik + Portainer + PostgreSQL + Redis
# Autor: Maicon Ramos - Automação sem Limites
# Versão: 1.0 - Comando Único

set -e

# Função para log colorido
log_info() { echo -e "\033[34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $1"; }
log_warning() { echo -e "\033[33m[WARNING]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $1"; }

clear
echo "🚀 SETUPALICIA - INSTALAÇÃO COMPLETA EM UM COMANDO"
echo "======================================================="
echo "Este script instalará TUDO de uma vez:"
echo "✅ Docker + Docker Swarm"
echo "✅ Traefik (SSL Automático)"
echo "✅ Portainer (Interface Docker)"
echo "✅ PostgreSQL (Banco de Dados)"
echo "✅ Redis (Cache)"
echo "✅ Evolution API v2.2.3 (WhatsApp)"
echo "✅ N8N (Automação)"
echo "======================================================="
echo ""

# Capturar parâmetros
SSL_EMAIL=$1
DOMINIO_N8N=$2
DOMINIO_PORTAINER=$3
WEBHOOK_N8N=$4
DOMINIO_EVOLUTION=$5

# Se não fornecidos, perguntar interativamente
if [ -z "$SSL_EMAIL" ]; then
    read -p "📧 Digite seu email para SSL: " SSL_EMAIL
fi

if [ -z "$DOMINIO_N8N" ]; then
    read -p "🔄 Digite o domínio para N8N (ex: n8n.seudominio.com): " DOMINIO_N8N
fi

if [ -z "$DOMINIO_PORTAINER" ]; then
    read -p "🐳 Digite o domínio para Portainer (ex: portainer.seudominio.com): " DOMINIO_PORTAINER
fi

if [ -z "$WEBHOOK_N8N" ]; then
    read -p "🔗 Digite o domínio para Webhook N8N (ex: webhook.seudominio.com): " WEBHOOK_N8N
fi

if [ -z "$DOMINIO_EVOLUTION" ]; then
    read -p "📱 Digite o domínio para Evolution API (ex: evolution.seudominio.com): " DOMINIO_EVOLUTION
fi

# Validar se todos os campos foram preenchidos
if [ -z "$SSL_EMAIL" ] || [ -z "$DOMINIO_N8N" ] || [ -z "$DOMINIO_PORTAINER" ] || [ -z "$WEBHOOK_N8N" ] || [ -z "$DOMINIO_EVOLUTION" ]; then
    log_error "Todos os campos são obrigatórios!"
    exit 1
fi

log_success "Configuração validada!"
echo "📧 Email: $SSL_EMAIL"
echo "🔄 N8N: $DOMINIO_N8N"  
echo "🐳 Portainer: $DOMINIO_PORTAINER"
echo "🔗 Webhook: $WEBHOOK_N8N"
echo "📱 Evolution: $DOMINIO_EVOLUTION"
echo ""

# Gerar chaves seguras
log_info "Gerando chaves de segurança..."
N8N_KEY=$(openssl rand -hex 16)
POSTGRES_PASSWORD=$(openssl rand -base64 12)
EVOLUTION_API_KEY=$(openssl rand -hex 32)

# Salvar variáveis
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

log_success "Variáveis de ambiente salvas em .env"

# Configuração do sistema
log_info "Configurando sistema..."
export DEBIAN_FRONTEND=noninteractive
sudo timedatectl set-timezone America/Sao_Paulo

# Atualizar sistema
log_info "Atualizando sistema (pode demorar)..."
{
    sudo apt update -y &&
    sudo apt upgrade -y &&
    sudo apt-get install -y apparmor-utils curl lsb-release ca-certificates apt-transport-https software-properties-common gnupg2
} >> instalacao_completa.log 2>&1

# Configurar swap
log_info "Configurando swap de 4GB..."
sudo fallocate -l 4G /swapfile >> instalacao_completa.log 2>&1
sudo chmod 600 /swapfile
sudo mkswap /swapfile >> instalacao_completa.log 2>&1
sudo swapon /swapfile
sudo cp /etc/fstab /etc/fstab.bak
echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab >> instalacao_completa.log 2>&1

# Configurar hostname
log_info "Configurando hostname..."
sudo hostnamectl set-hostname manager1
sudo sed -i "s/127.0.0.1.*/127.0.0.1 manager1/" /etc/hosts

# Instalar Docker
log_info "Instalando Docker..."
curl -fsSL https://get.docker.com | bash >> instalacao_completa.log 2>&1
sudo usermod -aG docker $USER

# Configurar Docker Swarm
log_info "Configurando Docker Swarm..."
endereco_ip=$(ip route get 8.8.8.8 | grep -oP 'src \K[^ ]+')
if [[ -z $endereco_ip ]]; then
    log_error "Não foi possível obter o endereço IP."
    exit 1
fi

docker swarm init --advertise-addr $endereco_ip >> instalacao_completa.log 2>&1
docker network create --driver=overlay network_public >> instalacao_completa.log 2>&1

log_success "Docker Swarm configurado com IP: $endereco_ip"

# Função para aguardar serviço
wait_service() {
    local service=$1
    local max_wait=120
    local count=0
    
    log_info "Aguardando $service ficar pronto..."
    while [ $count -lt $max_wait ]; do
        if docker service ps $service 2>/dev/null | grep -q "Running"; then
            log_success "$service está funcionando!"
            return 0
        fi
        sleep 5
        ((count+=5))
        echo -n "."
    done
    log_error "$service não ficou pronto"
    return 1
}

# Instalar Traefik
log_info "Instalando Traefik..."
curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/traefik.yaml" -o "traefik.yaml"
env SSL_EMAIL="$SSL_EMAIL" docker stack deploy --prune --resolve-image always -c traefik.yaml traefik >> instalacao_completa.log 2>&1
wait_service "traefik_traefik"

# Instalar Portainer
log_info "Instalando Portainer..."
curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/portainer.yaml" -o "portainer.yaml"
env DOMINIO_PORTAINER="$DOMINIO_PORTAINER" docker stack deploy --prune --resolve-image always -c portainer.yaml portainer >> instalacao_completa.log 2>&1
wait_service "portainer_portainer"

# Instalar PostgreSQL
log_info "Instalando PostgreSQL..."
curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/postgres.yaml" -o "postgres.yaml"
env POSTGRES_PASSWORD="$POSTGRES_PASSWORD" docker stack deploy --prune --resolve-image always -c postgres.yaml postgres >> instalacao_completa.log 2>&1
wait_service "postgres_postgres"

# Instalar Redis
log_info "Instalando Redis..."
curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/redis.yaml" -o "redis.yaml"
docker stack deploy --prune --resolve-image always -c redis.yaml redis >> instalacao_completa.log 2>&1
wait_service "redis_redis"

# Aguardar estabilização dos bancos
log_info "Aguardando estabilização dos bancos de dados..."
sleep 60

# Verificar PostgreSQL e criar bancos
log_info "Criando bancos de dados..."
postgres_ready=false
for i in {1..30}; do
    postgres_container=$(docker ps --filter "name=postgres_postgres" --format "{{.Names}}" | head -1)
    if [ ! -z "$postgres_container" ]; then
        if docker exec $postgres_container pg_isready -U postgres >/dev/null 2>&1; then
            log_success "PostgreSQL está pronto!"
            
            # Criar bancos
            docker exec $postgres_container psql -U postgres -d postgres -c "CREATE DATABASE IF NOT EXISTS evolution;" 2>/dev/null || \
            docker exec $postgres_container psql -U postgres -d postgres -c "CREATE DATABASE evolution;" 2>/dev/null
            
            docker exec $postgres_container psql -U postgres -d postgres -c "CREATE DATABASE IF NOT EXISTS n8n;" 2>/dev/null || \
            docker exec $postgres_container psql -U postgres -d postgres -c "CREATE DATABASE n8n;" 2>/dev/null
            
            log_success "Bancos de dados criados!"
            postgres_ready=true
            break
        fi
    fi
    log_info "Aguardando PostgreSQL... ($i/30)"
    sleep 3
done

if [ "$postgres_ready" = false ]; then
    log_error "PostgreSQL não ficou pronto"
    exit 1
fi

# Criar volumes Evolution
docker volume create evolution_instances >/dev/null 2>&1
docker volume create evolution_store >/dev/null 2>&1

# Instalar Evolution API
log_info "Instalando Evolution API..."

# Criar evolution.yaml local com configuração correta
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

env DOMINIO_EVOLUTION="$DOMINIO_EVOLUTION" POSTGRES_PASSWORD="$POSTGRES_PASSWORD" EVOLUTION_API_KEY="$EVOLUTION_API_KEY" docker stack deploy --prune --resolve-image always -c evolution.yaml evolution >> instalacao_completa.log 2>&1
wait_service "evolution_evolution-api"

# Instalar N8N
log_info "Instalando N8N..."
curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/n8n.yaml" -o "n8n.yaml"
env DOMINIO_N8N="$DOMINIO_N8N" WEBHOOK_N8N="$WEBHOOK_N8N" POSTGRES_PASSWORD="$POSTGRES_PASSWORD" N8N_KEY="$N8N_KEY" docker stack deploy --prune --resolve-image always -c n8n.yaml n8n >> instalacao_completa.log 2>&1
wait_service "n8n_n8n"

# Verificação final
log_info "Verificação final dos serviços..."
sleep 30

echo ""
echo "======================================================="
echo "🎉 INSTALAÇÃO COMPLETA FINALIZADA COM SUCESSO!"
echo "======================================================="
echo ""
echo "🌐 URLS DE ACESSO:"
echo "   • Portainer: https://$DOMINIO_PORTAINER"
echo "   • N8N: https://$DOMINIO_N8N"
echo "   • Evolution API: https://$DOMINIO_EVOLUTION"
echo "   • Evolution Docs: https://$DOMINIO_EVOLUTION/manager/docs"
echo "   • Webhook N8N: https://$WEBHOOK_N8N"
echo ""
echo "🔑 CREDENCIAIS (SALVAS EM .env):"
echo "   • Evolution API Key: $EVOLUTION_API_KEY"
echo "   • PostgreSQL Password: $POSTGRES_PASSWORD"
echo "   • N8N Encryption Key: $N8N_KEY"
echo ""
echo "📊 STATUS DOS SERVIÇOS:"
docker service ls
echo ""
echo "🔧 COMANDOS ÚTEIS:"
echo "   • Ver logs: docker service logs [nome-do-serviço]"
echo "   • Reiniciar: docker service update --force [nome-do-serviço]"
echo "   • Status: docker stack ps [nome-da-stack]"
echo ""
echo "⚠️ IMPORTANTE:"
echo "   • Aguarde 2-3 minutos para SSL ser gerado"
echo "   • Todos os domínios devem apontar para este IP: $endereco_ip"
echo "   • Portas 80 e 443 devem estar abertas no firewall"
echo ""
echo "======================================================="
echo "✅ TUDO FUNCIONANDO! ACESSE OS LINKS ACIMA"
echo "======================================================="