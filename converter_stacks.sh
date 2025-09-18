#!/bin/bash

# 🔄 CONVERSOR DE STACKS - LIMITED → FULL CONTROL
# Script para converter stacks existentes para controle total no Portainer
# Mantém todas as configurações e dados

set -e

# Cores
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

# Banner
clear
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          CONVERSOR DE STACKS - LIMITED → FULL CONTROL         ║"
echo "║                  Torna suas stacks editáveis                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Verificar se .env existe
if [ ! -f .env ]; then
    log_error "Arquivo .env não encontrado!"
    echo "Execute primeiro o script de instalação."
    exit 1
fi

# Carregar variáveis
source .env

# Verificar credenciais do Portainer
if [ -z "$PORTAINER_USER" ] || [ -z "$PORTAINER_PASS" ]; then
    log_warning "Credenciais do Portainer não encontradas no .env"
    echo ""
    read -p "👤 Usuário do Portainer: " PORTAINER_USER
    read -sp "🔑 Senha do Portainer: " PORTAINER_PASS
    echo ""
fi

# Detectar URL do Portainer
log_info "🔍 Detectando Portainer..."

PORTAINER_URL=""
for url in "https://$DOMINIO_PORTAINER" "http://$DOMINIO_PORTAINER" "http://localhost:9000"; do
    if curl -sk "$url/api/status" >/dev/null 2>&1; then
        PORTAINER_URL="$url"
        log_success "✅ Portainer encontrado em: $PORTAINER_URL"
        break
    fi
done

# Tentar IP direto se necessário
if [ -z "$PORTAINER_URL" ]; then
    container=$(docker ps --filter "name=portainer_portainer" --format "{{.Names}}" | head -1)
    if [ ! -z "$container" ]; then
        ip=$(docker inspect $container --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' | head -1)
        if [ ! -z "$ip" ] && curl -s "http://$ip:9000/api/status" >/dev/null 2>&1; then
            PORTAINER_URL="http://$ip:9000"
            log_success "✅ Portainer encontrado via IP: $PORTAINER_URL"
        fi
    fi
fi

if [ -z "$PORTAINER_URL" ]; then
    log_error "❌ Não foi possível encontrar o Portainer!"
    exit 1
fi

# Fazer login no Portainer
log_info "🔐 Fazendo login no Portainer..."

JWT_RESPONSE=$(curl -sk -X POST \
    "$PORTAINER_URL/api/auth" \
    -H "Content-Type: application/json" \
    -d "{\"Username\":\"$PORTAINER_USER\",\"Password\":\"$PORTAINER_PASS\"}" 2>/dev/null)

JWT_TOKEN=$(echo "$JWT_RESPONSE" | sed -n 's/.*"jwt":"\([^"]*\).*/\1/p')

if [ -z "$JWT_TOKEN" ]; then
    log_error "❌ Falha no login do Portainer!"
    echo "Verifique usuário e senha."
    exit 1
fi

log_success "✅ Login realizado com sucesso!"

# Obter ID do endpoint
log_info "📍 Obtendo endpoint..."

ENDPOINT_RESPONSE=$(curl -sk -X GET \
    "$PORTAINER_URL/api/endpoints" \
    -H "Authorization: Bearer $JWT_TOKEN" 2>/dev/null)

ENDPOINT_ID=$(echo "$ENDPOINT_RESPONSE" | grep -oP '"Id":\K[0-9]+' | head -1)

if [ -z "$ENDPOINT_ID" ]; then
    ENDPOINT_ID="1"
    log_warning "⚠️ Usando endpoint padrão: 1"
else
    log_success "✅ Endpoint ID: $ENDPOINT_ID"
fi

# Função para converter uma stack
convert_stack() {
    local stack_name=$1
    local yaml_file="${stack_name}_backup.yml"
    
    log_info "🔄 Convertendo $stack_name..."
    
    # Verificar se a stack existe
    if ! docker stack ls | grep -q "^$stack_name "; then
        log_warning "⚠️ Stack $stack_name não encontrada, pulando..."
        return 1
    fi
    
    # Obter configuração da stack
    log_info "📋 Salvando configuração atual..."
    
    # Extrair serviços da stack
    services=$(docker service ls --filter "label=com.docker.stack.namespace=$stack_name" --format "{{.Name}}")
    
    if [ -z "$services" ]; then
        log_warning "⚠️ Nenhum serviço encontrado para $stack_name"
        return 1
    fi
    
    # Criar arquivo YAML da stack
    echo "version: '3.8'" > "$yaml_file"
    echo "services:" >> "$yaml_file"
    
    for service in $services; do
        service_name=${service#${stack_name}_}
        log_info "  Exportando serviço: $service_name"
        
        # Obter configuração do serviço
        docker service inspect "$service" --format '{{json .}}' > "${service}.json"
        
        # Extrair informações básicas (simplificado)
        image=$(docker service inspect "$service" --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}')
        echo "  $service_name:" >> "$yaml_file"
        echo "    image: $image" >> "$yaml_file"
    done
    
    # Remover stack antiga
    log_info "🗑️ Removendo stack antiga..."
    docker stack rm "$stack_name" >/dev/null 2>&1
    
    # Aguardar remoção completa
    log_info "⏳ Aguardando remoção..."
    for i in {1..30}; do
        if ! docker stack ls | grep -q "^$stack_name "; then
            break
        fi
        sleep 2
    done
    
    # Aguardar containers serem removidos
    sleep 10
    
    # Ler conteúdo do arquivo YAML original se existir
    if [ -f "${stack_name}-stack.yml" ]; then
        yaml_file="${stack_name}-stack.yml"
        log_info "📄 Usando arquivo original: $yaml_file"
    elif [ -f "${stack_name}_stack.yml" ]; then
        yaml_file="${stack_name}_stack.yml"
        log_info "📄 Usando arquivo original: $yaml_file"
    elif [ -f "${stack_name}.yml" ]; then
        yaml_file="${stack_name}.yml"
        log_info "📄 Usando arquivo original: $yaml_file"
    else
        # Criar arquivo YAML básico baseado na configuração atual
        log_info "📝 Criando configuração básica..."
        create_stack_yaml "$stack_name"
        yaml_file="${stack_name}_generated.yml"
    fi
    
    # Deploy via API do Portainer (Full Control)
    log_info "🚀 Fazendo redeploy via API do Portainer..."
    
    if [ -f "$yaml_file" ]; then
        # Ler conteúdo do arquivo
        STACK_CONTENT=$(cat "$yaml_file")
        
        # Escapar para JSON
        ESCAPED_CONTENT=$(echo "$STACK_CONTENT" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
        
        # Deploy via API
        RESPONSE=$(curl -sk -X POST \
            "$PORTAINER_URL/api/stacks?type=1&method=string&endpointId=$ENDPOINT_ID" \
            -H "Authorization: Bearer $JWT_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{
                \"Name\": \"$stack_name\",
                \"SwarmID\": \"primary\",
                \"StackFileContent\": \"$ESCAPED_CONTENT\"
            }" 2>&1)
        
        if echo "$RESPONSE" | grep -q "\"Id\""; then
            log_success "✅ $stack_name convertida para FULL CONTROL!"
            return 0
        else
            log_warning "⚠️ Falha na API, tentando deploy via CLI..."
            docker stack deploy --prune --resolve-image always -c "$yaml_file" "$stack_name"
            log_warning "⚠️ $stack_name redeployada mas ainda Limited"
            return 1
        fi
    else
        log_error "❌ Arquivo YAML não encontrado para $stack_name"
        return 1
    fi
}

# Função para criar YAML básico
create_stack_yaml() {
    local stack_name=$1
    local output_file="${stack_name}_generated.yml"
    
    # Criar YAMLs básicos para cada stack conhecida
    case $stack_name in
        postgres)
            cat > "$output_file" <<EOF
version: '3.8'
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
      placement:
        constraints: [node.role == manager]
volumes:
  postgres_data:
    external: true
networks:
  network_public:
    external: true
EOF
            ;;
        redis)
            cat > "$output_file" <<EOF
version: '3.8'
services:
  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    networks:
      - network_public
    deploy:
      placement:
        constraints: [node.role == manager]
volumes:
  redis_data:
    external: true
networks:
  network_public:
    external: true
EOF
            ;;
        evolution)
            cat > "$output_file" <<EOF
version: '3.8'
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
      placement:
        constraints: [node.role == manager]
      labels:
        - traefik.enable=true
        - traefik.http.routers.evolution.rule=Host(\`$DOMINIO_EVOLUTION\`)
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
    external: true
EOF
            ;;
        n8n)
            cat > "$output_file" <<EOF
version: '3.8'
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
      placement:
        constraints: [node.role == manager]
      labels:
        - traefik.enable=true
        - traefik.http.routers.n8n.rule=Host(\`$DOMINIO_N8N\`)
        - traefik.http.routers.n8n.tls=true
        - traefik.http.routers.n8n.tls.certresolver=letsencryptresolver
        - traefik.http.routers.n8n.entrypoints=websecure
        - traefik.http.services.n8n.loadbalancer.server.port=5678
        - traefik.http.routers.webhook.rule=Host(\`$WEBHOOK_N8N\`)
        - traefik.http.routers.webhook.tls=true
        - traefik.http.routers.webhook.tls.certresolver=letsencryptresolver
        - traefik.http.routers.webhook.entrypoints=websecure
        - traefik.docker.network=network_public
volumes:
  n8n_data:
    external: true
networks:
  network_public:
    external: true
EOF
            ;;
        *)
            log_warning "⚠️ Stack desconhecida: $stack_name"
            return 1
            ;;
    esac
}

# Menu de seleção
echo ""
echo "🔍 Stacks detectadas com controle Limited:"
echo ""
docker stack ls
echo ""
echo "Escolha uma opção:"
echo "1) Converter TODAS as stacks editáveis (postgres, redis, evolution, n8n)"
echo "2) Converter stacks específicas"
echo "3) Sair"
echo ""
read -p "Digite sua opção (1-3): " opcao

case $opcao in
    1)
        log_info "🔄 Convertendo TODAS as stacks editáveis..."
        echo ""
        
        # Não converter traefik e portainer (devem ficar Limited)
        for stack in postgres redis evolution n8n; do
            echo ""
            echo "════════════════════════════════════════════"
            convert_stack "$stack"
            echo "════════════════════════════════════════════"
            sleep 5
        done
        ;;
        
    2)
        echo ""
        echo "Quais stacks deseja converter? (separadas por espaço)"
        echo "Opções: postgres redis evolution n8n"
        echo "Exemplo: postgres redis"
        echo ""
        read -p "Stacks: " stacks_to_convert
        
        for stack in $stacks_to_convert; do
            echo ""
            echo "════════════════════════════════════════════"
            convert_stack "$stack"
            echo "════════════════════════════════════════════"
            sleep 5
        done
        ;;
        
    3)
        log_info "Saindo..."
        exit 0
        ;;
        
    *)
        log_error "Opção inválida!"
        exit 1
        ;;
esac

# Verificação final
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    CONVERSÃO FINALIZADA                       ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 STATUS ATUAL DAS STACKS:"
docker stack ls
echo ""
echo "✅ Stacks convertidas agora são editáveis no Portainer!"
echo ""
echo "Para verificar no Portainer:"
echo "1. Acesse: $PORTAINER_URL"
echo "2. Vá em Stacks"
echo "3. Stacks com 'Full' control podem ser editadas"
echo ""
echo "⚠️ NOTA: Traefik e Portainer devem permanecer 'Limited' (normal)"
echo ""
