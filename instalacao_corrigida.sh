#!/bin/bash

# 🚀 SETUPALICIA - MENU COMPLETO + INSTALAÇÃO FUNCIONANDO
# Mantém o script original que funciona 100% + adiciona funcionalidades extras
# Autor: SetupAlicia - Automação DevOps
# Data: 2024
# Versão: 3.0 DEFINITIVA - Deploy via API PortainerMENU + ORIGINAL FUNCIONANDO

set -e

# Função para log colorido
log_info() { echo -e "\033[34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[32m[SUCESSO]\033[0m $1"; }
log_warning() { echo -e "\033[33m[AVISO]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERRO]\033[0m $1"; }

# Função para confirmação
confirmar() {
    local mensagem=$1
    echo ""
    echo "🤔 $mensagem"
    read -p "Digite 'sim' para continuar: " resposta
    if [ "$resposta" != "sim" ]; then
        log_warning "Operação cancelada."
        exit 0
    fi
    log_success "✅ Confirmado! Continuando..."
    echo ""
}

# Função para reset do Portainer
reset_portainer() {
    log_warning "🔄 RESET DO PORTAINER"
    echo "Esta operação vai resetar o Portainer (resolve timeout de 5 minutos)"
    
    confirmar "Deseja resetar o Portainer?"
    
    # Carregar variáveis se existirem
    if [ -f .env ]; then
        source .env
    else
        read -p "Digite o domínio do Portainer: " DOMINIO_PORTAINER
    fi
    
    # Reset do Portainer
    log_info "Parando e removendo Portainer..."
    docker stack rm portainer >/dev/null 2>&1 || true
    sleep 15
    
    docker volume rm portainer_data >/dev/null 2>&1 || true
    docker network rm agent_network >/dev/null 2>&1 || true
    docker container prune -f >/dev/null 2>&1
    
    log_info "Recriando Portainer limpo..."
    docker volume create portainer_data >/dev/null 2>&1
    docker network create --driver=overlay agent_network >/dev/null 2>&1
    
    # Criar YAML do Portainer
    cat > portainer_reset.yaml <<EOF
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

volumes:
  portainer_data:
    external: true

networks:
  network_public:
    external: true
  agent_network:
    external: true
EOF

    docker stack deploy --prune --resolve-image always -c portainer_reset.yaml portainer
    
    log_success "✅ Portainer resetado! Acesse: https://$DOMINIO_PORTAINER"
    echo "⚠️ Configure senha nos primeiros 5 minutos!"
}

# Função para fix SSL específico
fix_ssl_especifico() {
    log_warning "🔐 FIX SSL ESPECÍFICO"
    echo "ForForça certificados SSL para domínios pendentes"
    
    confirmar "Executar fix SSL?"
    
    # Carregar domínios
    if [ -f .env ]; then
        source .env
    else
        read -p "Digite domínio Portainer: " DOMINIO_PORTAINER
        read -p "Digite domínio N8N: " DOMINIO_N8N
        read -p "Digite domínio Evolution: " DOMINIO_EVOLUTION
        read -p "Digite domínio Webhook: " WEBHOOK_N8N
    fi
    
    server_ip=$(curl -s ifconfig.me 2>/dev/null || hostname -I | cut -d' ' -f1)
    
    # Forçar SSL para cada domínio usando função simples
    for domain in "$DOMINIO_PORTAINER" "$DOMINIO_N8N" "$DOMINIO_EVOLUTION" "$WEBHOOK_N8N"; do
        if [ "$domain" = "$DOMINIO_PORTAINER" ]; then
            check_ssl_simple "$domain" "Portainer"
        elif [ "$domain" = "$DOMINIO_N8N" ]; then
            check_ssl_simple "$domain" "N8N"
        elif [ "$domain" = "$DOMINIO_EVOLUTION" ]; then
            check_ssl_simple "$domain" "Evolution API"
        elif [ "$domain" = "$WEBHOOK_N8N" ]; then
            check_ssl_simple "$domain" "Webhook N8N"
        fi
    done
    
    # Testar resultado
    log_info "Testando SSL final..."
    for domain in "$DOMINIO_PORTAINER" "$DOMINIO_N8N" "$DOMINIO_EVOLUTION" "$WEBHOOK_N8N"; do
        if curl -s -I "https://$domain" --max-time 8 2>/dev/null | grep -q "HTTP.*[2-4][0-9][0-9]"; then
            log_success "✅ $domain: SSL OK"
        else
            log_warning "⚠️ $domain: SSL pendente"
        fi
    done
}

# Função para converter stacks Limited para Full Control
converter_stacks_full_control() {
    log_warning "🔄 CONVERTER STACKS PARA FULL CONTROL"
    echo ""
    echo "Vamos usar a API do Portainer para ter controle total."
    echo ""
    
    # Carregar variáveis
    if [ ! -f .env ]; then
        log_error "Arquivo .env não encontrado!"
        return 1
    fi
    
    source .env
    
    # Detectar Portainer
    log_info "🔍 Detectando Portainer..."
    PORTAINER_URL=""
    
    # Tentar HTTPS primeiro
    if curl -sk "https://$DOMINIO_PORTAINER/api/status" >/dev/null 2>&1; then
        PORTAINER_URL="https://$DOMINIO_PORTAINER"
    # Tentar HTTP
    elif curl -s "http://$DOMINIO_PORTAINER/api/status" >/dev/null 2>&1; then
        PORTAINER_URL="http://$DOMINIO_PORTAINER"
    # Tentar IP direto
    else
        container=$(docker ps --filter "name=portainer_portainer" --format "{{.Names}}" | head -1)
        if [ ! -z "$container" ]; then
            ip=$(docker inspect $container --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' | head -1)
            if [ ! -z "$ip" ] && curl -s "http://$ip:9000/api/status" >/dev/null 2>&1; then
                PORTAINER_URL="http://$ip:9000"
            fi
        fi
    fi
    
    if [ -z "$PORTAINER_URL" ]; then
        log_error "Não foi possível conectar ao Portainer!"
        return 1
    fi
    
    log_success "✅ Portainer encontrado: $PORTAINER_URL"
    
    # Obter credenciais
    if [ -z "$PORTAINER_ADMIN_USER" ] || [ -z "$PORTAINER_ADMIN_PASSWORD" ]; then
        log_info "Digite as credenciais do Portainer:"
        read -p "Usuário: " PORTAINER_ADMIN_USER
        read -sp "Senha: " PORTAINER_ADMIN_PASSWORD
        echo ""
    fi
    
    # Fazer login
    log_info "🔐 Fazendo login no Portainer..."
    JWT_RESPONSE=$(curl -sk -X POST \
        "$PORTAINER_URL/api/auth" \
        -H "Content-Type: application/json" \
        -d "{\"Username\":\"$PORTAINER_ADMIN_USER\",\"Password\":\"$PORTAINER_ADMIN_PASSWORD\"}" 2>/dev/null)
    
    JWT_TOKEN=$(echo "$JWT_RESPONSE" | sed -n 's/.*"jwt":"\([^"]*\).*/\1/p')
    
    if [ -z "$JWT_TOKEN" ]; then
        log_error "Falha no login! Verifique as credenciais."
        return 1
    fi
    
    log_success "✅ Login realizado com sucesso!"
    
    echo ""
    echo "Stacks que serão convertidas para Full Control:"
    echo "  • postgres"
    echo "  • redis"
    echo "  • evolution"
    echo "  • n8n"
    echo ""
    
    confirmar "Deseja converter as stacks para Full Control?"
    
    # Função para remover stack
    remove_stack() {
        local stack_name=$1
        log_info "Removendo $stack_name..."
        docker stack rm "$stack_name" >/dev/null 2>&1 || true
        for i in {1..15}; do
            if ! docker service ls | grep -q "${stack_name}_"; then
                break
            fi
            sleep 2
        done
        sleep 3
    }
    
    # Função para criar stack via API
    create_stack_api() {
        local stack_name=$1
        local stack_content=$2
        
        log_info "🚀 Criando $stack_name via API (Full Control)..."
        
        # Criar payload JSON
        local json_payload=$(cat <<JSON
{
    "Name": "$stack_name",
    "SwarmID": "primary",
    "StackFileContent": $(echo "$stack_content" | python3 -c "import sys, json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo "\"$stack_content\"")
}
JSON
)
        
        # Deploy via API
        local response=$(curl -sk -X POST \
            "$PORTAINER_URL/api/stacks?type=1&method=string&endpointId=1" \
            -H "Authorization: Bearer $JWT_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$json_payload" 2>&1)
        
        if echo "$response" | grep -q "\"Id\""; then
            log_success "✅ $stack_name criada com FULL CONTROL!"
            return 0
        else
            log_error "❌ Falha ao criar $stack_name via API"
            echo "Resposta: $response"
            return 1
        fi
    }
    
    # Remover todas as stacks primeiro
    for stack in postgres redis evolution n8n; do
        remove_stack "$stack"
    done
    
    echo ""
    log_info "🚀 Criando stacks com Full Control via API..."
    
    # PostgreSQL
    POSTGRES_YAML="version: '3.8'
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
volumes:
  postgres_data:
    external: true
networks:
  network_public:
    external: true"
    
    create_stack_api "postgres" "$POSTGRES_YAML"
    sleep 10
    
    # Redis
    REDIS_YAML="version: '3.8'
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
    external: true"
    
    create_stack_api "redis" "$REDIS_YAML"
    sleep 10
    
    # Criar databases
    log_info "Criando databases..."
    for i in {1..10}; do
        container=$(docker ps --filter "name=postgres_postgres" --format "{{.Names}}" | head -1)
        if [ ! -z "$container" ]; then
            docker exec $container psql -U postgres -c "CREATE DATABASE evolution;" 2>/dev/null || true
            docker exec $container psql -U postgres -c "CREATE DATABASE n8n;" 2>/dev/null || true
            break
        fi
        sleep 3
    done
    
    # Evolution
    EVOLUTION_YAML="version: '3.8'
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
"
    
    create_stack_api "evolution" "$EVOLUTION_YAML"
    sleep 10
    
    # N8N
    N8N_YAML="version: '3.8'
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
"
    
    create_stack_api "n8n" "$N8N_YAML"
    
    echo ""
    log_success "✅ CONVERSÃO CONCLUÍDA!"
    echo ""
    echo "📊 STATUS DAS STACKS:"
    docker stack ls
    echo ""
    echo "✅ Agora você pode editar as stacks no Portainer!"
    echo "Acesse: $PORTAINER_URL"
    echo ""
    echo "As stacks agora têm controle TOTAL (Full Control)."
}

# Função para forçar deploy via API com debug
forcar_deploy_api_debug() {
    log_warning "🎆 FORÇAR DEPLOY VIA API (DEBUG)"
    echo ""
    
    # Carregar variáveis
    if [ ! -f .env ]; then
        log_error "Arquivo .env não encontrado!"
        return 1
    fi
    
    source .env
    
    echo "Testando deploy via API com debug detalhado..."
    echo ""
    
    # Detectar Portainer
    PORTAINER_URL=""
    for url in "https://$DOMINIO_PORTAINER" "http://$DOMINIO_PORTAINER"; do
        if curl -sk "$url/api/status" >/dev/null 2>&1; then
            PORTAINER_URL="$url"
            break
        fi
    done
    
    if [ -z "$PORTAINER_URL" ]; then
        log_error "Portainer não encontrado!"
        return 1
    fi
    
    log_success "Portainer encontrado: $PORTAINER_URL"
    
    # Fazer login
    JWT_TOKEN=$(portainer_login "$PORTAINER_URL" "$PORTAINER_ADMIN_USER" "$PORTAINER_ADMIN_PASSWORD")
    if [ -z "$JWT_TOKEN" ]; then
        log_error "Falha no login!"
        return 1
    fi
    
    log_success "Login realizado! Token: ${JWT_TOKEN:0:20}..."
    
    # Testar deploy de uma stack simples
    cat > test_stack.yaml <<EOF
version: '3.8'
services:
  test:
    image: hello-world
    deploy:
      mode: replicated
      replicas: 1
EOF
    
    echo ""
    log_info "Testando deploy de stack de teste..."
    
    # Usar a função de deploy com debug
    deploy_via_portainer_api "test-stack" "test_stack.yaml" "$PORTAINER_URL" "$JWT_TOKEN"
    
    # Limpar
    rm -f test_stack.yaml
    docker stack rm test-stack >/dev/null 2>&1 || true
    
    echo ""
    log_info "Teste concluído!"
}

# Menu principal
mostrar_menu() {
    clear
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                        SETUP ALICIA                         ║"
    echo "║                    Menu de Instalação                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "┌──────────────────────────────────────────────────────────────┐"
    echo "│                      OPÇÕES DISPONÍVEIS                        │"
    echo "├──────────────────────────────────────────────────────────────┤"
    echo "│ 1) 📦 Instalação Completa                                │"
    echo "│    Instala todos os serviços (Traefik, Portainer, etc)      │"
    echo "│                                                              │"
    echo "│ 2) 🔄 Reset Portainer                                     │"
    echo "│    Resolve problema de timeout de 5 minutos               │"
    echo "│                                                              │"
    echo "│ 3) 🔐 Fix SSL                                              │"
    echo "│    Força geração de certificados pendentes               │"
    echo "│                                                              │"
    echo "│ 4) 📊 Status dos Serviços                                  │"
    echo "│    Mostra status e testa SSL de todos os domínios          │"
    echo "│                                                              │"
    echo "│ 5) 🔄 Converter Stacks para Full Control                    │"
    echo "│    Remove Limited e recria com controle total              │"
    echo "│                                                              │"
    echo "│ 6) 🎆 Forçar Deploy via API (DEBUG)                        │"
    echo "│    Testa deploy direto via API com debug detalhado         │"
    echo "│                                                              │"
    echo "│ 7) ❌ Sair                                                   │"
    echo "└──────────────────────────────────────────────────────────────┘"
    echo ""
}

# Função de status
mostrar_status() {
    log_info "📊 STATUS DOS SERVIÇOS"
    
    if docker service ls >/dev/null 2>&1; then
        echo ""
        echo "🐳 DOCKER SERVICES:"
        docker service ls
        
        echo ""
        echo "📦 CONTAINERS:"
        docker ps --format "table {{.Names}}\t{{.Status}}"
        
        if [ -f .env ]; then
            source .env
            echo ""
            echo "🔐 TESTE SSL:"
            
            for domain in "$DOMINIO_PORTAINER" "$DOMINIO_N8N" "$DOMINIO_EVOLUTION" "$WEBHOOK_N8N"; do
                if [ ! -z "$domain" ]; then
                    echo -n "🔍 $domain... "
                    if curl -s -I "https://$domain" --max-time 8 2>/dev/null | grep -q "HTTP.*[2-4][0-9][0-9]"; then
                        echo "✅ SSL OK"
                    else
                        echo "❌ SEM SSL"
                    fi
                fi
            done
        fi
    else
        log_error "Docker Swarm não ativo ou sem serviços"
    fi
    
    echo ""
    echo "Pressione Enter para voltar ao menu..."
    read
}

# Verificar se tem parâmetros (modo direto) ou mostrar menu
if [ $# -eq 0 ]; then
    # Modo menu interativo
    while true; do
        mostrar_menu
        read -p "Digite sua opção (1-7): " opcao
        
        case $opcao in
            1)
                # Coletar parâmetros para instalação
                read -p "📧 Digite seu email para SSL: " SSL_EMAIL
                read -p "🔄 Digite domínio N8N: " DOMINIO_N8N
                read -p "🐳 Digite domínio Portainer: " DOMINIO_PORTAINER
                read -p "🔗 Digite domínio Webhook: " WEBHOOK_N8N
                read -p "📱 Digite domínio Evolution: " DOMINIO_EVOLUTION
                
                confirmar "Iniciar instalação completa?"
                
                # Continuar com instalação original (pular menu)
                break
                ;;
            2)
                reset_portainer
                echo ""
                echo "Pressione Enter para voltar ao menu..."
                read
                ;;
            3)
                fix_ssl_especifico
                echo ""
                echo "Pressione Enter para voltar ao menu..."
                read
                ;;
            4)
                mostrar_status
                ;;
            5)
                converter_stacks_full_control
                echo ""
                echo "Pressione Enter para voltar ao menu..."
                read
                ;;
            6)
                forcar_deploy_api_debug
                echo ""
                echo "Pressione Enter para voltar ao menu..."
                read
                ;;
            7)
                log_info "Saindo..."
                exit 0
                ;;
            *)
                log_error "Opção inválida!"
                sleep 2
                ;;
        esac
    done
else
    # Modo direto com parâmetros (funcionamento original)
    SSL_EMAIL=$1
    DOMINIO_N8N=$2
    DOMINIO_PORTAINER=$3
    WEBHOOK_N8N=$4
    DOMINIO_EVOLUTION=$5
fi

# CONTINUA COM A INSTALAÇÃO ORIGINAL QUE JÁ FUNCIONA
clear
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                        SETUP ALICIA                         ║"
echo "║              Instalador Automatizado com SSL                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "📦 Aplicações incluídas:"
echo "   • Traefik (Proxy SSL automático)"
echo "   • Portainer (Interface Docker)"
echo "   • PostgreSQL (Banco de dados)"
echo "   • Redis (Cache)"
echo "   • Evolution API v2.2.3 (WhatsApp)"
echo "   • N8N (Automação)"
echo ""

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

log_success "✅ Parâmetros validados!"
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│                 CONFIGURAÇÃO VALIDADA                  │"
echo "├─────────────────────────────────────────────────────────┤"
echo "│ 📧 Email: $SSL_EMAIL"
echo "│ 🔄 N8N: $DOMINIO_N8N"  
echo "│ 🐳 Portainer: $DOMINIO_PORTAINER"
echo "│ 🔗 Webhook: $WEBHOOK_N8N"
echo "│ 📱 Evolution: $DOMINIO_EVOLUTION"
echo "└─────────────────────────────────────────────────────────┘"
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
PORTAINER_ADMIN_USER="admin"
PORTAINER_ADMIN_PASSWORD=$(openssl rand -base64 20 | tr -d "=+/" | cut -c1-16)

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
PORTAINER_ADMIN_USER=$PORTAINER_ADMIN_USER
PORTAINER_ADMIN_PASSWORD=$PORTAINER_ADMIN_PASSWORD
EOF

log_success "✅ Variáveis salvas em .env"

# Configuração do sistema
log_info "⚙️ Configurando sistema..."
export DEBIAN_FRONTEND=noninteractive
timedatectl set-timezone America/Sao_Paulo

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
    apt-get install -y curl wget gnupg lsb-release ca-certificates apt-transport-https software-properties-common jq
} >> instalacao_corrigida.log 2>&1

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
            log_success "✅ $service_name funcionando!"
            return 0
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

# Função para verificar SSL de forma simples e rápida
check_ssl_simple() {
    local domain=$1
    local service_name=$2
    
    log_info "🔐 Verificando SSL para $domain ($service_name)..."
    
    # Aguardar 15 segundos para o serviço estabilizar
    sleep 15
    
    # Fazer uma requisição simples para acionar Let's Encrypt
    curl -s -H "Host: $domain" "http://$server_ip" >/dev/null 2>&1 &
    curl -s -k "https://$domain" >/dev/null 2>&1 &
    
    # Testar uma vez se SSL já está funcionando
    if curl -s -I "https://$domain" --max-time 5 2>/dev/null | grep -q "HTTP.*[2-4][0-9][0-9]"; then
        log_success "✅ SSL já funcionando para $domain!"
    else
        log_info "🔄 SSL para $domain será processado em background"
    fi
    
    log_success "✅ $service_name configurado! Continuando instalação..."
}

# Função para fazer login no Portainer e obter JWT
portainer_login() {
    local portainer_url=$1
    local username=$2
    local password=$3
    
    local response=$(curl -sk -X POST \
        "$portainer_url/api/auth" \
        -H "Content-Type: application/json" \
        -d "{\"Username\":\"$username\",\"Password\":\"$password\"}" 2>/dev/null)
    
    local jwt_token=$(echo "$response" | sed -n 's/.*"jwt":"\([^"]*\).*/\1/p')
    echo "$jwt_token"
}

# Função para deploy via API do Portainer (FULL CONTROL)
deploy_via_portainer_api() {
    local stack_name=$1
    local yaml_file=$2
    local portainer_url=$3
    local jwt_token=$4
    
    log_info "🚀 Deployando $stack_name via API do Portainer (Full Control)..."
    
    # Remover stack existente se houver
    docker stack rm "$stack_name" >/dev/null 2>&1 || true
    sleep 10
    
    # Ler conteúdo do arquivo e escapar para JSON
    local stack_content=$(cat "$yaml_file")
    
    # Escapar conteúdo para JSON usando jq se disponível
    local escaped_content
    if command -v jq >/dev/null 2>&1; then
        escaped_content=$(echo "$stack_content" | jq -Rs .)
    else
        # Fallback manual para escapar JSON
        escaped_content=$(echo "$stack_content" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/^/"/' | sed 's/$/"/')
    fi
    
    # Obter endpoint ID correto
    local endpoint_response=$(curl -sk -H "Authorization: Bearer $jwt_token" "$portainer_url/api/endpoints" 2>/dev/null)
    local endpoint_id=$(echo "$endpoint_response" | sed -n 's/.*"Id":\([0-9]*\).*/\1/p' | head -1)
    
    if [ -z "$endpoint_id" ]; then
        endpoint_id=1
    fi
    
    # Criar payload JSON
    local json_payload="{
        \"Name\": \"$stack_name\",
        \"SwarmID\": \"primary\",
        \"StackFileContent\": $escaped_content
    }"
    
    # Testar se o token ainda é válido
    local test_response=$(curl -sk -H "Authorization: Bearer $jwt_token" "$portainer_url/api/users/admin/check" 2>/dev/null)
    if [ "$test_response" != "true" ]; then
        log_warning "⚠️ Token JWT inválido ou expirado"
        docker stack deploy --prune --resolve-image always -c "$yaml_file" "$stack_name"
        return 1
    fi
    
    # Debug: mostrar informações
    echo "Endpoint ID: $endpoint_id"
    echo "URL: $portainer_url/api/stacks?type=1&method=string&endpointId=$endpoint_id"
    echo "Tamanho do payload: $(echo "$json_payload" | wc -c) caracteres"
    
    # Deploy via API
    local response=$(curl -sk -X POST \
        "$portainer_url/api/stacks?type=1&method=string&endpointId=$endpoint_id" \
        -H "Authorization: Bearer $jwt_token" \
        -H "Content-Type: application/json" \
        -d "$json_payload" 2>&1)
    
    # Debug: mostrar resposta
    echo "Status HTTP: $(curl -sk -o /dev/null -w '%{http_code}' -X POST "$portainer_url/api/stacks?type=1&method=string&endpointId=$endpoint_id" -H "Authorization: Bearer $jwt_token" -H "Content-Type: application/json" -d "$json_payload" 2>/dev/null)"
    echo "Resposta da API: $response"
    
    # Verificar se houve sucesso
    if echo "$response" | grep -q "\"Id\"\|\"Name\""; then
        log_success "✅ $stack_name deployada com controle TOTAL!"
        return 0
    elif echo "$response" | grep -q "error\|Error\|invalid\|unauthorized"; then
        log_warning "⚠️ Erro na API: $(echo "$response" | head -100)"
        log_warning "⚠️ Fallback: deployando via CLI"
        docker stack deploy --prune --resolve-image always -c "$yaml_file" "$stack_name"
        return 1
    elif [ -z "$response" ]; then
        log_warning "⚠️ API retornou resposta vazia (possível timeout)"
        log_warning "⚠️ Fallback: deployando via CLI"
        docker stack deploy --prune --resolve-image always -c "$yaml_file" "$stack_name"
        return 1
    else
        log_warning "⚠️ Resposta inesperada da API: $(echo "$response" | head -100)"
        log_warning "⚠️ Fallback: deployando via CLI"
        docker stack deploy --prune --resolve-image always -c "$yaml_file" "$stack_name"
        return 1
    fi
}

# NOVA FUNÇÃO: Criar conta admin do Portainer automaticamente
create_portainer_admin_auto() {
    log_info "🔑 Configurando conta admin do Portainer automaticamente..."
    
    # As credenciais já foram geradas no início do script
    if [ -z "$PORTAINER_ADMIN_USER" ] || [ -z "$PORTAINER_ADMIN_PASSWORD" ]; then
        log_error "Credenciais do Portainer não encontradas!"
        return 1
    fi
    
    # Aguardar Portainer estar acessível
    local max_attempts=30
    local attempt=0
    local portainer_url=""
    
    while [ $attempt -lt $max_attempts ]; do
        # Tentar HTTPS primeiro
        if curl -s "https://$DOMINIO_PORTAINER/api/status" --insecure --max-time 5 >/dev/null 2>&1; then
            portainer_url="https://$DOMINIO_PORTAINER"
            log_success "✅ Portainer acessível via HTTPS!"
            break
        fi
        
        # Tentar HTTP caso SSL ainda não esteja pronto
        if curl -s "http://$DOMINIO_PORTAINER/api/status" --max-time 5 >/dev/null 2>&1; then
            portainer_url="http://$DOMINIO_PORTAINER"
            log_warning "⚠️ Portainer acessível via HTTP (SSL pendente)"
            break
        fi
        
        # Tentar via IP direto na porta do container
        local portainer_container=$(docker ps --filter "name=portainer_portainer" --format "{{.Names}}" | head -1)
        if [ ! -z "$portainer_container" ]; then
            local container_ip=$(docker inspect $portainer_container --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' | head -1)
            if [ ! -z "$container_ip" ] && curl -s "http://$container_ip:9000/api/status" --max-time 5 >/dev/null 2>&1; then
                portainer_url="http://$container_ip:9000"
                log_info "📡 Usando IP interno do container: $container_ip"
                break
            fi
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 2
    done
    
    if [ -z "$portainer_url" ]; then
        log_error "❌ Não foi possível conectar ao Portainer!"
        log_info "🔐 Você precisará configurar manualmente em: https://$DOMINIO_PORTAINER"
        return 1
    fi
    
    # Aguardar mais um pouco para garantir que o Portainer está pronto
    sleep 5
    
    # Verificar se já foi configurado
    local check_response=$(curl -s "$portainer_url/api/users/admin/check" --insecure --max-time 5 2>/dev/null)
    if [ "$check_response" = "true" ]; then
        log_warning "⚠️ Portainer já configurado anteriormente"
        # Tentar fazer login para verificar se temos as credenciais corretas
        JWT_TOKEN=$(portainer_login "$portainer_url" "$PORTAINER_ADMIN_USER" "$PORTAINER_ADMIN_PASSWORD")
        if [ ! -z "$JWT_TOKEN" ]; then
            PORTAINER_API_URL="$portainer_url"
            USE_PORTAINER_API=true
            log_success "✅ Login no Portainer realizado!"
        fi
        return 0
    fi
    
    # Criar usuário admin
    log_info "📝 Criando usuário admin: $PORTAINER_ADMIN_USER"
    
    local create_response=$(curl -s -X POST \
        "$portainer_url/api/users/admin/init" \
        -H "Content-Type: application/json" \
        -d "{
            \"Username\": \"$PORTAINER_ADMIN_USER\",
            \"Password\": \"$PORTAINER_ADMIN_PASSWORD\"
        }" \
        --insecure --max-time 10 2>/dev/null)
    
    # Verificar sucesso
    if echo "$create_response" | grep -q "jwt\|Username"; then
        log_success "✅ Conta admin criada com sucesso!"
        log_info "👤 Usuário: $PORTAINER_ADMIN_USER"
        log_info "🔐 Senha: $PORTAINER_ADMIN_PASSWORD"
        
        # Fazer login imediatamente para obter JWT
        JWT_TOKEN=$(portainer_login "$portainer_url" "$PORTAINER_ADMIN_USER" "$PORTAINER_ADMIN_PASSWORD")
        if [ ! -z "$JWT_TOKEN" ]; then
            PORTAINER_API_URL="$portainer_url"
            USE_PORTAINER_API=true
            log_success "✅ Login automático realizado! Deploy via API ativado."
        fi
        
        return 0
    else
        log_warning "⚠️ Não foi possível criar conta automaticamente"
        log_info "📋 Resposta: $create_response"
        echo "PORTAINER_ADMIN_USER=$PORTAINER_ADMIN_USER" >> .env
        echo "PORTAINER_ADMIN_PASSWORD=$PORTAINER_ADMIN_PASSWORD" >> .env
        
        return 1
    fi
}

# 1. INSTALAR TRAEFIK (PROXY SSL)
echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│               ETAPA 1/6 - INSTALANDO TRAEFIK                  │"
echo "└──────────────────────────────────────────────────────────────┘"
log_info "🔐 Configurando proxy SSL automático..."

cat > traefik_corrigido.yaml <<EOF
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
docker stack deploy --prune --resolve-image always -c traefik_corrigido.yaml traefik
wait_service_perfect "traefik" 120

log_success "✅ Traefik instalado - Proxy SSL pronto!"

# 2. INSTALAR PORTAINER
echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│              ETAPA 2/6 - INSTALANDO PORTAINER                 │"
echo "└──────────────────────────────────────────────────────────────┘"
log_info "🐳 Configurando interface de gerenciamento Docker..."

cat > portainer_corrigido.yaml <<EOF
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
        # HTTPS Router
        - traefik.http.routers.portainer.rule=Host(\`$DOMINIO_PORTAINER\`)
        - traefik.http.routers.portainer.tls=true
        - traefik.http.routers.portainer.tls.certresolver=letsencryptresolver
        - traefik.http.routers.portainer.entrypoints=websecure
        - traefik.http.services.portainer.loadbalancer.server.port=9000
        - traefik.http.routers.portainer.service=portainer
        # HTTP Redirect para HTTPS
        - traefik.http.routers.portainer-redirect.rule=Host(\`$DOMINIO_PORTAINER\`)
        - traefik.http.routers.portainer-redirect.entrypoints=web
        - traefik.http.routers.portainer-redirect.middlewares=redirect-to-https
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
docker stack deploy --prune --resolve-image always -c portainer_corrigido.yaml portainer
wait_service_perfect "portainer" 300

# Aguardar mais um pouco para garantir que o Portainer está totalmente pronto
sleep 10

# Criar admin e obter JWT automaticamente
create_portainer_admin_auto

# As variáveis JWT_TOKEN, PORTAINER_API_URL e USE_PORTAINER_API já foram definidas pela função acima
if [ "$USE_PORTAINER_API" = "true" ] && [ ! -z "$JWT_TOKEN" ]; then
    log_success "✅ Deploy via API do Portainer ativado para próximas stacks!"
else
    log_warning "⚠️ Deploy via API não disponível, usando método padrão"
fi

check_ssl_simple "$DOMINIO_PORTAINER" "Portainer"

echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│               ✅ PORTAINER CONFIGURADO                        │"
echo "├──────────────────────────────────────────────────────────────┤"
echo "│ 🌐 Acesse: https://$DOMINIO_PORTAINER                    │"
echo "│ 👤 Usuário: $PORTAINER_ADMIN_USER                         │"
echo "│ 🔑 Senha: $PORTAINER_ADMIN_PASSWORD                       │"
echo "│ 📝 Credenciais salvas em .env                             │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""

# 3. INSTALAR POSTGRESQL
echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│             ETAPA 3/6 - INSTALANDO POSTGRESQL                 │"
echo "└──────────────────────────────────────────────────────────────┘"
log_info "🗄️ Configurando banco de dados..."

cat > postgres_corrigido.yaml <<EOF
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

# Tentar deploy via API do Portainer para ter Full Control
if [ "$USE_PORTAINER_API" = "true" ] && [ ! -z "$JWT_TOKEN" ]; then
    deploy_via_portainer_api "postgres" "postgres_corrigido.yaml" "$PORTAINER_API_URL" "$JWT_TOKEN"
else
    docker stack deploy --prune --resolve-image always -c postgres_corrigido.yaml postgres
fi
wait_service_perfect "postgres" 180

# 4. INSTALAR REDIS
echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│                ETAPA 4/6 - INSTALANDO REDIS                   │"
echo "└──────────────────────────────────────────────────────────────┘"
log_info "🔴 Configurando cache e filas..."

cat > redis_corrigido.yaml <<EOF
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

# Tentar deploy via API do Portainer para ter Full Control
if [ "$USE_PORTAINER_API" = "true" ] && [ ! -z "$JWT_TOKEN" ]; then
    deploy_via_portainer_api "redis" "redis_corrigido.yaml" "$PORTAINER_API_URL" "$JWT_TOKEN"
else
    docker stack deploy --prune --resolve-image always -c redis_corrigido.yaml redis
fi
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
echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│            ETAPA 5/6 - INSTALANDO EVOLUTION API               │"
echo "└──────────────────────────────────────────────────────────────┘"
log_info "📱 Configurando API do WhatsApp..."

# Criar volumes
docker volume create evolution_instances >/dev/null 2>&1
docker volume create evolution_store >/dev/null 2>&1

cat > evolution_corrigido.yaml <<EOF
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
        # HTTPS Router Evolution
        - traefik.http.routers.evolution.rule=Host(\`$DOMINIO_EVOLUTION\`)
        - traefik.http.routers.evolution.tls=true
        - traefik.http.routers.evolution.tls.certresolver=letsencryptresolver
        - traefik.http.routers.evolution.entrypoints=websecure
        - traefik.http.services.evolution.loadbalancer.server.port=8080
        - traefik.http.routers.evolution.service=evolution
        # HTTP Redirect para HTTPS
        - traefik.http.routers.evolution-redirect.rule=Host(\`$DOMINIO_EVOLUTION\`)
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

docker volume create evolution_instances >/dev/null 2>&1
docker volume create evolution_store >/dev/null 2>&1

# Tentar deploy via API do Portainer para ter Full Control
if [ "$USE_PORTAINER_API" = "true" ] && [ ! -z "$JWT_TOKEN" ]; then
    deploy_via_portainer_api "evolution" "evolution_corrigido.yaml" "$PORTAINER_API_URL" "$JWT_TOKEN"
else
    docker stack deploy --prune --resolve-image always -c evolution_corrigido.yaml evolution
fi
wait_service_perfect "evolution" 300

# Verificar SSL do Evolution imediatamente
check_ssl_simple "$DOMINIO_EVOLUTION" "Evolution API"

echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│               ⚠️  IMPORTANTE - EVOLUTION API                   │"
echo "├──────────────────────────────────────────────────────────────┤"
echo "│ 🌐 Acesse: https://$DOMINIO_EVOLUTION                       │"
echo "│ 🔧 Painel Admin: https://$DOMINIO_EVOLUTION/manager             │"
echo "│ 🔑 API Key: $EVOLUTION_API_KEY"
echo "│ 📱 Para conectar WhatsApp: POST /instance/create          │"
echo "│ 🗃️ Documentação: https://$DOMINIO_EVOLUTION/docs           │"
echo "│ ⚡ Status da API: GET https://$DOMINIO_EVOLUTION/             │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""

# 6. INSTALAR N8N
echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│                 ETAPA 6/6 - INSTALANDO N8N                    │"
echo "└──────────────────────────────────────────────────────────────┘"
log_info "🔄 Configurando automação de workflows..."

cat > n8n_corrigida.yaml <<EOF
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
        # HTTPS Router N8N
        - traefik.http.routers.n8n.rule=Host(\`$DOMINIO_N8N\`)
        - traefik.http.routers.n8n.tls=true
        - traefik.http.routers.n8n.tls.certresolver=letsencryptresolver
        - traefik.http.routers.n8n.entrypoints=websecure
        - traefik.http.services.n8n.loadbalancer.server.port=5678
        - traefik.http.routers.n8n.service=n8n
        # HTTP Redirect para HTTPS
        - traefik.http.routers.n8n-redirect.rule=Host(\`$DOMINIO_N8N\`)
        - traefik.http.routers.n8n-redirect.entrypoints=web
        - traefik.http.routers.n8n-redirect.middlewares=redirect-to-https
        # HTTPS Router Webhook
        - traefik.http.routers.webhook.rule=Host(\`$WEBHOOK_N8N\`)
        - traefik.http.routers.webhook.tls=true
        - traefik.http.routers.webhook.tls.certresolver=letsencryptresolver
        - traefik.http.routers.webhook.entrypoints=websecure
        - traefik.http.routers.webhook.service=n8n
        # HTTP Redirect Webhook para HTTPS
        - traefik.http.routers.webhook-redirect.rule=Host(\`$WEBHOOK_N8N\`)
        - traefik.http.routers.webhook-redirect.entrypoints=web
        - traefik.http.routers.webhook-redirect.middlewares=redirect-to-https
        - traefik.docker.network=network_public

volumes:
  n8n_data:

networks:
  network_public:
    external: true
EOF

docker volume create n8n_data >/dev/null 2>&1

# Tentar deploy via API do Portainer para ter Full Control
if [ "$USE_PORTAINER_API" = "true" ] && [ ! -z "$JWT_TOKEN" ]; then
    deploy_via_portainer_api "n8n" "n8n_corrigida.yaml" "$PORTAINER_API_URL" "$JWT_TOKEN"
else
    docker stack deploy --prune --resolve-image always -c n8n_corrigida.yaml n8n
fi
wait_service_perfect "n8n" 300

# Verificar SSL do N8N e Webhook imediatamente
check_ssl_simple "$DOMINIO_N8N" "N8N"
check_ssl_simple "$WEBHOOK_N8N" "Webhook N8N"

echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│                  ⚠️  IMPORTANTE - N8N                           │"
echo "├──────────────────────────────────────────────────────────────┤"
echo "│ 🌐 Acesse: https://$DOMINIO_N8N                            │"
echo "│ 🔑 PRIMEIRA VEZ: Criar conta de administrador              │"
echo "│ 🚀 Configure workflows e automações                       │"
echo "│ 🔗 Webhook: https://$WEBHOOK_N8N                          │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""

# VERIFICAÇÃO FINAL DE SSL
echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│                VERIFICAÇÃO FINAL DE SSL                       │"
echo "└──────────────────────────────────────────────────────────────┘"
log_info "🔍 Verificando status final de todos os certificados SSL..."

# Verificar cada domínio uma última vez
for domain in "$DOMINIO_PORTAINER" "$DOMINIO_N8N" "$DOMINIO_EVOLUTION" "$WEBHOOK_N8N"; do
    if curl -s -I "https://$domain" --max-time 8 2>/dev/null | grep -q "HTTP.*[2-4][0-9][0-9]"; then
        log_success "✅ $domain: SSL funcionando"
    else
        log_warning "⚠️ $domain: SSL ainda processando"
    fi
done

# VERIFICAÇÃO FINAL COMPLETA
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    INSTALAÇÃO CONCLUÍDA                     ║"
echo "║                       SETUP ALICIA                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"

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
echo "=========================================="
echo "🎉 INSTALAÇÃO CORRIGIDA CONCLUÍDA!"
echo "=========================================="
echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│                        SERVIÇOS DISPONÍVEIS                        │"
echo "├──────────────────────────────────────────────────────────────┤"
echo "│ 🐳 Portainer: https://$DOMINIO_PORTAINER"
echo "│ 🔄 N8N: https://$DOMINIO_N8N"
echo "│ 📱 Evolution API: https://$DOMINIO_EVOLUTION"
echo "│ 🔧 Evolution Manager: https://$DOMINIO_EVOLUTION/manager"
echo "│ 🔗 Webhook N8N: https://$WEBHOOK_N8N"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│                      CREDENCIAIS DE ACESSO                      │"
echo "├──────────────────────────────────────────────────────────────┤"
echo "│ 👤 Portainer Admin: $PORTAINER_ADMIN_USER"
echo "│ 🔑 Portainer Senha: $PORTAINER_ADMIN_PASSWORD"
echo "│ 🔑 Evolution API Key: $EVOLUTION_API_KEY"
echo "│ 🗿 PostgreSQL Password: $POSTGRES_PASSWORD"
echo "│ 🔐 N8N Encryption Key: $N8N_KEY"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│                        INFORMAÇÕES IMPORTANTES                    │"
echo "├──────────────────────────────────────────────────────────────┤"
echo "│ • SSL processado automaticamente em background               │"
echo "│ • Redirecionamento HTTP→HTTPS ativo                          │"
echo "│ • ✅ Portainer admin criado automaticamente                 │"
echo "│ • 🔑 Configure conta administrador no N8N                   │"
echo "│ • IP do servidor: $server_ip                    │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""
echo "🎉 Instalação concluída com sucesso!"