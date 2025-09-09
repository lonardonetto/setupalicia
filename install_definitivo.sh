#!/bin/bash

# 🚀 INSTALAÇÃO DEFINITIVA - N8N + EVOLUTION API + TRAEFIK + PORTAINER
# Autor: Maicon Ramos - Automação sem Limites
# Versão: 3.0 - Instalação que FUNCIONA

set -e

# Função para log colorido
log_info() { echo -e "\033[34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $1"; }
log_warning() { echo -e "\033[33m[WARNING]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $1"; }

clear
echo "🚀 INSTALAÇÃO DEFINITIVA - SETUPALICIA"
echo "======================================="
echo "Este script instalará TUDO funcionando:"
echo "✅ Docker + Docker Swarm"
echo "✅ Traefik (SSL Automático)"
echo "✅ Portainer (Interface Docker)"
echo "✅ PostgreSQL (Banco de Dados)"
echo "✅ Redis (Cache)"
echo "✅ Evolution API v2.2.3 (WhatsApp)"
echo "✅ N8N (Automação)"
echo "======================================="
echo ""

# Capturar parâmetros
SSL_EMAIL=$1
DOMINIO_N8N=$2
DOMINIO_PORTAINER=$3
WEBHOOK_N8N=$4
DOMINIO_EVOLUTION=$5

# Validação de parâmetros com prompts interativos
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

log_success "✅ Parâmetros validados com sucesso!"
echo "📧 Email: $SSL_EMAIL"
echo "🔄 N8N: $DOMINIO_N8N"  
echo "🐳 Portainer: $DOMINIO_PORTAINER"
echo "🔗 Webhook: $WEBHOOK_N8N"
echo "📱 Evolution: $DOMINIO_EVOLUTION"
echo ""

# Gerar chaves seguras
log_info "🔐 Gerando chaves de segurança..."
N8N_KEY=$(openssl rand -hex 16)
POSTGRES_PASSWORD=$(openssl rand -base64 12)
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

# Atualizar sistema
log_info "📦 Atualizando sistema (pode demorar alguns minutos)..."
{
    sudo apt update -y &&
    sudo apt upgrade -y &&
    sudo apt-get install -y apparmor-utils curl lsb-release ca-certificates apt-transport-https software-properties-common gnupg2
} >> instalacao_definitiva.log 2>&1

# Aguardar liberação do lock do apt
while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
    sleep 5
done

# Configurar swap
log_info "💾 Configurando swap de 4GB..."
if [ ! -f /swapfile ]; then
    sudo fallocate -l 4G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab
fi

# Configurar hostname
log_info "🏷️ Configurando hostname..."
sudo hostnamectl set-hostname manager1
sudo sed -i "s/127.0.0.1.*/127.0.0.1 manager1/" /etc/hosts

# Instalar Docker
log_info "🐋 Instalando Docker..."
if ! command -v docker &> /dev/null; then
    log_info "Docker não encontrado, instalando..."
    if curl -fsSL https://get.docker.com | bash >> instalacao_definitiva.log 2>&1; then
        log_success "✅ Docker instalado com sucesso!"
    else
        log_error "❌ Falha ao instalar Docker!"
        exit 1
    fi
    
    log_info "Adicionando usuário ao grupo docker..."
    sudo usermod -aG docker $USER
    
    log_info "Reiniciando serviço Docker..."
    sudo systemctl restart docker
    sleep 5
else
    log_success "✅ Docker já está instalado!"
fi

# Verificar se Docker está funcionando
log_info "Verificando funcionamento do Docker..."
for i in {1..30}; do
    if docker ps >/dev/null 2>&1; then
        log_success "✅ Docker está funcionando!"
        break
    fi
    log_info "Tentativa $i/30 - Aguardando Docker inicializar..."
    sleep 2
done

if ! docker ps >/dev/null 2>&1; then
    log_error "❌ Docker não está funcionando após 60 segundos!"
    exit 1
fi

# Configurar Docker Swarm
log_info "🔧 Configurando Docker Swarm..."

# Múltiplos métodos para obter IP com fallback
log_info "Detectando endereço IP do servidor..."
endereco_ip=""

# Método 1: ip route (mais comum)
if [ -z "$endereco_ip" ]; then
    endereco_ip=$(ip route get 8.8.8.8 2>/dev/null | grep -oE 'src [0-9.]+' | cut -d' ' -f2 | head -1)
fi

# Método 2: hostname -I (fallback)
if [ -z "$endereco_ip" ]; then
    endereco_ip=$(hostname -I | cut -d' ' -f1)
fi

# Método 3: interface eth0 (fallback)
if [ -z "$endereco_ip" ]; then
    endereco_ip=$(ip -4 addr show eth0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
fi

# Método 4: interface ens3 (VPS comum)
if [ -z "$endereco_ip" ]; then
    endereco_ip=$(ip -4 addr show ens3 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
fi

# Método 5: qualquer interface (último recurso)
if [ -z "$endereco_ip" ]; then
    endereco_ip=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1)
fi

if [[ -z $endereco_ip ]]; then
    log_error "❌ Não foi possível obter o endereço IP do servidor!"
    log_info "Tentando continuar com IP local..."
    endereco_ip="127.0.0.1"
fi

log_info "IP detectado: $endereco_ip"

# Verificar se Docker está funcionando
log_info "Verificando se Docker está funcionando..."
if ! docker ps >/dev/null 2>&1; then
    log_error "❌ Docker não está funcionando! Tentando reiniciar..."
    sudo systemctl restart docker
    sleep 10
    
    if ! docker ps >/dev/null 2>&1; then
        log_error "❌ Docker ainda não está funcionando!"
        exit 1
    fi
fi
log_success "✅ Docker está funcionando!"

# Verificar estado atual do Swarm de forma mais robusta
log_info "Verificando estado do Docker Swarm..."
swarm_status="inactive"

# Tentar diferentes métodos para verificar Swarm
if docker info 2>/dev/null | grep -q "Swarm: active"; then
    swarm_status="active"
elif docker node ls >/dev/null 2>&1; then
    swarm_status="active"
fi

log_info "Estado atual do Swarm: $swarm_status"

# Inicializar Swarm se necessário
if [ "$swarm_status" != "active" ]; then
    log_info "Inicializando Docker Swarm..."
    if docker swarm init --advertise-addr $endereco_ip >> instalacao_definitiva.log 2>&1; then
        log_success "✅ Docker Swarm inicializado com sucesso!"
    else
        log_warning "⚠️ Falha ao inicializar Swarm. Tentando sem --advertise-addr..."
        if docker swarm init >> instalacao_definitiva.log 2>&1; then
            log_success "✅ Docker Swarm inicializado (método alternativo)!"
        else
            log_error "❌ Falha ao inicializar Docker Swarm!"
            log_info "Verificando se já existe um Swarm..."
            if docker node ls >/dev/null 2>&1; then
                log_warning "⚠️ Swarm já existe, continuando..."
            else
                exit 1
            fi
        fi
    fi
else
    log_success "✅ Docker Swarm já está ativo!"
fi

# Aguardar Swarm estabilizar
log_info "Aguardando Swarm estabilizar..."
sleep 5

# Verificar se conseguimos listar nodes
for i in {1..10}; do
    if docker node ls >/dev/null 2>&1; then
        log_success "✅ Swarm está funcionando corretamente!"
        break
    fi
    log_info "Tentativa $i/10 - Aguardando Swarm..."
    sleep 2
done

# Criar rede overlay se não existir
log_info "Criando rede overlay network_public..."
if docker network ls | grep -q "network_public"; then
    log_success "✅ Rede network_public já existe!"
else
    if docker network create --driver=overlay network_public >> instalacao_definitiva.log 2>&1; then
        log_success "✅ Rede network_public criada!"
    else
        log_error "❌ Falha ao criar rede network_public!"
        # Tentar continuar mesmo assim
        log_warning "⚠️ Continuando sem a rede overlay..."
    fi
fi

log_success "✅ Docker Swarm configurado com IP: $endereco_ip"

# Função para aguardar serviço ficar pronto
wait_service_ready() {
    local service_name=$1
    local container_filter=$2
    local max_wait=${3:-300}
    local check_command=$4
    
    log_info "⏳ Aguardando $service_name ficar pronto..."
    
    # Aguardar serviço existir
    log_info "Verificando se serviço $service_name existe..."
    local count=0
    while [ $count -lt 60 ]; do
        if docker service ls --filter name=$service_name --format "{{.Name}}" 2>/dev/null | grep -q "$service_name"; then
            log_success "✅ Serviço $service_name encontrado!"
            break
        fi
        if [ $((count % 15)) -eq 0 ]; then
            log_info "   ... aguardando serviço aparecer (${count}s)"
        fi
        sleep 5
        ((count+=5))
    done
    
    if [ $count -ge 60 ]; then
        log_error "❌ Serviço $service_name não foi encontrado após 60s"
        log_info "Listando todos os serviços disponíveis:"
        docker service ls
        return 1
    fi
    
    # Aguardar container ficar ativo
    log_info "Aguardando container do $service_name ficar ativo..."
    count=0
    while [ $count -lt $max_wait ]; do
        local container=$(docker ps --filter "$container_filter" --format "{{.Names}}" | head -1)
        if [ ! -z "$container" ]; then
            log_success "✅ Container encontrado: $container"
            
            if [ ! -z "$check_command" ]; then
                log_info "Executando verificação de saúde..."
                if eval "$check_command" >/dev/null 2>&1; then
                    log_success "✅ $service_name está funcionando!"
                    return 0
                else
                    log_info "   ... verificação de saúde falhou, aguardando..."
                fi
            else
                log_success "✅ $service_name está funcionando!"
                return 0
            fi
        else
            # Verificar se o serviço tem problemas
            local service_status=$(docker service ps $service_name --format "{{.CurrentState}}" 2>/dev/null | head -1)
            if echo "$service_status" | grep -q "Failed\|Rejected"; then
                log_warning "⚠️ Problema detectado em $service_name: $service_status"
                log_info "Tentando forçar restart do serviço..."
                docker service update --force $service_name >/dev/null 2>&1
                sleep 10
            fi
        fi
        
        if [ $((count % 30)) -eq 0 ]; then
            echo "   ... aguardando $service_name ($count/${max_wait}s)"
            log_info "Status atual do serviço:"
            docker service ps $service_name 2>/dev/null || echo "   Serviço não encontrado"
        fi
        sleep 5
        ((count+=5))
    done
    
    log_error "❌ $service_name não ficou pronto após $max_wait segundos"
    log_info "Status final do serviço:"
    docker service ps $service_name 2>/dev/null
    log_info "Logs do serviço:"
    docker service logs $service_name --tail 10 2>/dev/null
    return 1
}

# 1. INSTALAR TRAEFIK
log_info "🔐 Instalando Traefik..."
log_info "Baixando arquivo traefik.yaml..."
if curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/traefik.yaml" -o "traefik.yaml"; then
    log_success "✅ Arquivo traefik.yaml baixado!"
else
    log_error "❌ Falha ao baixar traefik.yaml!"
    exit 1
fi

log_info "Fazendo deploy da stack traefik..."
if env SSL_EMAIL="$SSL_EMAIL" docker stack deploy --prune --resolve-image always -c traefik.yaml traefik >> instalacao_definitiva.log 2>&1; then
    log_success "✅ Stack traefik deployada!"
else
    log_error "❌ Falha ao fazer deploy da stack traefik!"
    exit 1
fi

wait_service_ready "traefik_traefik" "name=traefik_traefik" 120

# 2. INSTALAR PORTAINER
log_info "🐳 Instalando Portainer..."
curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/portainer.yaml" -o "portainer.yaml"
env DOMINIO_PORTAINER="$DOMINIO_PORTAINER" docker stack deploy --prune --resolve-image always -c portainer.yaml portainer >> instalacao_definitiva.log 2>&1
wait_service_ready "portainer_portainer" "name=portainer_portainer" 120

# 3. INSTALAR POSTGRESQL
log_info "🗄️ Instalando PostgreSQL..."
curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/postgres.yaml" -o "postgres.yaml"
env POSTGRES_PASSWORD="$POSTGRES_PASSWORD" docker stack deploy --prune --resolve-image always -c postgres.yaml postgres >> instalacao_definitiva.log 2>&1
wait_service_ready "postgres_postgres" "name=postgres_postgres" 180 "docker exec \$(docker ps --filter 'name=postgres_postgres' --format '{{.Names}}' | head -1) pg_isready -U postgres"

# 4. INSTALAR REDIS
log_info "🔴 Instalando Redis..."
curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/redis.yaml" -o "redis.yaml"
docker stack deploy --prune --resolve-image always -c redis.yaml redis >> instalacao_definitiva.log 2>&1
wait_service_ready "redis_redis" "name=redis_redis" 120 "docker exec \$(docker ps --filter 'name=redis_redis' --format '{{.Names}}' | head -1) redis-cli ping"

# 5. PREPARAR BANCOS DE DADOS
log_info "🗃️ Preparando bancos de dados..."
sleep 10

postgres_container=$(docker ps --filter "name=postgres_postgres" --format "{{.Names}}" | head -1)
if [ ! -z "$postgres_container" ]; then
    # Criar bancos
    docker exec $postgres_container psql -U postgres -d postgres -c "CREATE DATABASE IF NOT EXISTS evolution;" 2>/dev/null || \
    docker exec $postgres_container psql -U postgres -d postgres -c "CREATE DATABASE evolution;" 2>/dev/null
    
    docker exec $postgres_container psql -U postgres -d postgres -c "CREATE DATABASE IF NOT EXISTS n8n;" 2>/dev/null || \
    docker exec $postgres_container psql -U postgres -d postgres -c "CREATE DATABASE n8n;" 2>/dev/null
    
    log_success "✅ Bancos de dados criados!"
fi

# Criar volumes para Evolution
docker volume create evolution_instances >/dev/null 2>&1 || true
docker volume create evolution_store >/dev/null 2>&1 || true

# 6. INSTALAR EVOLUTION API
log_info "📱 Instalando Evolution API..."

# Criar arquivo YAML otimizado para Evolution API
cat > evolution.yaml <<EOF
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
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/manager/docs"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 120s
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
      update_config:
        failure_action: rollback
        monitor: 60s
        delay: 30s
      resources:
        limits:
          memory: 2G
          cpus: '1.0'
        reservations:
          memory: 1G
          cpus: '0.5'
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

# Deploy da Evolution API com variáveis de ambiente
env DOMINIO_EVOLUTION="$DOMINIO_EVOLUTION" POSTGRES_PASSWORD="$POSTGRES_PASSWORD" EVOLUTION_API_KEY="$EVOLUTION_API_KEY" \
docker stack deploy --prune --resolve-image always -c evolution.yaml evolution >> instalacao_definitiva.log 2>&1

# Aguardar Evolution API com verificação mais rigorosa
wait_service_ready "evolution_evolution-api" "name=evolution_evolution-api" 600

# 7. INSTALAR N8N
log_info "🔄 Instalando N8N..."
curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/n8n.yaml" -o "n8n.yaml"
env DOMINIO_N8N="$DOMINIO_N8N" WEBHOOK_N8N="$WEBHOOK_N8N" POSTGRES_PASSWORD="$POSTGRES_PASSWORD" N8N_KEY="$N8N_KEY" \
docker stack deploy --prune --resolve-image always -c n8n.yaml n8n >> instalacao_definitiva.log 2>&1
wait_service_ready "n8n_n8n" "name=n8n" 300

# VERIFICAÇÃO FINAL COMPLETA
log_info "🔍 Executando verificação final..."
sleep 30

echo ""
echo "======================================="
echo "           VERIFICAÇÃO FINAL"
echo "======================================="

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
    log_success "✅ Evolution API: CONTAINER EXECUTANDO"
    
    # Teste de conectividade HTTP
    sleep 10
    container_ip=$(docker inspect $evolution_container --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null)
    if [ ! -z "$container_ip" ] && curl -s -o /dev/null -w "%{http_code}" "http://$container_ip:8080" | grep -q "[2-4][0-9][0-9]"; then
        log_success "✅ Evolution API: RESPONDENDO HTTP"
    else
        log_warning "⚠️ Evolution API: AINDA INICIALIZANDO (aguarde 2-3 minutos)"
    fi
else
    log_error "❌ Evolution API: CONTAINER NÃO ENCONTRADO"
    all_services_ok=false
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
echo "======================================="
if [ "$all_services_ok" = true ]; then
    echo "🎉 INSTALAÇÃO CONCLUÍDA COM SUCESSO!"
    echo "✅ TODOS OS SERVIÇOS ESTÃO FUNCIONANDO!"
else
    echo "⚠️ INSTALAÇÃO FINALIZADA COM ALGUNS PROBLEMAS"
    echo "Verifique os logs acima para mais detalhes"
fi
echo "======================================="
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
echo "📊 STATUS ATUAL DOS SERVIÇOS:"
docker service ls --format "table {{.Name}}\t{{.Replicas}}\t{{.Ports}}"
echo ""
echo "⚠️ IMPORTANTE:"
echo "   • Aguarde 2-3 minutos para SSL ser gerado"
echo "   • Todos os domínios devem apontar para: $endereco_ip"
echo "   • Portas 80 e 443 devem estar abertas"
echo "   • Se Evolution API demorar, é normal - aguarde até 5 minutos"
echo ""
echo "🔧 COMANDOS ÚTEIS:"
echo "   • Ver todos os containers: docker ps"
echo "   • Ver logs Evolution: docker service logs evolution_evolution-api --follow"
echo "   • Reiniciar Evolution: docker service update --force evolution_evolution-api"
echo "   • Status serviços: docker service ls"
echo "   • Ver stacks: docker stack ls"
echo ""
echo "======================================="
if [ "$all_services_ok" = true ]; then
    echo "🎊 PARABÉNS! TUDO FUNCIONANDO PERFEITAMENTE!"
    echo "✅ ACESSE OS LINKS ACIMA PARA USAR SUAS APLICAÇÕES"
else
    echo "⚠️ ALGUNS SERVIÇOS PRECISAM DE ATENÇÃO"
    echo "📞 Verifique os logs para resolver problemas pendentes"
fi
echo "======================================="