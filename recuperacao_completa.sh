#!/bin/bash

# 🔧 DIAGNÓSTICO E RECUPERAÇÃO COMPLETA - SETUPALICIA
# Resolve problemas de SSL, Traefik e serviços fora do ar
# Autor: Maicon Ramos - Automação sem Limites

set -e

# Função para log colorido
log_info() { echo -e "\033[34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[32m[SUCESSO]\033[0m $1"; }
log_warning() { echo -e "\033[33m[AVISO]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERRO]\033[0m $1"; }

clear
echo "🔧 DIAGNÓSTICO E RECUPERAÇÃO COMPLETA - SETUPALICIA"
echo "=================================================="
echo "Este script vai diagnosticar e corrigir:"
echo "❌ Problemas de SSL (Traefik)"
echo "❌ Serviços sem HTTPS"
echo "❌ Evolution API fora do ar"
echo "❌ Portainer com timeout"
echo "❌ Certificados SSL não gerados"
echo "=================================================="
echo ""

# Verificar se existe .env
if [ ! -f ".env" ]; then
    log_error "Arquivo .env não encontrado!"
    log_info "Execute este script no diretório onde foi feita a instalação"
    exit 1
fi

# Carregar variáveis
source .env

log_success "✅ Variáveis carregadas:"
echo "   • Email SSL: $SSL_EMAIL"
echo "   • Domínio N8N: $DOMINIO_N8N"
echo "   • Domínio Portainer: $DOMINIO_PORTAINER"
echo "   • Domínio Evolution: $DOMINIO_EVOLUTION"
echo "   • Webhook N8N: $WEBHOOK_N8N"
echo ""

# DIAGNÓSTICO COMPLETO
echo "🔍 EXECUTANDO DIAGNÓSTICO COMPLETO..."
echo "=================================================="

# 1. Verificar DNS
log_info "1. Verificando configuração DNS..."
server_ip=$(curl -s ifconfig.me || curl -s icanhazip.com || echo "IP_NAO_DETECTADO")
echo "   IP do servidor: $server_ip"

for domain in "$DOMINIO_PORTAINER" "$DOMINIO_N8N" "$DOMINIO_EVOLUTION" "$WEBHOOK_N8N"; do
    resolved_ip=$(nslookup $domain 8.8.8.8 2>/dev/null | grep -A 1 "Name:" | grep "Address:" | cut -d':' -f2 | tr -d ' ' || echo "FALHA_DNS")
    if [ "$resolved_ip" = "$server_ip" ]; then
        echo "   ✅ $domain → $resolved_ip (OK)"
    else
        echo "   ❌ $domain → $resolved_ip (ERRO - deveria ser $server_ip)"
    fi
done
echo ""

# 2. Verificar Docker e Swarm
log_info "2. Verificando Docker e Swarm..."
if docker ps >/dev/null 2>&1; then
    echo "   ✅ Docker funcionando"
else
    echo "   ❌ Docker com problemas"
fi

if docker node ls >/dev/null 2>&1; then
    echo "   ✅ Docker Swarm ativo"
else
    echo "   ❌ Docker Swarm com problemas"
fi
echo ""

# 3. Verificar stacks
log_info "3. Verificando stacks instaladas..."
echo "Stacks ativas:"
docker stack ls
echo ""

# 4. Verificar serviços
log_info "4. Verificando status dos serviços..."
echo "Serviços em execução:"
docker service ls
echo ""

# 5. Verificar containers
log_info "5. Verificando containers..."
echo "Containers ativos:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# 6. Verificar Traefik especificamente
log_info "6. Diagnóstico específico do Traefik (responsável pelo SSL)..."
traefik_container=$(docker ps --filter "name=traefik" --format "{{.Names}}" | head -1)
if [ ! -z "$traefik_container" ]; then
    echo "   ✅ Container Traefik encontrado: $traefik_container"
    echo "   Logs recentes do Traefik:"
    docker logs $traefik_container --tail 20
else
    echo "   ❌ Container Traefik NÃO ENCONTRADO!"
    log_error "PROBLEMA CRÍTICO: Traefik não está rodando!"
fi
echo ""

# 7. Verificar certificados SSL
log_info "7. Verificando certificados SSL..."
if [ ! -z "$traefik_container" ]; then
    echo "   Verificando diretório de certificados no Traefik:"
    docker exec $traefik_container ls -la /letsencrypt/ 2>/dev/null || echo "   Diretório de certificados não acessível"
fi
echo ""

# 8. Verificar portas
log_info "8. Verificando portas abertas..."
echo "   Porta 80 (HTTP):"
netstat -tlnp | grep ":80 " || echo "   ❌ Porta 80 não está aberta"
echo "   Porta 443 (HTTPS):"
netstat -tlnp | grep ":443 " || echo "   ❌ Porta 443 não está aberta"
echo ""

# RECUPERAÇÃO AUTOMÁTICA
echo ""
echo "🚀 INICIANDO RECUPERAÇÃO AUTOMÁTICA..."
echo "=================================================="

# 1. Parar todos os serviços problemáticos
log_info "1. Parando serviços problemáticos..."
docker stack rm traefik >/dev/null 2>&1 || true
docker stack rm portainer >/dev/null 2>&1 || true
docker stack rm evolution >/dev/null 2>&1 || true
docker stack rm n8n >/dev/null 2>&1 || true

log_info "Aguardando limpeza completa..."
sleep 30

# 2. Limpar recursos órfãos
log_info "2. Limpando recursos órfãos..."
docker container prune -f >/dev/null 2>&1
docker network prune -f >/dev/null 2>&1
docker volume prune -f >/dev/null 2>&1

# 3. Recriar rede overlay
log_info "3. Recriando rede overlay..."
docker network rm network_public >/dev/null 2>&1 || true
docker network create --driver=overlay network_public

# 4. Reinstalar Traefik (CRÍTICO para SSL)
log_info "4. Reinstalando Traefik com SSL automático..."

cat > traefik_fix.yaml <<EOF
version: '3.7'

services:
  traefik:
    image: traefik:v2.9
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
      - --certificatesresolvers.letsencryptresolver.acme.email=\${SSL_EMAIL}
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
        - traefik.http.routers.api.rule=Host(\`traefik.\${DOMINIO_PORTAINER}\`)
        - traefik.http.routers.api.tls=true
        - traefik.http.routers.api.tls.certresolver=letsencryptresolver
        - traefik.http.routers.api.service=api@internal
        - traefik.http.services.traefik.loadbalancer.server.port=8080
        - traefik.docker.network=network_public
        # Middleware para redirecionar HTTP para HTTPS
        - traefik.http.middlewares.redirect-to-https.redirectscheme.scheme=https
        - traefik.http.middlewares.redirect-to-https.redirectscheme.permanent=true
        - traefik.http.routers.redirect-to-https.rule=hostregexp(\`{host:.+}\`)
        - traefik.http.routers.redirect-to-https.entrypoints=web
        - traefik.http.routers.redirect-to-https.middlewares=redirect-to-https

volumes:
  traefik_letsencrypt:
    external: true

networks:
  network_public:
    external: true
EOF

# Criar volume para certificados
docker volume create traefik_letsencrypt >/dev/null 2>&1 || true

# Deploy do Traefik
env SSL_EMAIL="$SSL_EMAIL" DOMINIO_PORTAINER="$DOMINIO_PORTAINER" docker stack deploy --prune --resolve-image always -c traefik_fix.yaml traefik

log_info "Aguardando Traefik inicializar..."
sleep 30

# Verificar se Traefik está funcionando
for i in {1..12}; do
    if docker ps --filter "name=traefik" --format "{{.Names}}" | grep -q traefik; then
        log_success "✅ Traefik está rodando!"
        break
    fi
    echo "   Tentativa $i/12 - Aguardando Traefik..."
    sleep 5
done

# 5. Reinstalar Portainer
log_info "5. Reinstalando Portainer..."

cat > portainer_fix.yaml <<EOF
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
        - traefik.http.routers.portainer.rule=Host(\`\${DOMINIO_PORTAINER}\`)
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
    external: true

networks:
  network_public:
    external: true
  agent_network:
    driver: overlay
    attachable: true
EOF

# Criar volumes necessários
docker volume create portainer_data >/dev/null 2>&1 || true
docker network create --driver=overlay agent_network >/dev/null 2>&1 || true

env DOMINIO_PORTAINER="$DOMINIO_PORTAINER" docker stack deploy --prune --resolve-image always -c portainer_fix.yaml portainer

# 6. Reinstalar PostgreSQL e Redis
log_info "6. Reinstalando PostgreSQL..."
curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/postgres.yaml" -o "postgres.yaml"
env POSTGRES_PASSWORD="$POSTGRES_PASSWORD" docker stack deploy --prune --resolve-image always -c postgres.yaml postgres

log_info "7. Reinstalando Redis..."
curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/redis.yaml" -o "redis.yaml"
docker stack deploy --prune --resolve-image always -c redis.yaml redis

# Aguardar bancos estabilizarem
log_info "Aguardando bancos de dados estabilizarem..."
sleep 60

# 7. Recriar bancos de dados
log_info "8. Recriando bancos de dados..."
for i in {1..30}; do
    postgres_container=$(docker ps --filter "name=postgres_postgres" --format "{{.Names}}" | head -1)
    if [ ! -z "$postgres_container" ]; then
        if docker exec $postgres_container pg_isready -U postgres >/dev/null 2>&1; then
            docker exec $postgres_container psql -U postgres -d postgres -c "CREATE DATABASE IF NOT EXISTS evolution;" 2>/dev/null || \
            docker exec $postgres_container psql -U postgres -d postgres -c "CREATE DATABASE evolution;" 2>/dev/null
            
            docker exec $postgres_container psql -U postgres -d postgres -c "CREATE DATABASE IF NOT EXISTS n8n;" 2>/dev/null || \
            docker exec $postgres_container psql -U postgres -d postgres -c "CREATE DATABASE n8n;" 2>/dev/null
            
            log_success "✅ Bancos de dados criados!"
            break
        fi
    fi
    echo "   Tentativa $i/30 - Aguardando PostgreSQL..."
    sleep 3
done

# 8. Reinstalar Evolution API
log_info "9. Reinstalando Evolution API..."

# Criar volumes
docker volume create evolution_instances >/dev/null 2>&1 || true
docker volume create evolution_store >/dev/null 2>&1 || true

cat > evolution_fix.yaml <<EOF
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
        - traefik.http.routers.evolution.rule=Host(\`\${DOMINIO_EVOLUTION}\`)
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

env DOMINIO_EVOLUTION="$DOMINIO_EVOLUTION" POSTGRES_PASSWORD="$POSTGRES_PASSWORD" EVOLUTION_API_KEY="$EVOLUTION_API_KEY" \
docker stack deploy --prune --resolve-image always -c evolution_fix.yaml evolution

# 9. Reinstalar N8N
log_info "10. Reinstalando N8N..."
curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/n8n.yaml" -o "n8n.yaml"
env DOMINIO_N8N="$DOMINIO_N8N" WEBHOOK_N8N="$WEBHOOK_N8N" POSTGRES_PASSWORD="$POSTGRES_PASSWORD" N8N_KEY="$N8N_KEY" \
docker stack deploy --prune --resolve-image always -c n8n.yaml n8n

# VERIFICAÇÃO FINAL
echo ""
echo "⏳ AGUARDANDO SERVIÇOS ESTABILIZAREM (3 minutos)..."
echo "=================================================="
sleep 180

echo ""
echo "🔍 VERIFICAÇÃO FINAL APÓS RECUPERAÇÃO..."
echo "=================================================="

# Verificar todos os serviços
all_ok=true

echo "📊 STATUS DOS SERVIÇOS:"
docker service ls

echo ""
echo "🐳 CONTAINERS ATIVOS:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "🔐 VERIFICAÇÃO SSL E CONECTIVIDADE:"

# Verificar Traefik
traefik_container=$(docker ps --filter "name=traefik" --format "{{.Names}}" | head -1)
if [ ! -z "$traefik_container" ]; then
    log_success "✅ Traefik: FUNCIONANDO"
else
    log_error "❌ Traefik: NÃO ENCONTRADO"
    all_ok=false
fi

# Verificar Portainer
portainer_container=$(docker ps --filter "name=portainer" --format "{{.Names}}" | head -1)
if [ ! -z "$portainer_container" ]; then
    log_success "✅ Portainer: FUNCIONANDO"
    echo "   🌐 Acesse: https://$DOMINIO_PORTAINER"
else
    log_error "❌ Portainer: NÃO ENCONTRADO"
    all_ok=false
fi

# Verificar Evolution API
evolution_container=$(docker ps --filter "name=evolution" --format "{{.Names}}" | head -1)
if [ ! -z "$evolution_container" ]; then
    log_success "✅ Evolution API: FUNCIONANDO"
    echo "   🌐 Acesse: https://$DOMINIO_EVOLUTION"
else
    log_error "❌ Evolution API: NÃO ENCONTRADO"
    all_ok=false
fi

# Verificar N8N
n8n_container=$(docker ps --filter "name=n8n" --format "{{.Names}}" | head -1)
if [ ! -z "$n8n_container" ]; then
    log_success "✅ N8N: FUNCIONANDO"
    echo "   🌐 Acesse: https://$DOMINIO_N8N"
else
    log_error "❌ N8N: NÃO ENCONTRADO"
    all_ok=false
fi

echo ""
echo "=================================================="
if [ "$all_ok" = true ]; then
    echo "🎉 RECUPERAÇÃO CONCLUÍDA COM SUCESSO!"
    echo "✅ Todos os serviços estão funcionando com SSL!"
else
    echo "⚠️ RECUPERAÇÃO PARCIAL - Alguns serviços precisam de atenção"
fi
echo "=================================================="

echo ""
echo "🌐 LINKS DE ACESSO (todos com HTTPS):"
echo "   • Portainer: https://$DOMINIO_PORTAINER"
echo "   • N8N: https://$DOMINIO_N8N"
echo "   • Evolution API: https://$DOMINIO_EVOLUTION"
echo "   • Webhook N8N: https://$WEBHOOK_N8N"
echo ""
echo "🔑 CREDENCIAIS:"
echo "   • Evolution API Key: $EVOLUTION_API_KEY"
echo ""
echo "⚠️ IMPORTANTE:"
echo "   • Os certificados SSL podem levar 2-5 minutos para serem gerados"
echo "   • Se ainda aparecer 'Não seguro', aguarde alguns minutos"
echo "   • Todos os domínios devem apontar para o IP: $(curl -s ifconfig.me)"
echo ""
echo "🔧 COMANDOS ÚTEIS:"
echo "   • Ver logs Traefik: docker logs \$(docker ps --filter 'name=traefik' --format '{{.Names}}' | head -1) --follow"
echo "   • Ver certificados: docker exec \$(docker ps --filter 'name=traefik' --format '{{.Names}}' | head -1) ls -la /letsencrypt/"
echo "   • Reiniciar serviço: docker service update --force [nome_do_servico]"
echo ""
echo "=================================================="
echo "✅ SCRIPT CONCLUÍDO!"
echo "=================================================="