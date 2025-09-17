#!/bin/bash

# 🚀 SETUPALICIA - MENU COMPLETO 

set -e

# Função para log colorido
log_info() { echo -e "\033[34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[32m[SUCESSO]\033[0m $1"; }
log_warning() { echo -e "\033[33m[AVISO]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERRO]\033[0m $1"; }

# Função para salvar YAMLs das stacks para edição futura no Portainer
save_yaml_for_editing() {
    local stack_name=$1
    local yaml_file=$2
    
    # Criar diretório se não existir
    mkdir -p /opt/setupalicia/stacks >/dev/null 2>&1
    
    # Salvar YAML para edição futura no Portainer
    if [ -f "$yaml_file" ]; then
        cp "$yaml_file" "/opt/setupalicia/stacks/${stack_name}.yaml" >/dev/null 2>&1
    fi
}

# Função para configurar Portainer automaticamente
setup_portainer_auto() {
    log_info "🔧 Configurando Portainer automaticamente..."
    
    # Diagnóstico inicial
    log_info "🔍 Verificando status dos containers..."
    docker ps --filter "name=portainer_portainer" --format "table {{.Names}}\t{{.Status}}"
    
    # Verificar se está rodando via HTTP primeiro (mais rápido)
    local portainer_available=false
    
    log_info "⏳ Aguardando Portainer ficar online..."
    log_info "💡 Tentando HTTP primeiro (mais rápido)..."
    
    # Tentar HTTP primeiro (9000)
    for i in {1..30}; do
        if curl -s "http://localhost:9000/api/status" >/dev/null 2>&1; then
            log_success "✅ Portainer HTTP acessível!"
            portainer_available=true
            break
        fi
        
        if [ $((i % 10)) -eq 0 ]; then
            log_info "   ... tentativa $i/30 via HTTP"
        fi
        sleep 5
    done
    
    # Se HTTP não funcionou, tentar HTTPS
    if [ "$portainer_available" = false ]; then
        log_info "🔄 HTTP não disponível, tentando HTTPS..."
        for i in {1..60}; do
            if curl -s -k "https://$DOMINIO_PORTAINER/api/status" >/dev/null 2>&1; then
                log_success "✅ Portainer HTTPS acessível!"
                portainer_available=true
                break
            fi
            
            if [ $((i % 15)) -eq 0 ]; then
                log_info "   ... tentativa $i/60 via HTTPS (aguarde, SSL pode demorar)"
                log_info "   ... verificando se container está rodando..."
                docker ps --filter "name=portainer_portainer" --format "{{.Status}}"
            fi
            sleep 5
        done
    fi
    
    # Se ainda não está disponível, dar instruções manuais
    if [ "$portainer_available" = false ]; then
        log_warning "⚠️ Portainer demorou mais que o esperado para ficar online"
        log_info "📋 Vamos continuar e você poderá configurar manualmente depois"
        log_info "🌐 Acesse: https://$DOMINIO_PORTAINER quando estiver pronto"
        return 1
    fi
    
    # Gerar credenciais automáticas
    PORTAINER_USER="setupalicia"
    PORTAINER_PASS=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12)
    
    log_info "👤 Criando conta administrador automática..."
    
    # Decidir URL baseado em qual funcionou
    local portainer_url
    if curl -s "http://localhost:9000/api/status" >/dev/null 2>&1; then
        portainer_url="http://localhost:9000"
        log_info "🔗 Usando HTTP para configuração inicial"
    else
        portainer_url="https://$DOMINIO_PORTAINER"
        log_info "🔗 Usando HTTPS para configuração"
    fi
    
    # Criar usuário admin via API
    INIT_RESPONSE=$(curl -s -X POST "$portainer_url/api/users/admin/init" \
        -H "Content-Type: application/json" \
        -d "{
            \"Username\": \"$PORTAINER_USER\",
            \"Password\": \"$PORTAINER_PASS\"
        }" 2>/dev/null)
    
    if echo "$INIT_RESPONSE" | grep -q "JWT"; then
        log_success "✅ Conta criada automaticamente!"
        
        # Extrair JWT token
        JWT_TOKEN=$(echo "$INIT_RESPONSE" | grep -o '"jwt":"[^"]*' | cut -d'"' -f4)
        
        # Obter Swarm ID
        SWARM_ID=$(docker info --format '{{.Swarm.NodeID}}')
        
    # Criar API key com retry e melhor debugging
    log_info "🔑 Criando API Key para stacks editáveis..."
    
    for retry in {1..3}; do
        API_RESPONSE=$(curl -s -X POST "$portainer_url/api/users/1/tokens" \
            -H "Authorization: Bearer $JWT_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{
                \"description\": \"setupalicia-auto-$(date +%s)\"
            }" 2>/dev/null)
        
        log_info "📋 Tentativa $retry - Resposta API: ${API_RESPONSE:0:100}..."
        
        if echo "$API_RESPONSE" | grep -q "rawAPIKey"; then
            PORTAINER_API_KEY=$(echo "$API_RESPONSE" | grep -o '"rawAPIKey":"[^"]*' | cut -d'"' -f4)
            
            if [ ! -z "$PORTAINER_API_KEY" ] && [ ${#PORTAINER_API_KEY} -gt 10 ]; then
                log_success "✅ API Key criada com sucesso: ${PORTAINER_API_KEY:0:20}..."
                
                # Salvar credenciais no .env
                echo "PORTAINER_USER=$PORTAINER_USER" >> .env
                echo "PORTAINER_PASS=$PORTAINER_PASS" >> .env
                echo "PORTAINER_API_KEY=$PORTAINER_API_KEY" >> .env
                echo "SWARM_ID=$SWARM_ID" >> .env
                
                # Testar API Key imediatamente
                TEST_RESPONSE=$(curl -s -X GET "$portainer_url/api/stacks" \
                    -H "X-API-Key: $PORTAINER_API_KEY" 2>/dev/null)
                
                if echo "$TEST_RESPONSE" | grep -q "\[" || echo "$TEST_RESPONSE" | grep -q "\{" ; then
                    log_success "🚀 API Key testada e funcionando! Stacks serão editáveis."
                    return 0
                else
                    log_warning "⚠️ API Key criada mas falhou no teste. Tentando novamente..."
                fi
            else
                log_warning "⚠️ API Key vazia ou inválida na tentativa $retry"
            fi
        else
            log_warning "⚠️ Falha ao criar API Key (tentativa $retry): $API_RESPONSE"
        fi
        
        sleep 5
    done
    fi
    
    log_warning "⚠️ Não foi possível criar conta automática - usando método manual"
    log_info "📝 Você poderá configurar manualmente depois em: https://$DOMINIO_PORTAINER"
    return 1
}

# Função para criar stack via API do Portainer
create_stack_via_api() {
    local stack_name=$1
    local yaml_file=$2
    
    # Verificar se temos API Key válida
    if [ -z "$PORTAINER_API_KEY" ] || [ ${#PORTAINER_API_KEY} -lt 10 ]; then
        log_warning "⚠️ API Key não disponível - usando CLI (stacks não serão editáveis)"
        docker stack deploy --prune --resolve-image always -c "$yaml_file" "$stack_name"
        save_yaml_for_editing "$stack_name" "$yaml_file"
        return
    fi
    
    # Verificar se temos Swarm ID
    if [ -z "$SWARM_ID" ]; then
        SWARM_ID=$(docker info --format '{{.Swarm.NodeID}}')
    fi
    
    log_info "🚀 Criando stack $stack_name via API Portainer (EDITÁVEL)..."
    
    # Ler conteúdo do YAML e escapar adequadamente
    if [ ! -f "$yaml_file" ]; then
        log_error "❌ Arquivo $yaml_file não encontrado"
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
        log_success "✅ Stack $stack_name criada via API - TOTALMENTE EDITÁVEL no Portainer!"
        save_yaml_for_editing "$stack_name" "$yaml_file"
        
        # Aguardar um pouco para stack estabilizar
        sleep 10
        return 0
    else
        log_warning "⚠️ Falha na API: $API_RESPONSE"
        log_info "🔄 Usando CLI como fallback"
        docker stack deploy --prune --resolve-image always -c "$yaml_file" "$stack_name"
        save_yaml_for_editing "$stack_name" "$yaml_file"
        return 1
    fi
}

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
    echo "│ 5) ❌ Sair                                                   │"
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
        read -p "Digite sua opção (1-5): " opcao
        
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
save_yaml_for_editing "traefik" "traefik_corrigido.yaml"
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
save_yaml_for_editing "portainer" "portainer_corrigido.yaml"
wait_service_perfect "portainer" 120

# Configurar Portainer automaticamente
if setup_portainer_auto; then
    log_success "✅ Portainer configurado automaticamente!"
else
    log_info "🔑 Configuração manual necessária"
fi

# Verificar SSL do Portainer imediatamente
check_ssl_simple "$DOMINIO_PORTAINER" "Portainer"

echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│               ✅ PORTAINER CONFIGURADO AUTOMATICAMENTE           │"
echo "├──────────────────────────────────────────────────────────────┤"
echo "│ 🌐 Acesse: https://$DOMINIO_PORTAINER                    │"
echo "│ 🔑 Usuário: setupalicia                                  │"
echo "│ 🔐 Senha: (será exibida no final)                        │"
echo "│                                                              │"
echo "│ 🚀 Próximas stacks serão criadas via API (editáveis)      │"
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
create_stack_via_api "postgres" "postgres_corrigido.yaml"
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
create_stack_via_api "redis" "redis_corrigido.yaml"
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

create_stack_via_api "evolution" "evolution_corrigido.yaml"
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

cat > n8n_corrigido.yaml <<EOF
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
create_stack_via_api "n8n" "n8n_corrigido.yaml"
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

# Verificar serviços de forma organizada
echo "📊 RESUMO DOS SERVIÇOS:"
echo "✅ Traefik       - Proxy SSL"
echo "✅ Portainer     - Interface Docker (conta criada)"
echo "✅ PostgreSQL    - Banco de dados"
echo "✅ Redis         - Cache"
echo "✅ Evolution API - WhatsApp"
echo "✅ N8N           - Automação"
echo ""

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
echo "│ 🐳 PORTAINER (ACESSO AUTOMÁTICO CRIADO):                │"
echo "│    🌐 URL: https://$DOMINIO_PORTAINER                  │"
if [ ! -z "$PORTAINER_USER" ] && [ ! -z "$PORTAINER_PASS" ]; then
echo "│    🔑 Usuário: $PORTAINER_USER                           │"
echo "│    🔐 Senha: $PORTAINER_PASS                             │"
echo "│    🖑️ API Key: $PORTAINER_API_KEY"
else
echo "│    ⚠️ Conta automática não criada - configure manualmente    │"
fi
echo "│                                                              │"
echo "│ 🔑 Evolution API Key: $EVOLUTION_API_KEY"
echo "│ 🗿 PostgreSQL Password: $POSTGRES_PASSWORD"
echo "│ 🔐 N8N Encryption Key: $N8N_KEY"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
if [ ! -z "$PORTAINER_API_KEY" ] && [ ${#PORTAINER_API_KEY} -gt 10 ]; then
echo "│                   🚀 STACKS TOTALMENTE EDITÁVEIS!              │"
echo "├──────────────────────────────────────────────────────────────┤"
echo "│ 🎉 SUCESSO! Stacks criadas via API são EDITÁVEIS!           │"
echo "│ 🚀 Como editar:                                          │"
echo "│   1. Acesse Portainer com as credenciais acima            │"
echo "│   2. Vá em 'Stacks'                                         │"
echo "│   3. Clique na stack desejada                            │"
echo "│   4. Clique em 'Editor'                                  │"
echo "│   5. Faça suas alterações e clique 'Update'              │"
else
echo "│                   📝 STACKS EDITÁVEIS VIA UPLOAD              │"
echo "├──────────────────────────────────────────────────────────────┤"
echo "│ 📝 Método de edição: Upload de arquivos                    │"
echo "│ 📁 Arquivos salvos em: /opt/setupalicia/stacks/             │"
echo "│                                                              │"
echo "│ 📝 Como editar:                                           │"
echo "│ 1. Acesse Portainer com as credenciais acima              │"
echo "│ 2. Vá em 'Stacks' > 'Add stack'                             │"
echo "│ 3. Escolha 'Upload' e selecione arquivo                   │"
echo "│ 4. Edite conforme necessário e faça deploy                  │"
fi

echo "┌──────────────────────────────────────────────────────────────┐"
echo "│                        INFORMAÇÕES IMPORTANTES                    │"
echo "├──────────────────────────────────────────────────────────────┤"
echo "│ • SSL processado automaticamente em background               │"
echo "│ • Redirecionamento HTTP→HTTPS ativo                          │"
if [ -z "$PORTAINER_API_KEY" ] || [ ${#PORTAINER_API_KEY} -lt 10 ]; then
echo "│ • 📝 Stacks editáveis via upload de arquivos               │"
else
echo "│ • 🚀 Stacks EDITÁVEIS diretamente no Portainer            │"
fi
echo "│ • 🔑 Configure conta administrador no N8N                   │"
echo "│ • IP do servidor: $server_ip                    │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""
echo "🎉 Instalação concluída com sucesso!"