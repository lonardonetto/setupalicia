#!/bin/bash

# 🚀 PORTAINER STACK MANAGER
# Gerenciador de Stacks via API do Portainer para controle total
# Autor: SetupAlicia - Automação Profissional

# Função para fazer login no Portainer e obter JWT
portainer_login() {
    local PORTAINER_URL=$1
    local USERNAME=$2
    local PASSWORD=$3
    
    log_info "🔑 Fazendo login no Portainer..."
    
    local response=$(curl -s -X POST \
        "$PORTAINER_URL/api/auth" \
        -H "Content-Type: application/json" \
        --insecure \
        -d "{
            \"Username\": \"$USERNAME\",
            \"Password\": \"$PASSWORD\"
        }" 2>/dev/null)
    
    # Extrair token JWT
    local jwt_token=$(echo "$response" | sed -n 's/.*"jwt":"\([^"]*\).*/\1/p')
    
    if [ ! -z "$jwt_token" ]; then
        echo "$jwt_token"
        return 0
    else
        log_error "❌ Falha no login do Portainer"
        return 1
    fi
}

# Função para obter o ID do endpoint Swarm
get_swarm_endpoint_id() {
    local PORTAINER_URL=$1
    local JWT_TOKEN=$2
    
    local response=$(curl -s -X GET \
        "$PORTAINER_URL/api/endpoints" \
        -H "Authorization: Bearer $JWT_TOKEN" \
        --insecure 2>/dev/null)
    
    # Pegar o primeiro endpoint (geralmente é o local/primary)
    local endpoint_id=$(echo "$response" | sed -n 's/.*"Id":\([0-9]*\).*/\1/p' | head -1)
    
    if [ ! -z "$endpoint_id" ]; then
        echo "$endpoint_id"
        return 0
    else
        # Se não houver endpoints, criar um
        create_swarm_endpoint "$PORTAINER_URL" "$JWT_TOKEN"
    fi
}

# Função para criar endpoint Swarm se não existir
create_swarm_endpoint() {
    local PORTAINER_URL=$1
    local JWT_TOKEN=$2
    
    log_info "📍 Criando endpoint Swarm..."
    
    local response=$(curl -s -X POST \
        "$PORTAINER_URL/api/endpoints" \
        -H "Authorization: Bearer $JWT_TOKEN" \
        -H "Content-Type: application/json" \
        --insecure \
        -d '{
            "Name": "primary",
            "EndpointCreationType": 1
        }' 2>/dev/null)
    
    local endpoint_id=$(echo "$response" | sed -n 's/.*"Id":\([0-9]*\).*/\1/p')
    echo "$endpoint_id"
}

# Função para deployar stack via API do Portainer
deploy_stack_via_portainer() {
    local PORTAINER_URL=$1
    local JWT_TOKEN=$2
    local ENDPOINT_ID=$3
    local STACK_NAME=$4
    local STACK_FILE_CONTENT=$5
    local ENV_VARS=$6
    
    log_info "📦 Deployando stack $STACK_NAME via Portainer API..."
    
    # Preparar variáveis de ambiente em formato JSON array
    local env_json="[]"
    if [ ! -z "$ENV_VARS" ]; then
        env_json=$(echo "$ENV_VARS" | jq -R 'split("\n") | map(select(length > 0) | split("=") | {name: .[0], value: .[1]})')
    fi
    
    # Criar o payload JSON
    local payload=$(jq -n \
        --arg name "$STACK_NAME" \
        --arg content "$STACK_FILE_CONTENT" \
        --argjson env "$env_json" \
        '{
            "Name": $name,
            "StackFileContent": $content,
            "Env": $env,
            "SwarmID": "primary"
        }')
    
    # Deploy da stack
    local response=$(curl -s -X POST \
        "$PORTAINER_URL/api/stacks?type=1&method=string&endpointId=$ENDPOINT_ID" \
        -H "Authorization: Bearer $JWT_TOKEN" \
        -H "Content-Type: application/json" \
        --insecure \
        -d "$payload" 2>/dev/null)
    
    # Verificar se foi criada com sucesso
    if echo "$response" | grep -q "\"Id\""; then
        log_success "✅ Stack $STACK_NAME deployada com controle total!"
        return 0
    else
        log_warning "⚠️ Possível erro ao deployar $STACK_NAME: $response"
        return 1
    fi
}

# Função para remover stack existente via Docker CLI (para redeploy)
remove_docker_stack() {
    local STACK_NAME=$1
    
    if docker stack ls | grep -q "$STACK_NAME"; then
        log_info "🗑️ Removendo stack $STACK_NAME existente..."
        docker stack rm "$STACK_NAME" >/dev/null 2>&1
        
        # Aguardar remoção completa
        local count=0
        while [ $count -lt 30 ]; do
            if ! docker stack ls | grep -q "$STACK_NAME"; then
                break
            fi
            sleep 2
            count=$((count + 1))
        done
    fi
}

# Função principal para migrar todas as stacks para controle do Portainer
migrate_stacks_to_portainer() {
    local PORTAINER_URL=$1
    local ADMIN_USER=$2
    local ADMIN_PASSWORD=$3
    
    log_info "🔄 Migrando stacks para controle total do Portainer..."
    
    # Fazer login
    local JWT_TOKEN=$(portainer_login "$PORTAINER_URL" "$ADMIN_USER" "$ADMIN_PASSWORD")
    if [ -z "$JWT_TOKEN" ]; then
        log_error "❌ Não foi possível obter token JWT"
        return 1
    fi
    
    # Obter endpoint ID
    local ENDPOINT_ID=$(get_swarm_endpoint_id "$PORTAINER_URL" "$JWT_TOKEN")
    if [ -z "$ENDPOINT_ID" ]; then
        log_error "❌ Não foi possível obter endpoint ID"
        return 1
    fi
    
    log_success "✅ Autenticado no Portainer! Endpoint ID: $ENDPOINT_ID"
    
    # Salvar token e endpoint no .env para uso futuro
    echo "PORTAINER_JWT_TOKEN=$JWT_TOKEN" >> .env
    echo "PORTAINER_ENDPOINT_ID=$ENDPOINT_ID" >> .env
    
    return 0
}

# Função para deployar PostgreSQL via Portainer
deploy_postgres_via_portainer() {
    local PORTAINER_URL=$1
    local JWT_TOKEN=$2
    local ENDPOINT_ID=$3
    local POSTGRES_PASSWORD=$4
    
    # Remover stack existente se houver
    remove_docker_stack "postgres"
    
    # Conteúdo do stack file
    local stack_content="version: '3.7'

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
    external: true

networks:
  network_public:
    external: true"
    
    # Variáveis de ambiente
    local env_vars="POSTGRES_PASSWORD=$POSTGRES_PASSWORD"
    
    # Deploy via Portainer
    deploy_stack_via_portainer "$PORTAINER_URL" "$JWT_TOKEN" "$ENDPOINT_ID" "postgres" "$stack_content" "$env_vars"
}

# Função para deployar Redis via Portainer
deploy_redis_via_portainer() {
    local PORTAINER_URL=$1
    local JWT_TOKEN=$2
    local ENDPOINT_ID=$3
    
    # Remover stack existente se houver
    remove_docker_stack "redis"
    
    # Conteúdo do stack file
    local stack_content="version: '3.7'

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
    external: true

networks:
  network_public:
    external: true"
    
    # Deploy via Portainer
    deploy_stack_via_portainer "$PORTAINER_URL" "$JWT_TOKEN" "$ENDPOINT_ID" "redis" "$stack_content" ""
}

# Função para deployar Evolution API via Portainer
deploy_evolution_via_portainer() {
    local PORTAINER_URL=$1
    local JWT_TOKEN=$2
    local ENDPOINT_ID=$3
    local DOMINIO_EVOLUTION=$4
    local EVOLUTION_API_KEY=$5
    local POSTGRES_PASSWORD=$6
    
    # Remover stack existente se houver
    remove_docker_stack "evolution"
    
    # Conteúdo do stack file com todas as labels do Traefik
    local stack_content="version: '3.7'

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
      - CONFIG_SESSION_PHONE_CLIENT=Evolution API
      - CONFIG_SESSION_PHONE_NAME=Chrome
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
        - traefik.http.routers.evolution.rule=Host(\\\`$DOMINIO_EVOLUTION\\\`)
        - traefik.http.routers.evolution.tls=true
        - traefik.http.routers.evolution.tls.certresolver=letsencryptresolver
        - traefik.http.routers.evolution.entrypoints=websecure
        - traefik.http.services.evolution.loadbalancer.server.port=8080
        - traefik.http.routers.evolution.service=evolution
        - traefik.http.routers.evolution-redirect.rule=Host(\\\`$DOMINIO_EVOLUTION\\\`)
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
    external: true"
    
    # Variáveis de ambiente
    local env_vars="DOMINIO_EVOLUTION=$DOMINIO_EVOLUTION
EVOLUTION_API_KEY=$EVOLUTION_API_KEY
POSTGRES_PASSWORD=$POSTGRES_PASSWORD"
    
    # Deploy via Portainer
    deploy_stack_via_portainer "$PORTAINER_URL" "$JWT_TOKEN" "$ENDPOINT_ID" "evolution" "$stack_content" "$env_vars"
}

# Função para deployar N8N via Portainer
deploy_n8n_via_portainer() {
    local PORTAINER_URL=$1
    local JWT_TOKEN=$2
    local ENDPOINT_ID=$3
    local DOMINIO_N8N=$4
    local WEBHOOK_N8N=$5
    local N8N_KEY=$6
    local POSTGRES_PASSWORD=$7
    
    # Remover stack existente se houver
    remove_docker_stack "n8n"
    
    # Conteúdo do stack file
    local stack_content="version: '3.7'

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
        - traefik.http.routers.n8n.rule=Host(\\\`$DOMINIO_N8N\\\`)
        - traefik.http.routers.n8n.tls=true
        - traefik.http.routers.n8n.tls.certresolver=letsencryptresolver
        - traefik.http.routers.n8n.entrypoints=websecure
        - traefik.http.services.n8n.loadbalancer.server.port=5678
        - traefik.http.routers.n8n.service=n8n
        - traefik.http.routers.n8n-redirect.rule=Host(\\\`$DOMINIO_N8N\\\`)
        - traefik.http.routers.n8n-redirect.entrypoints=web
        - traefik.http.routers.n8n-redirect.middlewares=redirect-to-https
        - traefik.http.routers.webhook.rule=Host(\\\`$WEBHOOK_N8N\\\`)
        - traefik.http.routers.webhook.tls=true
        - traefik.http.routers.webhook.tls.certresolver=letsencryptresolver
        - traefik.http.routers.webhook.entrypoints=websecure
        - traefik.http.routers.webhook.service=n8n
        - traefik.http.routers.webhook-redirect.rule=Host(\\\`$WEBHOOK_N8N\\\`)
        - traefik.http.routers.webhook-redirect.entrypoints=web
        - traefik.http.routers.webhook-redirect.middlewares=redirect-to-https
        - traefik.docker.network=network_public

volumes:
  n8n_data:
    external: true

networks:
  network_public:
    external: true"
    
    # Variáveis de ambiente
    local env_vars="DOMINIO_N8N=$DOMINIO_N8N
WEBHOOK_N8N=$WEBHOOK_N8N
N8N_KEY=$N8N_KEY
POSTGRES_PASSWORD=$POSTGRES_PASSWORD"
    
    # Deploy via Portainer
    deploy_stack_via_portainer "$PORTAINER_URL" "$JWT_TOKEN" "$ENDPOINT_ID" "n8n" "$stack_content" "$env_vars"
}
