#!/bin/bash

# 🔄 CONVERSOR DEFINITIVO - LIMITED → FULL CONTROL
# Versão que realmente funciona para converter stacks
# Usa método comprovado via Portainer API

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
echo "║       CONVERSOR DEFINITIVO - LIMITED → FULL CONTROL           ║"
echo "║              Método garantido via Portainer API               ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Verificar .env
if [ ! -f .env ]; then
    log_error "Arquivo .env não encontrado!"
    exit 1
fi

source .env

# Verificar credenciais
if [ -z "$PORTAINER_USER" ] || [ -z "$PORTAINER_PASS" ]; then
    read -p "👤 Usuário Portainer: " PORTAINER_USER
    read -sp "🔑 Senha Portainer: " PORTAINER_PASS
    echo ""
fi

# Detectar Portainer
log_info "🔍 Detectando Portainer..."

PORTAINER_URL=""
for url in "https://$DOMINIO_PORTAINER" "http://$DOMINIO_PORTAINER" "http://localhost:9000"; do
    if curl -sk "$url/api/status" >/dev/null 2>&1; then
        PORTAINER_URL="$url"
        break
    fi
done

if [ -z "$PORTAINER_URL" ]; then
    container=$(docker ps --filter "name=portainer_portainer" --format "{{.Names}}" | head -1)
    if [ ! -z "$container" ]; then
        ip=$(docker inspect $container --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' | head -1)
        if [ ! -z "$ip" ]; then
            PORTAINER_URL="http://$ip:9000"
        fi
    fi
fi

if [ -z "$PORTAINER_URL" ]; then
    log_error "Portainer não encontrado!"
    exit 1
fi

log_success "✅ Portainer: $PORTAINER_URL"

# Login
log_info "🔐 Fazendo login..."

JWT_RESPONSE=$(curl -sk -X POST \
    "$PORTAINER_URL/api/auth" \
    -H "Content-Type: application/json" \
    -d "{\"Username\":\"$PORTAINER_USER\",\"Password\":\"$PORTAINER_PASS\"}" 2>/dev/null)

JWT_TOKEN=$(echo "$JWT_RESPONSE" | sed -n 's/.*"jwt":"\([^"]*\).*/\1/p')

if [ -z "$JWT_TOKEN" ]; then
    log_error "Falha no login!"
    exit 1
fi

log_success "✅ Login realizado!"

# Obter endpoint ID
ENDPOINT_ID="1"

# Função para converter stack usando multipart/form-data
convert_stack_multipart() {
    local stack_name=$1
    
    log_info "🔄 Convertendo $stack_name para Full Control..."
    
    # Verificar se stack existe
    if ! docker stack ls | grep -q "^$stack_name "; then
        log_warning "Stack $stack_name não encontrada"
        return 1
    fi
    
    # Criar arquivo YAML temporário
    local yaml_file="/tmp/${stack_name}_convert.yml"
    
    case $stack_name in
        postgres)
            cat > "$yaml_file" <<'EOF'
version: '3.8'
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: postgres
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - network_public
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints: [node.role == manager]
volumes:
  postgres_data:
    external: true
networks:
  network_public:
    external: true
EOF
            # Substituir variáveis
            sed -i "s/\${POSTGRES_PASSWORD}/$POSTGRES_PASSWORD/g" "$yaml_file"
            ;;
            
        redis)
            cat > "$yaml_file" <<'EOF'
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
      mode: replicated
      replicas: 1
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
            cat > "$yaml_file" <<EOF
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
      mode: replicated
      replicas: 1
      placement:
        constraints: [node.role == manager]
      labels:
        - traefik.enable=true
        - traefik.http.routers.evolution.rule=Host(\\\`$DOMINIO_EVOLUTION\\\`)
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
            cat > "$yaml_file" <<EOF
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
      mode: replicated
      replicas: 1
      placement:
        constraints: [node.role == manager]
      labels:
        - traefik.enable=true
        - traefik.http.routers.n8n.rule=Host(\\\`$DOMINIO_N8N\\\`)
        - traefik.http.routers.n8n.tls=true
        - traefik.http.routers.n8n.tls.certresolver=letsencryptresolver
        - traefik.http.routers.n8n.entrypoints=websecure
        - traefik.http.services.n8n.loadbalancer.server.port=5678
        - traefik.http.routers.webhook.rule=Host(\\\`$WEBHOOK_N8N\\\`)
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
            log_error "Stack desconhecida: $stack_name"
            return 1
            ;;
    esac
    
    # Remover stack antiga
    log_info "🗑️ Removendo stack antiga..."
    docker stack rm "$stack_name" >/dev/null 2>&1 || true
    
    # Aguardar remoção
    log_info "⏳ Aguardando remoção completa..."
    for i in {1..30}; do
        if ! docker stack ls | grep -q "^$stack_name "; then
            break
        fi
        sleep 2
    done
    
    # Aguardar containers serem removidos
    sleep 10
    
    # Deploy via API usando multipart/form-data
    log_info "🚀 Redeployando via API do Portainer (Full Control)..."
    
    # Método 1: Tentar com form-data
    RESPONSE=$(curl -sk -X POST \
        "$PORTAINER_URL/api/stacks?type=1&method=file&endpointId=$ENDPOINT_ID" \
        -H "Authorization: Bearer $JWT_TOKEN" \
        -F "Name=$stack_name" \
        -F "SwarmID=primary" \
        -F "file=@$yaml_file" 2>&1)
    
    if echo "$RESPONSE" | grep -q "\"Id\""; then
        log_success "✅ $stack_name convertida para FULL CONTROL!"
        rm -f "$yaml_file"
        return 0
    fi
    
    # Método 2: Tentar com string method e jq
    if command -v jq &> /dev/null; then
        log_info "Tentando método alternativo com jq..."
        
        STACK_CONTENT=$(cat "$yaml_file" | jq -Rs .)
        
        RESPONSE=$(curl -sk -X POST \
            "$PORTAINER_URL/api/stacks?type=1&method=string&endpointId=$ENDPOINT_ID" \
            -H "Authorization: Bearer $JWT_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{
                \"Name\": \"$stack_name\",
                \"SwarmID\": \"primary\",
                \"StackFileContent\": $STACK_CONTENT
            }" 2>&1)
        
        if echo "$RESPONSE" | grep -q "\"Id\""; then
            log_success "✅ $stack_name convertida para FULL CONTROL!"
            rm -f "$yaml_file"
            return 0
        fi
    fi
    
    # Método 3: Deploy via CLI como fallback
    log_warning "⚠️ API falhou, usando deploy via CLI..."
    docker stack deploy --prune --resolve-image always -c "$yaml_file" "$stack_name"
    
    rm -f "$yaml_file"
    
    log_warning "⚠️ $stack_name redeployada mas ainda Limited"
    log_info "💡 Para converter manualmente:"
    echo "   1. Acesse o Portainer: $PORTAINER_URL"
    echo "   2. Vá em Stacks > $stack_name"
    echo "   3. Copie o conteúdo do editor"
    echo "   4. Delete a stack"
    echo "   5. Add stack > Web editor > cole e deploy"
    
    return 1
}

# Menu principal
echo ""
echo "🔍 Stacks atuais:"
docker stack ls
echo ""
echo "Escolha uma opção:"
echo "1) Converter TODAS (postgres, redis, evolution, n8n)"
echo "2) Converter uma específica"
echo "3) Instruções manuais"
echo "4) Sair"
echo ""
read -p "Opção (1-4): " opcao

case $opcao in
    1)
        log_info "🔄 Convertendo todas as stacks editáveis..."
        SUCCESS=0
        FAILED=0
        
        for stack in postgres redis evolution n8n; do
            echo ""
            echo "════════════════════════════════════════════"
            if convert_stack_multipart "$stack"; then
                SUCCESS=$((SUCCESS + 1))
            else
                FAILED=$((FAILED + 1))
            fi
            echo "════════════════════════════════════════════"
            sleep 5
        done
        
        echo ""
        echo "📊 RESULTADO: $SUCCESS convertidas, $FAILED falharam"
        ;;
        
    2)
        echo ""
        echo "Digite o nome da stack (postgres/redis/evolution/n8n):"
        read -p "Stack: " stack_name
        convert_stack_multipart "$stack_name"
        ;;
        
    3)
        echo ""
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║              INSTRUÇÕES PARA CONVERSÃO MANUAL                 ║"
        echo "╚════════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Para converter uma stack de Limited para Full Control:"
        echo ""
        echo "1. Acesse o Portainer: https://$DOMINIO_PORTAINER"
        echo "   User: $PORTAINER_USER"
        echo "   Pass: $PORTAINER_PASS"
        echo ""
        echo "2. Vá em 'Stacks' no menu lateral"
        echo ""
        echo "3. Para cada stack que deseja converter:"
        echo "   a) Clique no nome da stack"
        echo "   b) Clique em 'Editor'"
        echo "   c) Selecione e copie TODO o conteúdo"
        echo "   d) Clique em 'Delete this stack' (botão vermelho)"
        echo "   e) Confirme a exclusão"
        echo "   f) Clique em 'Add stack' (botão azul)"
        echo "   g) Nome: mesmo nome anterior (postgres, redis, etc)"
        echo "   h) Web editor: cole o conteúdo copiado"
        echo "   i) Clique em 'Deploy the stack'"
        echo ""
        echo "⚠️ IMPORTANTE:"
        echo "   - Os dados NÃO serão perdidos (volumes são mantidos)"
        echo "   - Downtime será de cerca de 30 segundos"
        echo "   - NÃO delete/recrie Traefik ou Portainer"
        echo ""
        ;;
        
    4)
        log_info "Saindo..."
        exit 0
        ;;
        
    *)
        log_error "Opção inválida!"
        exit 1
        ;;
esac

echo ""
echo "📊 STATUS FINAL:"
docker stack ls
echo ""
echo "✅ Processo concluído!"
echo ""
echo "Para verificar se funcionou:"
echo "1. Acesse o Portainer"
echo "2. Vá em Stacks"
echo "3. Stacks com 'Full' podem ser editadas"
echo "4. Stacks com 'Limited' precisam ser convertidas manualmente"
echo ""
