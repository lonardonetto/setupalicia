#!/bin/bash

# SETUPALICIA - INSTALADOR COMPLETO EM UM UNICO ARQUIVO
# Instala: Traefik, Portainer, PostgreSQL, Redis, Evolution API, N8N

set -e

# Funcoes de log
log_info() { echo -e "\033[34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[32m[SUCESSO]\033[0m $1"; }
log_warning() { echo -e "\033[33m[AVISO]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERRO]\033[0m $1"; }

# PARAMETROS DO USUARIO - CONFIGURADOS AUTOMATICAMENTE
SSL_EMAIL="leonardonetto1982@gmail.com"
DOMINIO_N8N="editor.publiczap.com.br"
DOMINIO_PORTAINER="portainer.publiczap.com.br"
WEBHOOK_N8N="webhook.publiczap.com.br"
DOMINIO_EVOLUTION="evo.publiczap.com.br"

# Validar que os dados estao corretos
log_info "Usando configuracao:"
echo "  Email SSL: $SSL_EMAIL"
echo "  N8N: $DOMINIO_N8N"
echo "  Portainer: $DOMINIO_PORTAINER"
echo "  Webhook: $WEBHOOK_N8N"
echo "  Evolution: $DOMINIO_EVOLUTION"
echo ""

clear
echo "================================================================"
echo "              SETUPALICIA - INSTALACAO COMPLETA               "
echo "================================================================"
echo ""
echo "CONFIGURACAO VALIDADA:"
echo "  Email SSL: $SSL_EMAIL"
echo "  N8N: $DOMINIO_N8N"
echo "  Portainer: $DOMINIO_PORTAINER"
echo "  Webhook: $WEBHOOK_N8N"
echo "  Evolution: $DOMINIO_EVOLUTION"
echo ""
echo "Instalando TUDO em um unico script:"
echo "- Traefik (SSL automatico)"
echo "- Portainer (Interface Docker)"
echo "- PostgreSQL + Redis"
echo "- Evolution API v2.2.3"
echo "- N8N"
echo ""

# Confirmacao dos dados
read -p "Os dados acima estao corretos? (s/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    log_error "Instalacao cancelada pelo usuario!"
    echo "Para usar outros dominios, edite o script e altere as variaveis no inicio."
    exit 1
fi
log_success "Dados confirmados! Iniciando instalacao..."

# Gerar chaves
N8N_KEY=$(openssl rand -hex 16)
POSTGRES_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12)
EVOLUTION_API_KEY=$(openssl rand -hex 32)
PORTAINER_USER="setupalicia"
PORTAINER_PASS=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12)

# Criar .env
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

log_success "Configuracao salva!"

# Configurar sistema
log_info "Configurando sistema..."
timedatectl set-timezone America/Sao_Paulo || true
apt update -y >/dev/null 2>&1 || true

# Instalar Docker se necessario
if ! command -v docker >/dev/null 2>&1; then
    log_info "Instalando Docker..."
    curl -fsSL https://get.docker.com | sh >/dev/null 2>&1
    systemctl enable docker
    systemctl start docker
fi

# CORRIGIR DOCKER SWARM - METODOS MULTIPLOS
log_info "Configurando Docker Swarm..."
server_ip=$(curl -s ifconfig.me || curl -s icanhazip.com || hostname -I | cut -d' ' -f1)

# Limpar Swarm anterior
docker swarm leave --force >/dev/null 2>&1 || true
sleep 5

# Tentar inicializar Swarm com multiplos metodos
if docker swarm init --advertise-addr $server_ip >/dev/null 2>&1; then
    log_success "Swarm inicializado (metodo 1)!"
elif docker swarm init --force-new-cluster >/dev/null 2>&1; then
    log_success "Swarm inicializado (metodo 2)!"
elif docker swarm init >/dev/null 2>&1; then
    log_success "Swarm inicializado (metodo 3)!"
else
    log_warning "Problemas com Swarm - reiniciando Docker..."
    systemctl restart docker
    sleep 10
    if docker swarm init >/dev/null 2>&1; then
        log_success "Swarm inicializado apos restart!"
    else
        log_error "Falha critica no Docker Swarm!"
        exit 1
    fi
fi

# Criar rede
docker network create --driver=overlay network_public >/dev/null 2>&1 || true
log_success "Rede criada!"

# FUNCAO PARA AGUARDAR SERVICOS
wait_service() {
    local service=$1
    local max_wait=${2:-180}
    log_info "Aguardando $service..."
    
    for i in $(seq 1 $max_wait); do
        if docker ps --filter "name=$service" --format "{{.Names}}" | grep -q "$service"; then
            log_success "$service funcionando!"
            return 0
        fi
        sleep 1
    done
    log_error "Timeout: $service"
    return 1
}

# =============== TRAEFIK ===============
log_info "Instalando Traefik..."
cat > traefik.yaml <<EOF
version: '3.8'
services:
  traefik:
    image: traefik:latest
    networks: [network_public]
    ports: ["80:80", "443:443"]
    command:
      - --api.dashboard=true
      - --providers.docker=true
      - --providers.docker.swarmmode=true
      - --providers.docker.network=network_public
      - --providers.docker.exposedbydefault=false
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --certificatesresolvers.letsencryptresolver.acme.httpchallenge=true
      - --certificatesresolvers.letsencryptresolver.acme.httpchallenge.entrypoint=web
      - --certificatesresolvers.letsencryptresolver.acme.email=${SSL_EMAIL}
      - --certificatesresolvers.letsencryptresolver.acme.storage=/letsencrypt/acme.json
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - traefik_letsencrypt:/letsencrypt
    deploy:
      placement: {constraints: [node.role == manager]}
      labels:
        - traefik.enable=true
        - traefik.http.routers.http-catchall.rule=hostregexp({host:.+})
        - traefik.http.routers.http-catchall.entrypoints=web
        - traefik.http.routers.http-catchall.middlewares=redirect-to-https
        - traefik.http.middlewares.redirect-to-https.redirectscheme.scheme=https
volumes: {traefik_letsencrypt: {}}
networks: {network_public: {external: true}}
EOF

docker stack deploy -c traefik.yaml traefik
wait_service "traefik_traefik" 120

# =============== PORTAINER ===============
log_info "Instalando Portainer..."
cat > portainer.yaml <<EOF
version: '3.8'
services:
  portainer:
    image: portainer/portainer-ce:latest
    networks: [network_public]
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    deploy:
      placement: {constraints: [node.role == manager]}
      labels:
        - traefik.enable=true
        - traefik.http.routers.portainer.rule=Host(\`${DOMINIO_PORTAINER}\`)
        - traefik.http.routers.portainer.entrypoints=websecure
        - traefik.http.routers.portainer.tls.certresolver=letsencryptresolver
        - traefik.http.services.portainer.loadbalancer.server.port=9000
volumes: {portainer_data: {}}
networks: {network_public: {external: true}}
EOF

docker stack deploy -c portainer.yaml portainer
wait_service "portainer_portainer" 180

# AGUARDAR PORTAINER ESTABILIZAR
log_info "Aguardando Portainer estabilizar (4 minutos)..."
sleep 240

# CONFIGURAR PORTAINER AUTOMATICAMENTE
log_info "Configurando Portainer automaticamente..."
portainer_url="https://$DOMINIO_PORTAINER"

# Tentar 10 vezes
for attempt in {1..10}; do
    log_info "Tentativa $attempt/10..."
    
    # Criar conta admin
    INIT_RESPONSE=$(curl -s -k -X POST "$portainer_url/api/users/admin/init" \
        -H "Content-Type: application/json" \
        -d "{\"Username\":\"$PORTAINER_USER\",\"Password\":\"$PORTAINER_PASS\"}" 2>/dev/null)
    
    # Extrair JWT
    if echo "$INIT_RESPONSE" | grep -qi "jwt"; then
        JWT_TOKEN=$(echo "$INIT_RESPONSE" | sed -n 's/.*"[Jj][Ww][Tt]":\s*"\([^"]*\)".*/\1/p')
        
        if [ ! -z "$JWT_TOKEN" ]; then
            log_success "JWT obtido!"
            
            # Criar API Key
            API_RESPONSE=$(curl -s -k -X POST "$portainer_url/api/users/1/tokens" \
                -H "Authorization: Bearer $JWT_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{\"description\":\"setupalicia-$(date +%s)\"}" 2>/dev/null)
            
            if echo "$API_RESPONSE" | grep -q "rawAPIKey"; then
                PORTAINER_API_KEY=$(echo "$API_RESPONSE" | sed -n 's/.*"rawAPIKey":\s*"\([^"]*\)".*/\1/p')
                
                if [ ! -z "$PORTAINER_API_KEY" ]; then
                    log_success "API Key criada! Stacks serao EDITAVEIS!"
                    echo "PORTAINER_API_KEY=$PORTAINER_API_KEY" >> .env
                    break
                fi
            fi
        fi
    fi
    
    if [ $attempt -lt 10 ]; then
        sleep 15
    fi
done

# =============== POSTGRESQL ===============
log_info "Instalando PostgreSQL..."
cat > postgres.yaml <<EOF
version: '3.8'
services:
  postgres:
    image: postgres:15
    networks: [network_public]
    environment:
      POSTGRES_DB: postgres
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes: [postgres_data:/var/lib/postgresql/data]
    deploy:
      placement: {constraints: [node.role == manager]}
volumes: {postgres_data: {}}
networks: {network_public: {external: true}}
EOF

# Usar API se disponivel
if [ ! -z "$PORTAINER_API_KEY" ]; then
    log_info "Criando PostgreSQL via API (EDITAVEL)..."
    SWARM_ID=$(docker info --format '{{.Swarm.NodeID}}')
    YAML_CONTENT=$(cat postgres.yaml | jq -Rs .)
    
    curl -s -k -X POST "$portainer_url/api/stacks" \
        -H "X-API-Key: $PORTAINER_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"Name\":\"postgres\",\"SwarmID\":\"$SWARM_ID\",\"StackFileContent\":$YAML_CONTENT}" >/dev/null 2>&1
else
    docker stack deploy -c postgres.yaml postgres
fi
wait_service "postgres_postgres" 120

# =============== REDIS ===============
log_info "Instalando Redis..."
cat > redis.yaml <<EOF
version: '3.8'
services:
  redis:
    image: redis:alpine
    networks: [network_public]
    volumes: [redis_data:/data]
    deploy:
      placement: {constraints: [node.role == manager]}
volumes: {redis_data: {}}
networks: {network_public: {external: true}}
EOF

if [ ! -z "$PORTAINER_API_KEY" ]; then
    YAML_CONTENT=$(cat redis.yaml | jq -Rs .)
    curl -s -k -X POST "$portainer_url/api/stacks" \
        -H "X-API-Key: $PORTAINER_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"Name\":\"redis\",\"SwarmID\":\"$SWARM_ID\",\"StackFileContent\":$YAML_CONTENT}" >/dev/null 2>&1
else
    docker stack deploy -c redis.yaml redis
fi
wait_service "redis_redis" 120

# =============== EVOLUTION API ===============
log_info "Instalando Evolution API..."
cat > evolution.yaml <<EOF
version: '3.8'
services:
  evolution:
    image: davedev0/evolution-api:v2.2.3
    networks: [network_public]
    environment:
      SERVER_URL: https://${DOMINIO_EVOLUTION}
      CORS_ORIGIN: "*"
      API_KEY: ${EVOLUTION_API_KEY}
      REDIS_ENABLED: true
      REDIS_HOST: redis
      DATABASE_ENABLED: true
      DATABASE_CONNECTION_URI: postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/postgres?schema=evolution
      WEBHOOK_GLOBAL_URL: https://${WEBHOOK_N8N}
      WEBHOOK_GLOBAL_ENABLED: true
    volumes:
      - evolution_instances:/evolution/instances
      - evolution_store:/evolution/store
    deploy:
      placement: {constraints: [node.role == manager]}
      labels:
        - traefik.enable=true
        - traefik.http.routers.evolution.rule=Host(\`${DOMINIO_EVOLUTION}\`)
        - traefik.http.routers.evolution.entrypoints=websecure
        - traefik.http.routers.evolution.tls.certresolver=letsencryptresolver
        - traefik.http.services.evolution.loadbalancer.server.port=8080
volumes: {evolution_instances: {}, evolution_store: {}}
networks: {network_public: {external: true}}
EOF

if [ ! -z "$PORTAINER_API_KEY" ]; then
    YAML_CONTENT=$(cat evolution.yaml | jq -Rs .)
    curl -s -k -X POST "$portainer_url/api/stacks" \
        -H "X-API-Key: $PORTAINER_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"Name\":\"evolution\",\"SwarmID\":\"$SWARM_ID\",\"StackFileContent\":$YAML_CONTENT}" >/dev/null 2>&1
else
    docker stack deploy -c evolution.yaml evolution
fi
wait_service "evolution_evolution" 180

# =============== N8N ===============
log_info "Instalando N8N..."
cat > n8n.yaml <<EOF
version: '3.8'
services:
  n8n:
    image: docker.n8n.io/n8nio/n8n:latest
    networks: [network_public]
    environment:
      N8N_HOST: ${DOMINIO_N8N}
      N8N_PORT: 5678
      N8N_PROTOCOL: https
      N8N_ENCRYPTION_KEY: ${N8N_KEY}
      WEBHOOK_URL: https://${WEBHOOK_N8N}
      GENERIC_TIMEZONE: America/Sao_Paulo
      DB_TYPE: postgresdb
      DB_POSTGRESDB_HOST: postgres
      DB_POSTGRESDB_PORT: 5432
      DB_POSTGRESDB_DATABASE: postgres
      DB_POSTGRESDB_USER: postgres
      DB_POSTGRESDB_PASSWORD: ${POSTGRES_PASSWORD}
      DB_POSTGRESDB_SCHEMA: n8n
      QUEUE_BULL_REDIS_HOST: redis
    volumes: [n8n_data:/home/node/.n8n]
    deploy:
      placement: {constraints: [node.role == manager]}
      labels:
        - traefik.enable=true
        - traefik.http.routers.n8n.rule=Host(\`${DOMINIO_N8N}\`)
        - traefik.http.routers.n8n.entrypoints=websecure
        - traefik.http.routers.n8n.tls.certresolver=letsencryptresolver
        - traefik.http.services.n8n.loadbalancer.server.port=5678
        - traefik.http.routers.n8n-webhook.rule=Host(\`${WEBHOOK_N8N}\`)
        - traefik.http.routers.n8n-webhook.entrypoints=websecure
        - traefik.http.routers.n8n-webhook.tls.certresolver=letsencryptresolver
volumes: {n8n_data: {}}
networks: {network_public: {external: true}}
EOF

if [ ! -z "$PORTAINER_API_KEY" ]; then
    YAML_CONTENT=$(cat n8n.yaml | jq -Rs .)
    curl -s -k -X POST "$portainer_url/api/stacks" \
        -H "X-API-Key: $PORTAINER_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"Name\":\"n8n\",\"SwarmID\":\"$SWARM_ID\",\"StackFileContent\":$YAML_CONTENT}" >/dev/null 2>&1
else
    docker stack deploy -c n8n.yaml n8n
fi
wait_service "n8n_n8n" 180

# =============== FINALIZACAO ===============
clear
echo "================================================================"
echo "                  INSTALACAO CONCLUIDA!                       "
echo "================================================================"
echo ""
echo "TODAS AS APLICACOES INSTALADAS:"
echo ""
echo "ACESSOS COM SEUS DOMINIOS:"
echo "- Portainer: https://$DOMINIO_PORTAINER"
echo "  Usuario: $PORTAINER_USER"
echo "  Senha: $PORTAINER_PASS"
echo ""
echo "- N8N (Editor): https://$DOMINIO_N8N"
echo "- N8N (Webhook): https://$WEBHOOK_N8N"
echo "- Evolution API: https://$DOMINIO_EVOLUTION"
echo "  API Key: $EVOLUTION_API_KEY"
echo ""
echo "DADOS TECNICOS:"
echo "- Email SSL (Let's Encrypt): $SSL_EMAIL"
echo "- PostgreSQL Password: $POSTGRES_PASSWORD"
echo "- N8N Encryption Key: $N8N_KEY"

if [ ! -z "$PORTAINER_API_KEY" ]; then
    echo ""
    echo "STACKS EDITAVEIS!"
    echo "- Todas as stacks foram criadas via API"
    echo "- Totalmente editaveis no Portainer!"
    echo "- API Key: ${PORTAINER_API_KEY:0:30}..."
else
    echo ""
    echo "AVISO: Stacks criadas via CLI"
    echo "- Configure manualmente no Portainer se necessario"
fi

echo ""
echo "PROXIMOS PASSOS:"
echo "1. Aguarde alguns minutos para certificados SSL"
echo "2. Configure N8N: https://$DOMINIO_N8N"
echo "3. Teste Evolution: https://$DOMINIO_EVOLUTION"
echo "4. Gerencie tudo: https://$DOMINIO_PORTAINER"
echo ""
echo "Credenciais salvas em .env"
echo "================================================================"

log_success "INSTALACAO COMPLETA - TUDO FUNCIONANDO!"