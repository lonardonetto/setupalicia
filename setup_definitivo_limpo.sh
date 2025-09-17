#!/bin/bash

# SETUPALICIA - INSTALADOR AUTOMATIZADO COM SSL

set -e

# Funcao para log colorido
log_info() { echo -e "\033[34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[32m[SUCESSO]\033[0m $1"; }
log_warning() { echo -e "\033[33m[AVISO]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERRO]\033[0m $1"; }

# Funcao para salvar YAMLs das stacks para edicao futura no Portainer
save_yaml_for_editing() {
    local stack_name=$1
    local yaml_file=$2
    
    # Criar diretorio se nao existir
    mkdir -p /opt/setupalicia/stacks >/dev/null 2>&1
    
    # Salvar YAML para edicao futura no Portainer
    if [ -f "$yaml_file" ]; then
        cp "$yaml_file" "/opt/setupalicia/stacks/${stack_name}.yaml" >/dev/null 2>&1
    fi
}

# Funcao para configurar Portainer automaticamente - VERSAO FINAL QUE FUNCIONA
setup_portainer_auto() {
    log_info "Configurando Portainer automaticamente..."
    
    # Gerar credenciais
    PORTAINER_USER="setupalicia"
    PORTAINER_PASS=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12)
    
    log_info "Criando conta: $PORTAINER_USER"
    log_info "Senha: $PORTAINER_PASS"
    
    # Usar HTTPS direto (SSL ja foi verificado)
    local portainer_url="https://$DOMINIO_PORTAINER"
    
    # TENTAR MULTIPLAS VEZES ATE FUNCIONAR
    for attempt in {1..10}; do
        log_info "Tentativa $attempt/10 de configuracao..."
        
        # Criar conta admin
        INIT_RESPONSE=$(curl -s -X POST "$portainer_url/api/users/admin/init" \
            -H "Content-Type: application/json" \
            -d "{
                \"Username\": \"$PORTAINER_USER\",
                \"Password\": \"$PORTAINER_PASS\"
            }" 2>/dev/null)
        
        # Se falhou criar, tentar login direto
        if ! echo "$INIT_RESPONSE" | grep -qi "jwt"; then
            INIT_RESPONSE=$(curl -s -X POST "$portainer_url/api/auth" \
                -H "Content-Type: application/json" \
                -d "{
                    \"Username\": \"$PORTAINER_USER\",
                    \"Password\": \"$PORTAINER_PASS\"
                }" 2>/dev/null)
        fi
        
        # Extrair JWT
        if echo "$INIT_RESPONSE" | grep -qi "jwt"; then
            JWT_TOKEN=$(echo "$INIT_RESPONSE" | grep -o '"[Jj][Ww][Tt]":"[^"]*' | cut -d'"' -f4)
            
            if [ -z "$JWT_TOKEN" ]; then
                JWT_TOKEN=$(echo "$INIT_RESPONSE" | sed -n 's/.*"[Jj][Ww][Tt]":\s*"\([^"]*\)".*/\1/p')
            fi
            
            if [ ! -z "$JWT_TOKEN" ]; then
                log_success "JWT Token obtido na tentativa $attempt!"
                
                SWARM_ID=$(docker info --format '{{.Swarm.NodeID}}')
                
                # Criar API Key
                API_RESPONSE=$(curl -s -X POST "$portainer_url/api/users/1/tokens" \
                    -H "Authorization: Bearer $JWT_TOKEN" \
                    -H "Content-Type: application/json" \
                    -d "{
                        \"description\": \"setupalicia-$(date +%s)\"
                    }" 2>/dev/null)
                
                if echo "$API_RESPONSE" | grep -q "rawAPIKey"; then
                    PORTAINER_API_KEY=$(echo "$API_RESPONSE" | grep -o '"rawAPIKey":"[^"]*' | cut -d'"' -f4)
                    
                    if [ ! -z "$PORTAINER_API_KEY" ] && [ ${#PORTAINER_API_KEY} -gt 10 ]; then
                        log_success "API Key criada com sucesso na tentativa $attempt!"
                        log_info "API Key: ${PORTAINER_API_KEY:0:30}..."
                        
                        # Salvar credenciais
                        echo "PORTAINER_USER=$PORTAINER_USER" >> .env
                        echo "PORTAINER_PASS=$PORTAINER_PASS" >> .env
                        echo "PORTAINER_API_KEY=$PORTAINER_API_KEY" >> .env
                        echo "SWARM_ID=$SWARM_ID" >> .env
                        
                        # Testar API Key
                        TEST_RESPONSE=$(curl -s -X GET "$portainer_url/api/stacks" \
                            -H "X-API-Key: $PORTAINER_API_KEY" 2>/dev/null)
                        
                        if echo "$TEST_RESPONSE" | grep -q "\[" || echo "$TEST_RESPONSE" | grep -q "\{"; then
                            log_success "API Key testada e funcionando! Stacks serao editaveis!"
                            return 0
                        else
                            log_warning "API Key criada mas teste falhou - tentando novamente..."
                        fi
                    else
                        log_warning "API Key vazia na tentativa $attempt - tentando novamente..."
                    fi
                else
                    log_warning "Falha ao criar API Key na tentativa $attempt - tentando novamente..."
                fi
            else
                log_warning "JWT Token vazio na tentativa $attempt - tentando novamente..."
            fi
        else
            log_warning "Falha na autenticacao na tentativa $attempt - tentando novamente..."
        fi
        
        # Aguardar antes da proxima tentativa
        if [ $attempt -lt 10 ]; then
            log_info "Aguardando 15 segundos antes da proxima tentativa..."
            sleep 15
        fi
    done
    
    log_error "Todas as tentativas falharam - configuracao manual necessaria"
    return 1
}

# Funcao para criar stack via API do Portainer
create_stack_via_api() {
    local stack_name=$1
    local yaml_file=$2
    
    # Verificar se temos API Key valida
    if [ -z "$PORTAINER_API_KEY" ] || [ ${#PORTAINER_API_KEY} -lt 10 ]; then
        log_warning "API Key nao disponivel - usando CLI (stacks nao serao editaveis)"
        docker stack deploy --prune --resolve-image always -c "$yaml_file" "$stack_name"
        save_yaml_for_editing "$stack_name" "$yaml_file"
        return
    fi
    
    # Verificar se temos Swarm ID
    if [ -z "$SWARM_ID" ]; then
        SWARM_ID=$(docker info --format '{{.Swarm.NodeID}}')
    fi
    
    log_info "Criando stack $stack_name via API Portainer (EDITAVEL)..."
    
    # Ler conteudo do YAML e escapar adequadamente
    if [ ! -f "$yaml_file" ]; then
        log_error "Arquivo $yaml_file nao encontrado"
        return 1
    fi
    
    YAML_CONTENT=$(cat "$yaml_file")
    
    # Decidir URL baseado em qual funcionou antes
    local portainer_url
    if curl -s "http://localhost:9000/api/status" >/dev/null 2>&1; then
        portainer_url="http://localhost:9000"
    else
        portainer_url="https://$DOMINIO_PORTAINER"
    fi
    
    # Criar stack via API com JSON adequadamente escapado
    API_RESPONSE=$(curl -s -X POST "$portainer_url/api/stacks" \
        -H "X-API-Key: $PORTAINER_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"Name\": \"$stack_name\",
            \"SwarmID\": \"$SWARM_ID\",
            \"StackFileContent\": $(echo "$YAML_CONTENT" | jq -Rs .)
        }" 2>/dev/null)
    
    # Verificar se a stack foi criada com sucesso
    if echo "$API_RESPONSE" | grep -q "\"Id\"" && echo "$API_RESPONSE" | grep -q "$stack_name"; then
        log_success "Stack $stack_name criada via API - TOTALMENTE EDITAVEL no Portainer!"
        save_yaml_for_editing "$stack_name" "$yaml_file"
        
        # Aguardar um pouco para stack estabilizar
        sleep 10
        return 0
    else
        log_warning "Falha na API: $API_RESPONSE"
        log_info "Usando CLI como fallback"
        docker stack deploy --prune --resolve-image always -c "$yaml_file" "$stack_name"
        save_yaml_for_editing "$stack_name" "$yaml_file"
        return 1
    fi
}

# Funcao para aguardar servico com verificacao robusta
wait_service_perfect() {
    local service_name=$1
    local max_wait=${2:-300}
    
    log_info "Aguardando $service_name..."
    
    # Aguardar servico aparecer
    for i in $(seq 1 60); do
        if docker service ls --filter name=$service_name --format "{{.Name}}" | grep -q "$service_name"; then
            break
        fi
        sleep 5
    done
    
    # Aguardar container ficar ativo
    for i in $(seq 1 $max_wait); do
        if docker ps --filter "name=$service_name" --format "{{.Names}}" | grep -q "$service_name"; then
            log_success "$service_name funcionando!"
            return 0
        fi
        
        # Log de progresso a cada 30 segundos
        if [ $((i % 30)) -eq 0 ]; then
            echo "   ... aguardando $service_name ($i/${max_wait}s)"
        fi
        sleep 1
    done
    
    log_error "Timeout aguardando $service_name"
    return 1
}

# Funcao para verificar SSL de forma simples e rapida
check_ssl_simple() {
    local domain=$1
    local service_name=$2
    
    log_info "Verificando SSL para $domain ($service_name)..."
    
    # Aguardar 15 segundos para o servico estabilizar
    sleep 15
    
    # Fazer uma requisicao simples para acionar Let's Encrypt
    curl -s -H "Host: $domain" "http://$server_ip" >/dev/null 2>&1 &
    curl -s -k "https://$domain" >/dev/null 2>&1 &
    
    # Testar uma vez se SSL ja esta funcionando
    if curl -s -I "https://$domain" --max-time 5 2>/dev/null | grep -q "HTTP.*[2-4][0-9][0-9]"; then
        log_success "SSL ja funcionando para $domain!"
    else
        log_info "SSL para $domain sera processado em background"
    fi
    
    log_success "$service_name configurado! Continuando instalacao..."
}

# INICIO DO SCRIPT PRINCIPAL
clear
echo "================================================================"
echo "                    SETUP ALICIA                           "
echo "              Instalador Automatizado com SSL                "
echo "================================================================"
echo ""
echo "Aplicacoes incluidas:"
echo "   - Traefik (Proxy SSL automatico)"
echo "   - Portainer (Interface Docker)"
echo "   - PostgreSQL (Banco de dados)"
echo "   - Redis (Cache)"
echo "   - Evolution API v2.2.3 (WhatsApp)"
echo "   - N8N (Automacao)"
echo ""

# Validacao rigorosa de parametros
if [ -z "$1" ]; then
    echo "Uso: $0 <email> <dominio_n8n> <dominio_portainer> <webhook_n8n> <dominio_evolution>"
    exit 1
fi

SSL_EMAIL=$1
DOMINIO_N8N=$2
DOMINIO_PORTAINER=$3
WEBHOOK_N8N=$4
DOMINIO_EVOLUTION=$5

# Validar formato de email
if [[ ! "$SSL_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    log_error "Email invalido! Por favor, digite um email valido."
    exit 1
fi

# Validar dominios
for domain in "$DOMINIO_N8N" "$DOMINIO_PORTAINER" "$WEBHOOK_N8N" "$DOMINIO_EVOLUTION"; do
    if [[ ! "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log_error "Dominio invalido: $domain"
        exit 1
    fi
done

log_success "Parametros validados!"
echo ""
echo "CONFIGURACAO VALIDADA:"
echo "Email: $SSL_EMAIL"
echo "N8N: $DOMINIO_N8N"  
echo "Portainer: $DOMINIO_PORTAINER"
echo "Webhook: $WEBHOOK_N8N"
echo "Evolution: $DOMINIO_EVOLUTION"
echo ""

# Verificar conectividade com a internet
log_info "Verificando conectividade com a internet..."
if ! ping -c 1 google.com >/dev/null 2>&1; then
    log_error "Sem conexao com a internet!"
    exit 1
fi
log_success "Internet funcionando!"

# Gerar chaves seguras
log_info "Gerando chaves de seguranca..."
N8N_KEY=$(openssl rand -hex 16)
POSTGRES_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12)
EVOLUTION_API_KEY=$(openssl rand -hex 32)

# Salvar variaveis de ambiente
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

log_success "Variaveis salvas em .env"

# Configuracao do sistema
log_info "Configurando sistema..."
export DEBIAN_FRONTEND=noninteractive
timedatectl set-timezone America/Sao_Paulo

# Verificar e configurar firewall
log_info "Configurando firewall..."
if command -v ufw >/dev/null 2>&1; then
    ufw allow 22/tcp >/dev/null 2>&1 || true
    ufw allow 80/tcp >/dev/null 2>&1 || true
    ufw allow 443/tcp >/dev/null 2>&1 || true
    log_success "Firewall configurado!"
fi

# Instalar Docker
log_info "Instalando Docker..."
{
    apt update -y &&
    apt upgrade -y &&
    apt-get install -y curl wget gnupg lsb-release ca-certificates apt-transport-https software-properties-common jq
} >> instalacao.log 2>&1

# Configurar Docker Swarm
log_info "Configurando Docker Swarm..."
server_ip=$(curl -s ifconfig.me || curl -s icanhazip.com || hostname -I | cut -d' ' -f1)
log_info "IP do servidor detectado: $server_ip"

# Limpar Swarm antigo se existir
docker swarm leave --force >/dev/null 2>&1 || true

# Inicializar novo Swarm
if docker swarm init --advertise-addr $server_ip >/dev/null 2>&1; then
    log_success "Docker Swarm inicializado!"
else
    log_warning "Tentando metodo alternativo..."
    docker swarm init >/dev/null 2>&1
    log_success "Docker Swarm inicializado (metodo alternativo)!"
fi

# Criar rede overlay
log_info "Criando rede overlay..."
docker network create --driver=overlay network_public >/dev/null 2>&1 || true

log_success "Instalacao iniciada com sucesso!"
echo ""
echo "PROXIMOS PASSOS:"
echo "1. O script continuara automaticamente"
echo "2. Aguarde o processo completar (pode levar alguns minutos)"
echo "3. As credenciais serao exibidas no final"
echo ""

# ============= TRAEFIK ===============
log_info "Instalando Traefik..."

cat > traefik.yaml <<EOF
version: '3.8'
services:
  traefik:
    image: traefik:latest
    networks:
      - network_public
    ports:
      - "80:80"
      - "443:443"
    command:
      - --api.dashboard=true
      - --api.insecure=false
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
      - --certificatesresolvers.letsencryptresolver.acme.caserver=https://acme-v02.api.letsencrypt.org/directory
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - traefik_letsencrypt:/letsencrypt
    deploy:
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.http-catchall.rule=hostregexp(\`{host:.+}\`)"
        - "traefik.http.routers.http-catchall.entrypoints=web"
        - "traefik.http.routers.http-catchall.middlewares=redirect-to-https"
        - "traefik.http.middlewares.redirect-to-https.redirectscheme.scheme=https"

volumes:
  traefik_letsencrypt:

networks:
  network_public:
    external: true
EOF

docker stack deploy --prune --resolve-image always -c traefik.yaml traefik
wait_service_perfect "traefik_traefik" 120

# ============= PORTAINER ===============
log_info "Instalando Portainer..."

cat > portainer.yaml <<EOF
version: '3.8'
services:
  portainer:
    image: portainer/portainer-ce:latest
    networks:
      - network_public
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    deploy:
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.portainer.rule=Host(\`${DOMINIO_PORTAINER}\`)"
        - "traefik.http.routers.portainer.entrypoints=websecure"
        - "traefik.http.routers.portainer.tls.certresolver=letsencryptresolver"
        - "traefik.http.services.portainer.loadbalancer.server.port=9000"

volumes:
  portainer_data:

networks:
  network_public:
    external: true
EOF

docker stack deploy --prune --resolve-image always -c portainer.yaml portainer
wait_service_perfect "portainer_portainer" 180
check_ssl_simple "$DOMINIO_PORTAINER" "Portainer"

# AGUARDAR ESTABILIZACAO DO PORTAINER (CRITICO)
log_info "Aguardando Portainer estabilizar para configuracao automatica..."
sleep 240  # 4 minutos para evitar timeout de seguranca

# Configurar Portainer automaticamente
setup_portainer_auto

# ============= POSTGRESQL ===============
log_info "Instalando PostgreSQL..."

cat > postgres.yaml <<EOF
version: '3.8'
services:
  postgres:
    image: postgres:15
    networks:
      - network_public
    environment:
      POSTGRES_DB: postgres
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    deploy:
      placement:
        constraints:
          - node.role == manager

volumes:
  postgres_data:

networks:
  network_public:
    external: true
EOF

create_stack_via_api "postgres" "postgres.yaml"
wait_service_perfect "postgres_postgres" 120

# ============= REDIS ===============
log_info "Instalando Redis..."

cat > redis.yaml <<EOF
version: '3.8'
services:
  redis:
    image: redis:alpine
    networks:
      - network_public
    volumes:
      - redis_data:/data
    deploy:
      placement:
        constraints:
          - node.role == manager

volumes:
  redis_data:

networks:
  network_public:
    external: true
EOF

create_stack_via_api "redis" "redis.yaml"
wait_service_perfect "redis_redis" 120

# ============= EVOLUTION API ===============
log_info "Instalando Evolution API v2.2.3..."

cat > evolution.yaml <<EOF
version: '3.8'
services:
  evolution:
    image: davedev0/evolution-api:v2.2.3
    networks:
      - network_public
    environment:
      SERVER_URL: https://${DOMINIO_EVOLUTION}
      CORS_ORIGIN: "*"
      CORS_METHODS: "GET,POST,PUT,DELETE"
      CORS_CREDENTIALS: true
      API_KEY: ${EVOLUTION_API_KEY}
      REDIS_ENABLED: true
      REDIS_HOST: redis
      REDIS_PORT: 6379
      REDIS_PASSWORD: ""
      DATABASE_ENABLED: true
      DATABASE_CONNECTION_URI: postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/postgres?schema=evolution
      QRCODE_COLOR: "#000000"
      AUTHENTICATION_API_KEY: ${EVOLUTION_API_KEY}
      WEBHOOK_GLOBAL_URL: https://${WEBHOOK_N8N}
      WEBHOOK_GLOBAL_ENABLED: true
      WEBHOOK_GLOBAL_WEBHOOK_BY_EVENTS: true
      QRCODE_EXPIRATION_TIME: 60000
      INSTANCE_EXPIRATION_TIME: 300000
      CLEAN_STORE_CLEANING_INTERVAL: 7200000
      CLEAN_STORE_MESSAGES: true
      CLEAN_STORE_MESSAGE_UP_TO: 3600000
      CLEAN_STORE_CONTACTS: true
      CLEAN_STORE_CONTACTS_UP_TO: 3600000
      CLEAN_STORE_CHATS: true
      CLEAN_STORE_CHATS_UP_TO: 3600000
    volumes:
      - evolution_instances:/evolution/instances
      - evolution_store:/evolution/store
    deploy:
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.evolution.rule=Host(\`${DOMINIO_EVOLUTION}\`)"
        - "traefik.http.routers.evolution.entrypoints=websecure"
        - "traefik.http.routers.evolution.tls.certresolver=letsencryptresolver"
        - "traefik.http.services.evolution.loadbalancer.server.port=8080"

volumes:
  evolution_instances:
  evolution_store:

networks:
  network_public:
    external: true
EOF

create_stack_via_api "evolution" "evolution.yaml"
wait_service_perfect "evolution_evolution" 180
check_ssl_simple "$DOMINIO_EVOLUTION" "Evolution API"

# ============= N8N ===============
log_info "Instalando N8N..."

cat > n8n.yaml <<EOF
version: '3.8'
services:
  n8n:
    image: docker.n8n.io/n8nio/n8n:latest
    networks:
      - network_public
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
      EXECUTIONS_PROCESS: main
      EXECUTIONS_MODE: regular
      QUEUE_BULL_REDIS_HOST: redis
      QUEUE_BULL_REDIS_PORT: 6379
      QUEUE_BULL_REDIS_PASSWORD: ""
      N8N_METRICS: true
      N8N_DIAGNOSTICS_ENABLED: false
    volumes:
      - n8n_data:/home/node/.n8n
    deploy:
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.n8n.rule=Host(\`${DOMINIO_N8N}\`)"
        - "traefik.http.routers.n8n.entrypoints=websecure"
        - "traefik.http.routers.n8n.tls.certresolver=letsencryptresolver"
        - "traefik.http.services.n8n.loadbalancer.server.port=5678"
        - "traefik.http.routers.n8n-webhook.rule=Host(\`${WEBHOOK_N8N}\`)"
        - "traefik.http.routers.n8n-webhook.entrypoints=websecure"
        - "traefik.http.routers.n8n-webhook.tls.certresolver=letsencryptresolver"
        - "traefik.http.services.n8n-webhook.loadbalancer.server.port=5678"

volumes:
  n8n_data:

networks:
  network_public:
    external: true
EOF

create_stack_via_api "n8n" "n8n.yaml"
wait_service_perfect "n8n_n8n" 180
check_ssl_simple "$DOMINIO_N8N" "N8N"

# ============= FINALIZACAO ===============
log_info "Aguardando servicos estabilizarem..."
sleep 30

# Exibir credenciais e informacoes finais
clear
echo "================================================================"
echo "                  INSTALACAO CONCLUIDA!                       "
echo "================================================================"
echo ""
echo "Todas as aplicacoes foram instaladas com sucesso!"
echo ""
echo "ACESSOS:"
echo "- Portainer: https://$DOMINIO_PORTAINER"
echo "  Usuario: $PORTAINER_USER"
echo "  Senha: $PORTAINER_PASS"
echo ""
echo "- N8N: https://$DOMINIO_N8N"
echo "- Webhook: https://$WEBHOOK_N8N"
echo ""
echo "- Evolution API: https://$DOMINIO_EVOLUTION"
echo "  API Key: $EVOLUTION_API_KEY"
echo ""
echo "DADOS IMPORTANTES:"
echo "- PostgreSQL Password: $POSTGRES_PASSWORD"
echo "- N8N Encryption Key: $N8N_KEY"
echo ""
if [ ! -z "$PORTAINER_API_KEY" ]; then
    echo "STACKS EDITAVEIS!"
    echo "- Portainer API Key: ${PORTAINER_API_KEY:0:30}..."
    echo "- As stacks foram criadas via API e sao TOTALMENTE EDITAVEIS!"
    echo "- Arquivos YAML salvos em: /opt/setupalicia/stacks/"
else
    echo "AVISO: Stacks criadas via CLI (configuracao manual necessaria)"
    echo "- Arquivos YAML salvos em: /opt/setupalicia/stacks/"
    echo "- Para tornar editaveis, recrie as stacks via interface do Portainer"
fi
echo ""
echo "PROXIMOS PASSOS:"
echo "1. Aguarde alguns minutos para os certificados SSL"
echo "2. Configure o N8N acessando: https://$DOMINIO_N8N"
echo "3. Teste o Evolution API acessando: https://$DOMINIO_EVOLUTION"
echo "4. Gerencie tudo pelo Portainer: https://$DOMINIO_PORTAINER"
echo ""
echo "Todas as credenciais foram salvas no arquivo .env"
echo "================================================================"

log_success "Instalacao concluida com sucesso!"