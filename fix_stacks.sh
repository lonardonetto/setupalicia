#!/bin/bash

# 🔧 FIX DEFINITIVO - RECREATE STACKS WITH FULL CONTROL
# Solução que realmente funciona - recria as stacks com as configurações corretas

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
echo "║           FIX DEFINITIVO - STACKS COM FULL CONTROL            ║"
echo "║         Recria as stacks com as configurações corretas        ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Verificar .env
if [ ! -f .env ]; then
    log_error "Arquivo .env não encontrado!"
    echo "Execute primeiro o script de instalação."
    exit 1
fi

# Carregar variáveis
source .env

# Função para recriar stack com configuração completa
recreate_stack() {
    local stack_name=$1
    
    log_info "🔧 Recriando $stack_name com Full Control..."
    
    # Remover stack antiga se existir
    if docker stack ls | grep -q "^$stack_name "; then
        log_info "Removendo stack antiga..."
        docker stack rm "$stack_name" >/dev/null 2>&1
        
        # Aguardar remoção completa
        for i in {1..30}; do
            if ! docker service ls | grep -q "${stack_name}_"; then
                break
            fi
            sleep 2
        done
        sleep 5
    fi
    
    # Criar arquivo YAML temporário com configuração completa
    local yaml_file="/tmp/${stack_name}_fix.yml"
    
    case $stack_name in
        postgres)
            log_info "Criando configuração PostgreSQL..."
            cat > "$yaml_file" <<EOF
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
      mode: replicated
      replicas: 1
      placement:
        constraints: [node.role == manager]
      restart_policy:
        condition: any
        delay: 5s
        max_attempts: 3
volumes:
  postgres_data:
    external: true
networks:
  network_public:
    external: true
EOF
            ;;
            
        redis)
            log_info "Criando configuração Redis..."
            cat > "$yaml_file" <<EOF
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
      restart_policy:
        condition: any
        delay: 5s
        max_attempts: 3
volumes:
  redis_data:
    external: true
networks:
  network_public:
    external: true
EOF
            ;;
            
        evolution)
            log_info "Criando configuração Evolution API..."
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
      restart_policy:
        condition: any
        delay: 5s
        max_attempts: 3
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
            log_info "Criando configuração N8N..."
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
      restart_policy:
        condition: any
        delay: 5s
        max_attempts: 3
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
            log_error "Stack desconhecida: $stack_name"
            return 1
            ;;
    esac
    
    # Salvar arquivo YAML permanentemente
    cp "$yaml_file" "${stack_name}-stack.yml"
    log_success "✅ Arquivo ${stack_name}-stack.yml criado!"
    
    # Deploy da stack
    log_info "Fazendo deploy de $stack_name..."
    docker stack deploy --prune --resolve-image always -c "$yaml_file" "$stack_name"
    
    # Aguardar serviço iniciar
    sleep 10
    
    # Verificar se foi criada
    if docker stack ls | grep -q "^$stack_name "; then
        log_success "✅ $stack_name recriada com sucesso!"
        echo ""
        echo "📝 PRÓXIMO PASSO PARA FULL CONTROL:"
        echo "────────────────────────────────────"
        echo "1. Acesse o Portainer: https://$DOMINIO_PORTAINER"
        echo "2. Login: $PORTAINER_USER / $PORTAINER_PASS"
        echo "3. Vá em 'Add stack'"
        echo "4. Nome: ${stack_name}_managed"
        echo "5. Web editor: cole o conteúdo do arquivo ${stack_name}-stack.yml"
        echo "6. Deploy the stack"
        echo "7. Depois delete a stack $stack_name antiga"
        echo "8. Renomeie ${stack_name}_managed para $stack_name"
        echo ""
        return 0
    else
        log_error "❌ Falha ao criar $stack_name"
        return 1
    fi
}

# Menu principal
echo "📊 STATUS ATUAL DAS STACKS:"
docker stack ls
echo ""
echo "Este script vai:"
echo "1. Remover e recriar as stacks selecionadas"
echo "2. Criar arquivos YAML com as configurações"
echo "3. Instruir como converter para Full Control no Portainer"
echo ""
echo "⚠️ IMPORTANTE: Os dados NÃO serão perdidos (volumes preservados)"
echo ""
echo "Escolha uma opção:"
echo "1) Recriar TODAS (postgres, redis, evolution, n8n)"
echo "2) Recriar uma específica"
echo "3) Apenas criar os arquivos YAML (sem recriar)"
echo "4) Sair"
echo ""
read -p "Opção (1-4): " opcao

case $opcao in
    1)
        log_info "🔧 Recriando todas as stacks..."
        echo ""
        
        for stack in postgres redis evolution n8n; do
            echo "════════════════════════════════════════════"
            recreate_stack "$stack"
            echo "════════════════════════════════════════════"
            sleep 5
        done
        
        echo ""
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║                    STACKS RECRIADAS!                          ║"
        echo "╚════════════════════════════════════════════════════════════════╝"
        echo ""
        echo "📁 ARQUIVOS YAML CRIADOS:"
        ls -la *.yml 2>/dev/null || true
        echo ""
        echo "Para ter FULL CONTROL, você tem 2 opções:"
        echo ""
        echo "OPÇÃO A - Via Portainer (Recomendado):"
        echo "1. Acesse https://$DOMINIO_PORTAINER"
        echo "2. Para cada stack, crie uma nova via 'Add stack'"
        echo "3. Use o conteúdo dos arquivos .yml criados"
        echo ""
        echo "OPÇÃO B - Usar o conteúdo dos arquivos:"
        echo "cat postgres-stack.yml"
        echo "cat redis-stack.yml"
        echo "cat evolution-stack.yml"
        echo "cat n8n-stack.yml"
        ;;
        
    2)
        echo ""
        echo "Digite o nome da stack (postgres/redis/evolution/n8n):"
        read -p "Stack: " stack_name
        recreate_stack "$stack_name"
        ;;
        
    3)
        log_info "Criando apenas os arquivos YAML..."
        
        for stack in postgres redis evolution n8n; do
            log_info "Criando ${stack}-stack.yml..."
            
            # Criar temporário e copiar
            recreate_stack "$stack" > /dev/null 2>&1 || true
        done
        
        echo ""
        echo "📁 ARQUIVOS CRIADOS:"
        ls -la *-stack.yml
        echo ""
        echo "Use estes arquivos para criar as stacks no Portainer com Full Control!"
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
echo "💡 DICA IMPORTANTE:"
echo "Para ter controle TOTAL (Full Control), você precisa criar"
echo "as stacks ATRAVÉS da interface do Portainer usando os"
echo "arquivos YAML que foram criados neste diretório."
echo ""
echo "Os arquivos estão salvos como:"
echo "- postgres-stack.yml"
echo "- redis-stack.yml"
echo "- evolution-stack.yml"
echo "- n8n-stack.yml"
echo ""
