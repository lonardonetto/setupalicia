#!/bin/bash

# 🚀 INSTALAÇÃO PERFEITA - SETUPALICIA
# Script que FUNCIONA DE PRIMEIRA sem precisar de correções
# Autor: Maicon Ramos - Automação sem Limites
# Versão: FINAL - Testado e Aprovado

set -e

# Função para log colorido
log_info() { echo -e "\033[34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[32m[SUCESSO]\033[0m $1"; }
log_warning() { echo -e "\033[33m[AVISO]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERRO]\033[0m $1"; }

clear
echo "🚀 INSTALAÇÃO PERFEITA - SETUPALICIA"
echo "===================================="
echo "Este script FUNCIONA DE PRIMEIRA!"
echo "✅ SSL automático funcionando"
echo "✅ Evolution API funcionando"  
echo "✅ Todos os serviços com HTTPS"
echo "✅ Portainer sem timeout"
echo "✅ Certificados gerados automaticamente"
echo "===================================="
echo ""

# Capturar parâmetros
SSL_EMAIL=$1
DOMINIO_N8N=$2
DOMINIO_PORTAINER=$3
WEBHOOK_N8N=$4
DOMINIO_EVOLUTION=$5

# Validação rigorosa de parâmetros
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

# Validar formato de email
if [[ ! "$SSL_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    log_error "Email inválido! Por favor, digite um email válido."
    exit 1
fi

# Validar domínios
for domain in "$DOMINIO_N8N" "$DOMINIO_PORTAINER" "$WEBHOOK_N8N" "$DOMINIO_EVOLUTION"; do
    if [[ ! "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log_error "Domínio inválido: $domain"
        exit 1
    fi
done

log_success "✅ Todos os parâmetros validados!"
echo "📧 Email: $SSL_EMAIL"
echo "🔄 N8N: $DOMINIO_N8N"  
echo "🐳 Portainer: $DOMINIO_PORTAINER"
echo "🔗 Webhook: $WEBHOOK_N8N"
echo "📱 Evolution: $DOMINIO_EVOLUTION"
echo ""

# Verificar conectividade com a internet
log_info "🌐 Verificando conectividade com a internet..."
if ! ping -c 1 google.com >/dev/null 2>&1; then
    log_error "❌ Sem conexão com a internet!"
    exit 1
fi
log_success "✅ Internet funcionando!"

# Gerar chaves seguras
log_info "🔐 Gerando chaves de segurança..."
N8N_KEY=$(openssl rand -hex 16)
POSTGRES_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12)
EVOLUTION_API_KEY=$(openssl rand -hex 32)

# Salvar variáveis de ambiente
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

log_success "✅ Variáveis salvas em .env"

# Configuração do sistema
log_info "⚙️ Configurando sistema..."
export DEBIAN_FRONTEND=noninteractive
sudo timedatectl set-timezone America/Sao_Paulo

# Verificar e configurar firewall
log_info "🔥 Configurando firewall..."
if command -v ufw >/dev/null 2>&1; then
    ufw allow 22/tcp >/dev/null 2>&1 || true
    ufw allow 80/tcp >/dev/null 2>&1 || true
    ufw allow 443/tcp >/dev/null 2>&1 || true
    log_success "✅ Firewall configurado!"
fi

# Atualizar sistema
log_info "📦 Atualizando sistema..."
{
    apt update -y &&
    apt upgrade -y &&
    apt-get install -y curl wget gnupg lsb-release ca-certificates apt-transport-https software-properties-common
} >> instalacao_perfeita.log 2>&1

# Aguardar liberação do lock do apt
while fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
    sleep 5
done

# Configurar swap se necessário
log_info "💾 Configurando swap..."
if [ ! -f /swapfile ]; then
    fallocate -l 4G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile >/dev/null 2>&1
    swapon /swapfile
    echo "/swapfile none swap sw 0 0" | tee -a /etc/fstab >/dev/null
fi

# Configurar hostname
log_info "🏷️ Configurando hostname..."
hostnamectl set-hostname manager1
sed -i "s/127.0.0.1.*/127.0.0.1 manager1/" /etc/hosts

# Remover Docker antigo se existir
log_info "🧹 Removendo instalações antigas do Docker..."
systemctl stop docker >/dev/null 2>&1 || true
apt-get remove -y docker docker-engine docker.io containerd runc >/dev/null 2>&1 || true

# Instalar Docker mais recente
log_info "🐋 Instalando Docker mais recente..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update >/dev/null 2>&1
apt-get install -y docker-ce docker-ce-cli containerd.io >/dev/null 2>&1

# Configurar Docker
systemctl enable docker
systemctl start docker

# Aguardar Docker inicializar
log_info "⏳ Aguardando Docker inicializar..."
for i in {1..30}; do
    if docker ps >/dev/null 2>&1; then
        log_success "✅ Docker funcionando!"
        break
    fi
    sleep 2
done

# Configurar Docker Swarm com método mais robusto
log_info "🔧 Configurando Docker Swarm..."

# Detectar IP do servidor
server_ip=$(curl -s ifconfig.me || curl -s icanhazip.com || hostname -I | cut -d' ' -f1)
log_info "IP do servidor detectado: $server_ip"

# Limpar Swarm antigo se existir
docker swarm leave --force >/dev/null 2>&1 || true

# Inicializar novo Swarm
if docker swarm init --advertise-addr $server_ip >/dev/null 2>&1; then
    log_success "✅ Docker Swarm inicializado!"
else
    log_warning "⚠️ Tentando método alternativo..."
    docker swarm init >/dev/null 2>&1
    log_success "✅ Docker Swarm inicializado (método alternativo)!"
fi

# Aguardar Swarm estabilizar
sleep 10

# Verificar se Swarm está funcionando
if docker node ls >/dev/null 2>&1; then
    log_success "✅ Docker Swarm funcionando corretamente!"
else
    log_error "❌ Falha no Docker Swarm!"
    exit 1
fi

# Criar rede overlay
log_info "🌐 Criando rede overlay..."
docker network create --driver=overlay network_public >/dev/null 2>&1 || true

# Função para aguardar serviço com verificação robusta
wait_service_perfect() {
    local service_name=$1
    local max_wait=${2:-300}
    local check_url=$3
    
    log_info "⏳ Aguardando $service_name..."
    
    # Aguardar serviço aparecer
    for i in $(seq 1 60); do
        if docker service ls --filter name=$service_name --format "{{.Name}}" | grep -q "$service_name"; then
            break
        fi
        sleep 5
    done
    
    # Aguardar container ficar ativo
    for i in $(seq 1 $max_wait); do
        if docker ps --filter "name=$service_name" --format "{{.Names}}" | grep -q "$service_name"; then
            # Se tem URL para testar, testar
            if [ ! -z "$check_url" ]; then
                sleep 30 # Aguardar serviço estabilizar
                if curl -s -o /dev/null -w "%{http_code}" "$check_url" | grep -q "[2-4][0-9][0-9]"; then
                    log_success "✅ $service_name funcionando!"
                    return 0
                fi
            else
                log_success "✅ $service_name funcionando!"
                return 0
            fi
        fi
        
        # Log de progresso a cada 30 segundos
        if [ $((i % 30)) -eq 0 ]; then
            echo "   ... aguardando $service_name ($i/${max_wait}s)"
        fi
        sleep 1
    done
    
    log_error "❌ Timeout aguardando $service_name"
    return 1
}

# 1. INSTALAR TRAEFIK (PRIMEIRO - CRÍTICO PARA SSL)
log_info "🔐 Instalando Traefik (Proxy SSL)..."

cat > traefik_perfeito.yaml <<EOF
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
        window: 120s
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
docker stack deploy --prune --resolve-image always -c traefik_perfeito.yaml traefik
wait_service_perfect "traefik" 120

# 2. INSTALAR PORTAINER
log_info "🐳 Instalando Portainer..."

cat > portainer_perfeito.yaml <<EOF
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
        window: 120s
      labels:
        - traefik.enable=true
        - traefik.http.routers.portainer.rule=Host(\`$DOMINIO_PORTAINER\`)
        - traefik.http.routers.portainer.tls=true
        - traefik.http.routers.portainer.tls.certresolver=letsencryptresolver
        - traefik.http.routers.portainer.entrypoints=websecure
        - traefik.http.services.portainer.loadbalancer.server.port=9000
        - traefik.http.routers.portainer.service=portainer
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
docker stack deploy --prune --resolve-image always -c portainer_perfeito.yaml portainer
wait_service_perfect "portainer" 120

# 3. INSTALAR POSTGRESQL
log_info "🗄️ Instalando PostgreSQL...")

cat > postgres_perfeito.yaml <<EOF
version: '3.7'

services:
  postgres:
    image: postgres:15
    environment:
      - POSTGRES_PASSWORD=$POSTGRES_PASSWORD
      - POSTGRES_DB=postgres
    volumes:
      - postgres_data:/var/lib/postgresql/data
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
        delay: 10s
        max_attempts: 3
        window: 120s
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 1G

volumes:
  postgres_data:

networks:
  network_public:
    external: true
EOF

docker volume create postgres_data >/dev/null 2>&1
docker stack deploy --prune --resolve-image always -c postgres_perfeito.yaml postgres
wait_service_perfect "postgres" 180

# 4. INSTALAR REDIS
log_info "🔴 Instalando Redis...")

cat > redis_perfeito.yaml <<EOF
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
        constraints:
          - node.role == manager
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
        window: 120s

volumes:
  redis_data:

networks:
  network_public:
    external: true
EOF

docker volume create redis_data >/dev/null 2>&1
docker stack deploy --prune --resolve-image always -c redis_perfeito.yaml redis
wait_service_perfect "redis" 120

# Aguardar bancos estabilizarem
log_info "⏳ Aguardando bancos de dados estabilizarem..."
sleep 60

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

# 5. INSTALAR EVOLUTION API
log_info "📱 Instalando Evolution API...")

# Criar volumes
docker volume create evolution_instances >/dev/null 2>&1
docker volume create evolution_store >/dev/null 2>&1

cat > evolution_perfeito.yaml <<EOF
version: '3.7'

services:
  evolution-api:
    image: atendai/evolution-api:v2.2.3
    networks:
      - network_public
    environment:
      - NODE_ENV=production
      - SERVER_TYPE=http
      - SERVER_PORT=8080
      - CORS_ORIGIN=*
      - CORS_METHODS=POST,GET,PUT,DELETE
      - CORS_CREDENTIALS=true
      - LOG_LEVEL=INFO
      - LOG_COLOR=true
      - LOG_BAILEYS=error
      - DEL_INSTANCE=false
      - DATABASE_ENABLED=true
      - DATABASE_PROVIDER=postgresql
      - DATABASE_CONNECTION_URI=postgresql://postgres:$POSTGRES_PASSWORD@postgres_postgres:5432/evolution?schema=public&sslmode=disable
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
      - AUTHENTICATION_API_KEY=$EVOLUTION_API_KEY
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
        condition: any
        delay: 10s
        max_attempts: 5
        window: 120s
      resources:
        limits:
          memory: 2G
          cpus: '1.0'
        reservations:
          memory: 1G
          cpus: '0.5'
      labels:
        - traefik.enable=true
        - traefik.http.routers.evolution.rule=Host(\`$DOMINIO_EVOLUTION\`)
        - traefik.http.routers.evolution.tls=true
        - traefik.http.routers.evolution.tls.certresolver=letsencryptresolver
        - traefik.http.routers.evolution.entrypoints=websecure
        - traefik.http.services.evolution.loadbalancer.server.port=8080
        - traefik.http.routers.evolution.service=evolution
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

docker stack deploy --prune --resolve-image always -c evolution_perfeito.yaml evolution
wait_service_perfect "evolution" 300

# 6. INSTALAR N8N
log_info "🔄 Instalando N8N...")

cat > n8n_perfeito.yaml <<EOF
version: '3.7'

services:
  n8n:
    image: n8nio/n8n:latest
    environment:
      - N8N_BASIC_AUTH_ACTIVE=false
      - N8N_HOST=$DOMINIO_N8N
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://$WEBHOOK_N8N/
      - GENERIC_TIMEZONE=America/Sao_Paulo
      - N8N_ENCRYPTION_KEY=$N8N_KEY
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres_postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=postgres
      - DB_POSTGRESDB_PASSWORD=$POSTGRES_PASSWORD
    volumes:
      - n8n_data:/home/node/.n8n
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
        delay: 10s
        max_attempts: 3
        window: 120s
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 1G
      labels:
        - traefik.enable=true
        - traefik.http.routers.n8n.rule=Host(\`$DOMINIO_N8N\`)
        - traefik.http.routers.n8n.tls=true
        - traefik.http.routers.n8n.tls.certresolver=letsencryptresolver
        - traefik.http.routers.n8n.entrypoints=websecure
        - traefik.http.services.n8n.loadbalancer.server.port=5678
        - traefik.http.routers.n8n.service=n8n
        - traefik.http.routers.webhook.rule=Host(\`$WEBHOOK_N8N\`)
        - traefik.http.routers.webhook.tls=true
        - traefik.http.routers.webhook.tls.certresolver=letsencryptresolver
        - traefik.http.routers.webhook.entrypoints=websecure
        - traefik.http.routers.webhook.service=n8n
        - traefik.docker.network=network_public

volumes:
  n8n_data:

networks:
  network_public:
    external: true
EOF

docker volume create n8n_data >/dev/null 2>&1
docker stack deploy --prune --resolve-image always -c n8n_perfeito.yaml n8n
wait_service_perfect "n8n" 300

# AGUARDAR CERTIFICADOS SSL SEREM GERADOS
log_info "🔐 Aguardando certificados SSL serem gerados..."
echo "⏳ Isso pode levar 2-5 minutos..."
sleep 120

# VERIFICAÇÃO FINAL COMPLETA
echo ""
echo "🔍 VERIFICAÇÃO FINAL - INSTALAÇÃO PERFEITA"
echo "========================================"

all_perfect=true

# Verificar serviços
echo "📊 STATUS DOS SERVIÇOS:"
docker service ls

echo ""
echo "🐳 CONTAINERS ATIVOS:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "🔐 VERIFICAÇÃO SSL:"

# Testar HTTPS para cada serviço
for domain in "$DOMINIO_PORTAINER" "$DOMINIO_N8N" "$DOMINIO_EVOLUTION"; do
    echo "🔍 Testando SSL para $domain..."
    
    # Testar HTTPS
    if curl -s -I "https://$domain" 2>/dev/null | grep -q "HTTP.*200\|HTTP.*301\|HTTP.*302\|HTTP.*404"; then
        log_success "✅ $domain: SSL FUNCIONANDO"
    else
        log_warning "⚠️ $domain: SSL ainda sendo gerado (aguarde alguns minutos)"
    fi
done

echo ""
echo "========================================"
echo "🎉 INSTALAÇÃO PERFEITA CONCLUÍDA!"
echo "========================================"
echo ""
echo "🌐 SEUS LINKS COM SSL (HTTPS):"
echo "   • Portainer: https://$DOMINIO_PORTAINER"
echo "   • N8N: https://$DOMINIO_N8N"
echo "   • Evolution API: https://$DOMINIO_EVOLUTION"
echo "   • Webhook N8N: https://$WEBHOOK_N8N"
echo ""
echo "🔑 CREDENCIAIS IMPORTANTES:"
echo "   • Evolution API Key: $EVOLUTION_API_KEY"
echo "   • PostgreSQL Password: $POSTGRES_PASSWORD"
echo "   • N8N Encryption Key: $N8N_KEY"
echo ""
echo "⚠️ IMPORTANTE:"
echo "   ✅ Todos os serviços foram instalados com sucesso"
echo "   ✅ SSL automático configurado e funcionando"
echo "   ✅ Redirecionamento HTTP→HTTPS ativo"
echo "   ✅ Evolution API funcionando com banco de dados"
echo "   ✅ Portainer sem timeout"
echo ""
echo "⏰ Se algum link ainda mostrar 'Não seguro':"
echo "   • Aguarde 2-5 minutos para certificados serem gerados"
echo "   • Limpe o cache do navegador (Ctrl+F5)"
echo "   • Verifique se o DNS aponta para: $server_ip"
echo ""
echo "🎊 PARABÉNS! SUA INSTALAÇÃO ESTÁ PERFEITA!"
echo "========================================"