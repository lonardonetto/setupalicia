﻿#!/bin/bash

# ðŸš€ SETUPALICIA - MENU COMPLETO + INSTALAÃ‡ÃƒO FUNCIONANDO
# MantÃ©m o script original que funciona 100% + adiciona funcionalidades extras
# Autor: Maicon Ramos - AutomaÃ§Ã£o sem Limites
# VersÃ£o: MENU + ORIGINAL FUNCIONANDO

set -e

# FunÃ§Ã£o para log colorido
log_info() { echo -e "\033[34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[32m[SUCESSO]\033[0m $1"; }
log_warning() { echo -e "\033[33m[AVISO]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERRO]\033[0m $1"; }

# FunÃ§Ã£o para confirmaÃ§Ã£o
confirmar() {
    local mensagem=$1
    echo ""
    echo "ðŸ¤” $mensagem"
    read -p "Digite 'sim' para continuar: " resposta
    if [ "$resposta" != "sim" ]; then
        log_warning "OperaÃ§Ã£o cancelada."
        exit 0
    fi
    log_success "âœ… Confirmado! Continuando..."
    echo ""
}

# FunÃ§Ã£o para reset do Portainer
reset_portainer() {
    log_warning "ðŸ”„ RESET DO PORTAINER"
    echo "Esta operaÃ§Ã£o vai resetar o Portainer (resolve timeout de 5 minutos)"
    
    confirmar "Deseja resetar o Portainer?"
    
    # Carregar variÃ¡veis se existirem
    if [ -f .env ]; then
        source .env
    else
        read -p "Digite o domÃ­nio do Portainer: " DOMINIO_PORTAINER
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
    
    log_success "âœ… Portainer resetado! Acesse: https://$DOMINIO_PORTAINER"
    echo "âš ï¸ Configure senha nos primeiros 5 minutos!"
}

# FunÃ§Ã£o para fix SSL especÃ­fico
fix_ssl_especifico() {
    log_warning "ðŸ” FIX SSL ESPECÃFICO"
    echo "ForForÃ§a certificados SSL para domÃ­nios pendentes"
    
    confirmar "Executar fix SSL?"
    
    # Carregar domÃ­nios
    if [ -f .env ]; then
        source .env
    else
        read -p "Digite domÃ­nio Portainer: " DOMINIO_PORTAINER
        read -p "Digite domÃ­nio N8N: " DOMINIO_N8N
        read -p "Digite domÃ­nio Evolution: " DOMINIO_EVOLUTION
        read -p "Digite domÃ­nio Webhook: " WEBHOOK_N8N
    fi
    
    server_ip=$(curl -s ifconfig.me 2>/dev/null || hostname -I | cut -d' ' -f1)
    
    # ForÃ§ar SSL para cada domÃ­nio usando funÃ§Ã£o simples
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
            log_success "âœ… $domain: SSL OK"
        else
            log_warning "âš ï¸ $domain: SSL pendente"
        fi
    done
}

# Menu principal
mostrar_menu() {
    clear
    echo "â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—"
    echo "â•‘                        SETUP ALICIA                         â•‘"
    echo "â•‘                    Menu de InstalaÃ§Ã£o                       â•‘"
    echo "â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•"
    echo ""
    echo "â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”"
    echo "â”‚                      OPÃ‡Ã•ES DISPONÃVEIS                        â”‚"
    echo "â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤"
    echo "â”‚ 1) ðŸ“¦ InstalaÃ§Ã£o Completa                                â”‚"
    echo "â”‚    Instala todos os serviÃ§os (Traefik, Portainer, etc)      â”‚"
    echo "â”‚                                                              â”‚"
    echo "â”‚ 2) ðŸ”„ Reset Portainer                                     â”‚"
    echo "â”‚    Resolve problema de timeout de 5 minutos               â”‚"
    echo "â”‚                                                              â”‚"
    echo "â”‚ 3) ðŸ” Fix SSL                                              â”‚"
    echo "â”‚    ForÃ§a geraÃ§Ã£o de certificados pendentes               â”‚"
    echo "â”‚                                                              â”‚"
    echo "â”‚ 4) ðŸ“Š Status dos ServiÃ§os                                  â”‚"
    echo "â”‚    Mostra status e testa SSL de todos os domÃ­nios          â”‚"
    echo "â”‚                                                              â”‚"
    echo "â”‚ 5) âŒ Sair                                                   â”‚"
    echo "â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜"
    echo ""
}

# FunÃ§Ã£o de status
mostrar_status() {
    log_info "ðŸ“Š STATUS DOS SERVIÃ‡OS"
    
    if docker service ls >/dev/null 2>&1; then
        echo ""
        echo "ðŸ³ DOCKER SERVICES:"
        docker service ls
        
        echo ""
        echo "ðŸ“¦ CONTAINERS:"
        docker ps --format "table {{.Names}}\t{{.Status}}"
        
        if [ -f .env ]; then
            source .env
            echo ""
            echo "ðŸ” TESTE SSL:"
            
            for domain in "$DOMINIO_PORTAINER" "$DOMINIO_N8N" "$DOMINIO_EVOLUTION" "$WEBHOOK_N8N"; do
                if [ ! -z "$domain" ]; then
                    echo -n "ðŸ” $domain... "
                    if curl -s -I "https://$domain" --max-time 8 2>/dev/null | grep -q "HTTP.*[2-4][0-9][0-9]"; then
                        echo "âœ… SSL OK"
                    else
                        echo "âŒ SEM SSL"
                    fi
                fi
            done
        fi
    else
        log_error "Docker Swarm nÃ£o ativo ou sem serviÃ§os"
    fi
    
    echo ""
    echo "Pressione Enter para voltar ao menu..."
    read
}

# Verificar se tem parÃ¢metros (modo direto) ou mostrar menu
if [ $# -eq 0 ]; then
    # Modo menu interativo
    while true; do
        mostrar_menu
        read -p "Digite sua opÃ§Ã£o (1-5): " opcao
        
        case $opcao in
            1)
                # Coletar parÃ¢metros para instalaÃ§Ã£o
                read -p "ðŸ“§ Digite seu email para SSL: " SSL_EMAIL
                read -p "ðŸ”„ Digite domÃ­nio N8N: " DOMINIO_N8N
                read -p "ðŸ³ Digite domÃ­nio Portainer: " DOMINIO_PORTAINER
                read -p "ðŸ”— Digite domÃ­nio Webhook: " WEBHOOK_N8N
                read -p "ðŸ“± Digite domÃ­nio Evolution: " DOMINIO_EVOLUTION
                
                confirmar "Iniciar instalaÃ§Ã£o completa?"
                
                # Continuar com instalaÃ§Ã£o original (pular menu)
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
                log_error "OpÃ§Ã£o invÃ¡lida!"
                sleep 2
                ;;
        esac
    done
else
    # Modo direto com parÃ¢metros (funcionamento original)
    SSL_EMAIL=$1
    DOMINIO_N8N=$2
    DOMINIO_PORTAINER=$3
    WEBHOOK_N8N=$4
    DOMINIO_EVOLUTION=$5
fi

# CONTINUA COM A INSTALAÃ‡ÃƒO ORIGINAL QUE JÃ FUNCIONA
clear
echo "â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—"
echo "â•‘                        SETUP ALICIA                         â•‘"
echo "â•‘              Instalador Automatizado com SSL                â•‘"
echo "â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•"
echo ""
echo "ðŸ“¦ AplicaÃ§Ãµes incluÃ­das:"
echo "   â€¢ Traefik (Proxy SSL automÃ¡tico)"
echo "   â€¢ Portainer (Interface Docker)"
echo "   â€¢ PostgreSQL (Banco de dados)"
echo "   â€¢ Redis (Cache)"
echo "   â€¢ Evolution API v2.2.3 (WhatsApp)"
echo "   â€¢ N8N (AutomaÃ§Ã£o)"
echo ""

# ValidaÃ§Ã£o rigorosa de parÃ¢metros
if [ -z "$SSL_EMAIL" ]; then
    read -p "ðŸ“§ Digite seu email para SSL: " SSL_EMAIL
fi

if [ -z "$DOMINIO_N8N" ]; then
    read -p "ðŸ”„ Digite o domÃ­nio para N8N (ex: n8n.seudominio.com): " DOMINIO_N8N
fi

if [ -z "$DOMINIO_PORTAINER" ]; then
    read -p "ðŸ³ Digite o domÃ­nio para Portainer (ex: portainer.seudominio.com): " DOMINIO_PORTAINER
fi

if [ -z "$WEBHOOK_N8N" ]; then
    read -p "ðŸ”— Digite o domÃ­nio para Webhook N8N (ex: webhook.seudominio.com): " WEBHOOK_N8N
fi

if [ -z "$DOMINIO_EVOLUTION" ]; then
    read -p "ðŸ“± Digite o domÃ­nio para Evolution API (ex: evolution.seudominio.com): " DOMINIO_EVOLUTION
fi

# Validar formato de email
if [[ ! "$SSL_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    log_error "Email invÃ¡lido! Por favor, digite um email vÃ¡lido."
    exit 1
fi

# Validar domÃ­nios
for domain in "$DOMINIO_N8N" "$DOMINIO_PORTAINER" "$WEBHOOK_N8N" "$DOMINIO_EVOLUTION"; do
    if [[ ! "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log_error "DomÃ­nio invÃ¡lido: $domain"
        exit 1
    fi
done

log_success "âœ… ParÃ¢metros validados!"
echo ""
echo "â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”"
echo "â”‚                 CONFIGURAÃ‡ÃƒO VALIDADA                  â”‚"
echo "â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤"
echo "â”‚ ðŸ“§ Email: $SSL_EMAIL"
echo "â”‚ ðŸ”„ N8N: $DOMINIO_N8N"  
echo "â”‚ ðŸ³ Portainer: $DOMINIO_PORTAINER"
echo "â”‚ ðŸ”— Webhook: $WEBHOOK_N8N"
echo "â”‚ ðŸ“± Evolution: $DOMINIO_EVOLUTION"
echo "â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜"
echo ""

# Verificar conectividade com a internet
log_info "ðŸŒ Verificando conectividade com a internet..."
if ! ping -c 1 google.com >/dev/null 2>&1; then
    log_error "âŒ Sem conexÃ£o com a internet!"
    exit 1
fi
log_success "âœ… Internet funcionando!"

# Gerar chaves seguras
log_info "ðŸ” Gerando chaves de seguranÃ§a..."
N8N_KEY=$(openssl rand -hex 16)
POSTGRES_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12)
EVOLUTION_API_KEY=$(openssl rand -hex 32)

# Salvar variÃ¡veis de ambiente
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

log_success "âœ… VariÃ¡veis salvas em .env"

# ConfiguraÃ§Ã£o do sistema
log_info "âš™ï¸ Configurando sistema..."
export DEBIAN_FRONTEND=noninteractive
timedatectl set-timezone America/Sao_Paulo

# Verificar e configurar firewall
log_info "ðŸ”¥ Configurando firewall..."
if command -v ufw >/dev/null 2>&1; then
    ufw allow 22/tcp >/dev/null 2>&1 || true
    ufw allow 80/tcp >/dev/null 2>&1 || true
    ufw allow 443/tcp >/dev/null 2>&1 || true
    log_success "âœ… Firewall configurado!"
fi

# Atualizar sistema
log_info "ðŸ“¦ Atualizando sistema..."
{
    apt update -y &&
    apt upgrade -y &&
    apt-get install -y curl wget gnupg lsb-release ca-certificates apt-transport-https software-properties-common
} >> instalacao_corrigida.log 2>&1

# Aguardar liberaÃ§Ã£o do lock do apt
while fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
    sleep 5
done

# Configurar swap se necessÃ¡rio
log_info "ðŸ’¾ Configurando swap..."
if [ ! -f /swapfile ]; then
    fallocate -l 4G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile >/dev/null 2>&1
    swapon /swapfile
    echo "/swapfile none swap sw 0 0" | tee -a /etc/fstab >/dev/null
fi

# Configurar hostname
log_info "ðŸ·ï¸ Configurando hostname..."
hostnamectl set-hostname manager1
sed -i "s/127.0.0.1.*/127.0.0.1 manager1/" /etc/hosts

# Remover Docker antigo se existir
log_info "ðŸ§¹ Removendo instalaÃ§Ãµes antigas do Docker..."
systemctl stop docker >/dev/null 2>&1 || true
apt-get remove -y docker docker-engine docker.io containerd runc >/dev/null 2>&1 || true

# Instalar Docker mais recente
log_info "ðŸ‹ Instalando Docker mais recente..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update >/dev/null 2>&1
apt-get install -y docker-ce docker-ce-cli containerd.io >/dev/null 2>&1

# Configurar Docker
systemctl enable docker
systemctl start docker

# Aguardar Docker inicializar
log_info "â³ Aguardando Docker inicializar..."
for i in {1..30}; do
    if docker ps >/dev/null 2>&1; then
        log_success "âœ… Docker funcionando!"
        break
    fi
    sleep 2
done

# Configurar Docker Swarm com mÃ©todo mais robusto
log_info "ðŸ”§ Configurando Docker Swarm..."

# Detectar IP do servidor
server_ip=$(curl -s ifconfig.me || curl -s icanhazip.com || hostname -I | cut -d' ' -f1)
log_info "IP do servidor detectado: $server_ip"

# Limpar Swarm antigo se existir
docker swarm leave --force >/dev/null 2>&1 || true

# Inicializar novo Swarm
if docker swarm init --advertise-addr $server_ip >/dev/null 2>&1; then
    log_success "âœ… Docker Swarm inicializado!"
else
    log_warning "âš ï¸ Tentando mÃ©todo alternativo..."
    docker swarm init >/dev/null 2>&1
    log_success "âœ… Docker Swarm inicializado (mÃ©todo alternativo)!"
fi

# Aguardar Swarm estabilizar
sleep 10

# Verificar se Swarm estÃ¡ funcionando
if docker node ls >/dev/null 2>&1; then
    log_success "âœ… Docker Swarm funcionando corretamente!"
else
    log_error "âŒ Falha no Docker Swarm!"
    exit 1
fi

# Criar rede overlay
log_info "ðŸŒ Criando rede overlay..."
docker network create --driver=overlay network_public >/dev/null 2>&1 || true

# FunÃ§Ã£o para aguardar serviÃ§o com verificaÃ§Ã£o robusta
wait_service_perfect() {
    local service_name=$1
    local max_wait=${2:-300}
    
    log_info "â³ Aguardando $service_name..."
    
    # Aguardar serviÃ§o aparecer
    for i in $(seq 1 60); do
        if docker service ls --filter name=$service_name --format "{{.Name}}" | grep -q "$service_name"; then
            break
        fi
        sleep 5
    done
    
    # Aguardar container ficar ativo
    for i in $(seq 1 $max_wait); do
        if docker ps --filter "name=$service_name" --format "{{.Names}}" | grep -q "$service_name"; then
            log_success "âœ… $service_name funcionando!"
            return 0
        fi
        
        # Log de progresso a cada 30 segundos
        if [ $((i % 30)) -eq 0 ]; then
            echo "   ... aguardando $service_name ($i/${max_wait}s)"
        fi
        sleep 1
    done
    
    log_error "âŒ Timeout aguardando $service_name"
    return 1
}

# FunÃ§Ã£o para verificar SSL de forma simples e rÃ¡pida
check_ssl_simple() {
    local domain=$1
    local service_name=$2
    
    log_info "ðŸ” Verificando SSL para $domain ($service_name)..."
    
    # Aguardar 15 segundos para o serviÃ§o estabilizar
    sleep 15
    
    # Fazer uma requisiÃ§Ã£o simples para acionar Let's Encrypt
    curl -s -H "Host: $domain" "http://$server_ip" >/dev/null 2>&1 &
    curl -s -k "https://$domain" >/dev/null 2>&1 &
    
    # Testar uma vez se SSL jÃ¡ estÃ¡ funcionando
    if curl -s -I "https://$domain" --max-time 5 2>/dev/null | grep -q "HTTP.*[2-4][0-9][0-9]"; then
        log_success "âœ… SSL jÃ¡ funcionando para $domain!"
    else
        log_info "ðŸ”„ SSL para $domain serÃ¡ processado em background"
    fi
    
    log_success "âœ… $service_name configurado! Continuando instalaÃ§Ã£o..."
}

# 1. INSTALAR TRAEFIK (PROXY SSL)
echo ""
echo "â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”"
echo "â”‚               ETAPA 1/6 - INSTALANDO TRAEFIK                  â”‚"
echo "â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜"
log_info "ðŸ” Configurando proxy SSL automÃ¡tico..."

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

log_success "âœ… Traefik instalado - Proxy SSL pronto!"

# 2. INSTALAR PORTAINER
echo ""
echo "â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”"
echo "â”‚              ETAPA 2/6 - INSTALANDO PORTAINER                 â”‚"
echo "â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜"
log_info "ðŸ³ Configurando interface de gerenciamento Docker..."

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
wait_service_perfect "portainer" 120

# Verificar SSL do Portainer imediatamente
check_ssl_simple "$DOMINIO_PORTAINER" "Portainer"

echo ""
echo "â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”"
echo "â”‚               âš ï¸  IMPORTANTE - PORTAINER                        â”‚"
echo "â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤"
echo "â”‚ ðŸ”´ CRIE SUA CONTA EM ATÃ‰ 5 MINUTOS!                       â”‚"
echo "â”‚ ðŸŒ Acesse: https://$DOMINIO_PORTAINER                    â”‚"
echo "â”‚ â° Timeout apÃ³s 5 minutos de inatividade                    â”‚"
echo "â”‚ ðŸ”‘ Configure username e senha de administrador            â”‚"
echo "â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜"
echo ""

# 3. INSTALAR POSTGRESQL
echo ""
echo "â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”"
echo "â”‚             ETAPA 3/6 - INSTALANDO POSTGRESQL                 â”‚"
echo "â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜"
log_info "ðŸ—„ï¸ Configurando banco de dados..."

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
docker stack deploy --prune --resolve-image always -c postgres_corrigido.yaml postgres
wait_service_perfect "postgres" 180

# 4. INSTALAR REDIS
echo ""
echo "â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”"
echo "â”‚                ETAPA 4/6 - INSTALANDO REDIS                   â”‚"
echo "â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜"
log_info "ðŸ”´ Configurando cache e filas..."

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
docker stack deploy --prune --resolve-image always -c redis_corrigido.yaml redis
wait_service_perfect "redis" 120

# Aguardar bancos estabilizarem
log_info "â³ Aguardando bancos de dados estabilizarem..."
sleep 60

# Criar bancos de dados
log_info "ðŸ—ƒï¸ Criando bancos de dados..."
for i in {1..30}; do
    postgres_container=$(docker ps --filter "name=postgres_postgres" --format "{{.Names}}" | head -1)
    if [ ! -z "$postgres_container" ]; then
        if docker exec $postgres_container pg_isready -U postgres >/dev/null 2>&1; then
            docker exec $postgres_container psql -U postgres -d postgres -c "CREATE DATABASE evolution;" 2>/dev/null || true
            docker exec $postgres_container psql -U postgres -d postgres -c "CREATE DATABASE n8n;" 2>/dev/null || true
            log_success "âœ… Bancos de dados criados!"
            break
        fi
    fi
    echo "   Tentativa $i/30 - Aguardando PostgreSQL..."
    sleep 3
done

# 5. INSTALAR EVOLUTION API
echo ""
echo "â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”"
echo "â”‚            ETAPA 5/6 - INSTALANDO EVOLUTION API               â”‚"
echo "â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜"
log_info "ðŸ“± Configurando API do WhatsApp..."

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

docker stack deploy --prune --resolve-image always -c evolution_corrigido.yaml evolution
wait_service_perfect "evolution" 300

# Verificar SSL do Evolution imediatamente
check_ssl_simple "$DOMINIO_EVOLUTION" "Evolution API"

echo ""
echo "â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”"
echo "â”‚               âš ï¸  IMPORTANTE - EVOLUTION API                   â”‚"
echo "â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤"
echo "â”‚ ðŸŒ Acesse: https://$DOMINIO_EVOLUTION                       â”‚"
echo "â”‚ ðŸ”§ Painel Admin: https://$DOMINIO_EVOLUTION/manager             â”‚"
echo "â”‚ ðŸ”‘ API Key: $EVOLUTION_API_KEY"
echo "â”‚ ðŸ“± Para conectar WhatsApp: POST /instance/create          â”‚"
echo "â”‚ ðŸ—ƒï¸ DocumentaÃ§Ã£o: https://$DOMINIO_EVOLUTION/docs           â”‚"
echo "â”‚ âš¡ Status da API: GET https://$DOMINIO_EVOLUTION/             â”‚"
echo "â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜"
echo ""

# 6. INSTALAR N8N
echo ""
echo "â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”"
echo "â”‚                 ETAPA 6/6 - INSTALANDO N8N                    â”‚"
echo "â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜"
log_info "ðŸ”„ Configurando automaÃ§Ã£o de workflows..."

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
docker stack deploy --prune --resolve-image always -c n8n_corrigido.yaml n8n
wait_service_perfect "n8n" 300

# Verificar SSL do N8N e Webhook imediatamente
check_ssl_simple "$DOMINIO_N8N" "N8N"
check_ssl_simple "$WEBHOOK_N8N" "Webhook N8N"

echo ""
echo "â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”"
echo "â”‚                  âš ï¸  IMPORTANTE - N8N                           â”‚"
echo "â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤"
echo "â”‚ ðŸŒ Acesse: https://$DOMINIO_N8N                            â”‚"
echo "â”‚ ðŸ”‘ PRIMEIRA VEZ: Criar conta de administrador              â”‚"
echo "â”‚ ðŸš€ Configure workflows e automaÃ§Ãµes                       â”‚"
echo "â”‚ ðŸ”— Webhook: https://$WEBHOOK_N8N                          â”‚"
echo "â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜"
echo ""

# VERIFICAÃ‡ÃƒO FINAL DE SSL
echo ""
echo "â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”"
echo "â”‚                VERIFICAÃ‡ÃƒO FINAL DE SSL                       â”‚"
echo "â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜"
log_info "ðŸ” Verificando status final de todos os certificados SSL..."

# Verificar cada domÃ­nio uma Ãºltima vez
for domain in "$DOMINIO_PORTAINER" "$DOMINIO_N8N" "$DOMINIO_EVOLUTION" "$WEBHOOK_N8N"; do
    if curl -s -I "https://$domain" --max-time 8 2>/dev/null | grep -q "HTTP.*[2-4][0-9][0-9]"; then
        log_success "âœ… $domain: SSL funcionando"
    else
        log_warning "âš ï¸ $domain: SSL ainda processando"
    fi
done

# VERIFICAÃ‡ÃƒO FINAL COMPLETA
echo "â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—"
echo "â•‘                    INSTALAÃ‡ÃƒO CONCLUÃDA                     â•‘"
echo "â•‘                       SETUP ALICIA                        â•‘"
echo "â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•"

all_perfect=true

# Verificar serviÃ§os
echo "ðŸ“Š STATUS DOS SERVIÃ‡OS:"
docker service ls

echo ""
echo "ðŸ³ CONTAINERS ATIVOS:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "ðŸ” VERIFICAÃ‡ÃƒO SSL:"

# Testar HTTPS para cada serviÃ§o
for domain in "$DOMINIO_PORTAINER" "$DOMINIO_N8N" "$DOMINIO_EVOLUTION"; do
    echo "ðŸ” Testando SSL para $domain..."
    
    # Testar HTTPS
    if curl -s -I "https://$domain" 2>/dev/null | grep -q "HTTP.*200\|HTTP.*301\|HTTP.*302\|HTTP.*404"; then
        log_success "âœ… $domain: SSL FUNCIONANDO"
    else
        log_warning "âš ï¸ $domain: SSL ainda sendo gerado (aguarde alguns minutos)"
    fi
done

echo ""
echo "=========================================="
echo "ðŸŽ‰ INSTALAÃ‡ÃƒO CORRIGIDA CONCLUÃDA!"
echo "=========================================="
echo ""
echo "â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”"
echo "â”‚                        SERVIÃ‡OS DISPONÃVEIS                        â”‚"
echo "â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤"
echo "â”‚ ðŸ³ Portainer: https://$DOMINIO_PORTAINER"
echo "â”‚ ðŸ”„ N8N: https://$DOMINIO_N8N"
echo "â”‚ ðŸ“± Evolution API: https://$DOMINIO_EVOLUTION"
echo "â”‚ ðŸ”§ Evolution Manager: https://$DOMINIO_EVOLUTION/manager"
echo "â”‚ ðŸ”— Webhook N8N: https://$WEBHOOK_N8N"
echo "â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜"
echo ""
echo "â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”"
echo "â”‚                      CREDENCIAIS DE ACESSO                      â”‚"
echo "â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤"
echo "â”‚ ðŸ”‘ Evolution API Key: $EVOLUTION_API_KEY"
echo "â”‚ ðŸ—¿ PostgreSQL Password: $POSTGRES_PASSWORD"
echo "â”‚ ðŸ” N8N Encryption Key: $N8N_KEY"
echo "â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜"
echo ""
echo "â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”"
echo "â”‚                        INFORMAÃ‡Ã•ES IMPORTANTES                    â”‚"
echo "â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤"
echo "â”‚ â€¢ SSL processado automaticamente em background               â”‚"
echo "â”‚ â€¢ Redirecionamento HTTPâ†’HTTPS ativo                          â”‚"
echo "â”‚ â€¢ ðŸ”‘ Configure conta administrador no N8N                   â”‚"
echo "â”‚ â€¢ IP do servidor: $server_ip                    â”‚"
echo "â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜"
echo ""
echo "ðŸŽ‰ InstalaÃ§Ã£o concluÃ­da com sucesso!"
# ================== Portainer: bootstrap automático (inline) ==================
# Cria admin automaticamente, autentica na API e cria/atualiza stacks gerenciadas
# Tenta 127.0.0.1:9000; se falhar e DOMINIO_PORTAINER existir, usa https://DOMINIO (com -k)

portainer_bootstrap_inline() {
  set +e
  need() { command -v "$1" >/dev/null 2>&1; }
  if ! need curl; then
    if command -v apt >/dev/null 2>&1; then sudo apt update -y && sudo apt install -y curl; fi
    if command -v yum >/dev/null 2>&1; then sudo yum install -y curl; fi
  fi
  if ! need jq; then
    if command -v apt >/dev/null 2>&1; then sudo apt update -y && sudo apt install -y jq; fi
    if command -v yum >/dev/null 2>&1; then sudo yum install -y jq; fi
  fi
  set -e

  [ -f .env ] && set -a && source .env && set +a
  if [ -z "${PORTAINER_ADMIN_PASSWORD:-}" ]; then
    PORTAINER_ADMIN_PASSWORD="$(tr -dc 'A-Za-z0-9!@#%^&*' </dev/urandom | head -c 20)"
    echo "PORTAINER_ADMIN_PASSWORD=${PORTAINER_ADMIN_PASSWORD}" >> .env
  fi

  CURL_FLAGS=( -fsS )
  PORTAINER_URL=""
  choose_portainer_url() {
    if curl "${CURL_FLAGS[@]}" http://127.0.0.1:9000/api/system/status >/dev/null 2>&1; then
      PORTAINER_URL="http://127.0.0.1:9000"; return; fi
    if [ -n "${DOMINIO_PORTAINER:-}" ]; then
      if curl -k "${CURL_FLAGS[@]}" "https://${DOMINIO_PORTAINER}/api/system/status" >/dev/null 2>&1; then
        PORTAINER_URL="https://${DOMINIO_PORTAINER}"; CURL_FLAGS=( -k -fsS ); return; fi
    fi
    PORTAINER_URL=""
  }

  echo "[Portainer] Aguardando serviço..."
  for i in $(seq 1 90); do
    choose_portainer_url
    if [ -n "$PORTAINER_URL" ]; then echo "[Portainer] Online em: $PORTAINER_URL"; break; fi
    sleep 2
    [ "$i" -eq 90 ] && { echo "[Portainer] Timeout"; return 1; }
  done

  curl "${CURL_FLAGS[@]}" -X POST "$PORTAINER_URL/api/users/admin/init" \
    -H "Content-Type: application/json" -d "{\"Password\": \"${PORTAINER_ADMIN_PASSWORD}\"}" \
    >/dev/null 2>&1 || true

  JWT="$( curl "${CURL_FLAGS[@]}" -X POST "$PORTAINER_URL/api/auth" -H "Content-Type: application/json" \
    -d "{\"Username\":\"admin\",\"Password\":\"${PORTAINER_ADMIN_PASSWORD}\"}" | jq -r .jwt )"
  if [ -z "${JWT}" ] || [ "${JWT}" = "null" ]; then echo "[Portainer] Falha auth"; return 1; fi

  ENDPOINT_ID="$( curl "${CURL_FLAGS[@]}" "$PORTAINER_URL/api/endpoints" -H "Authorization: Bearer ${JWT}" \
    | jq 'map(select(.Name=="local")) | .[0].Id' )"
  if [ -z "${ENDPOINT_ID}" ] || [ "${ENDPOINT_ID}" = "null" ]; then
    curl "${CURL_FLAGS[@]}" -X POST "$PORTAINER_URL/api/endpoints" -H "Authorization: Bearer ${JWT}" \
      -H "Content-Type: application/json" -d '{"Name":"local","EndpointCreationType":1,"URL":"unix:///var/run/docker.sock"}' >/dev/null
    ENDPOINT_ID="$( curl "${CURL_FLAGS[@]}" "$PORTAINER_URL/api/endpoints" -H "Authorization: Bearer ${JWT}" | jq 'map(select(.Name=="local")) | .[0].Id' )"
  fi

  SWARM_ID="$(docker info -f '{{.Swarm.Cluster.ID}}' 2>/dev/null || true)"
  if [ -z "${SWARM_ID}" ]; then docker swarm init >/dev/null 2>&1 || true; SWARM_ID="$(docker info -f '{{.Swarm.Cluster.ID}}')"; fi

  create_or_update_stack() {
    local stack_name="$1"; local file_path="$2"; local base_name; base_name="$(basename "${file_path}")"
    if [ ! -f "${file_path}" ] && [ ! -f "./stacks/${base_name}" ]; then
      mkdir -p ./stacks
      curl -fsSL "https://raw.githubusercontent.com/lonardonetto/setupalicia/main/stacks/${base_name}" -o "./stacks/${base_name}" || true
    fi
    if [ ! -f "${file_path}" ] && [ -f "./stacks/${base_name}" ]; then file_path="./stacks/${base_name}"; fi
    if [ ! -f "${file_path}" ]; then echo "[Stack] Arquivo não encontrado: ${file_path} (ignorando ${stack_name})"; return; fi
    local content; content="$(cat "${file_path}")"; local existing_id
    existing_id="$( curl "${CURL_FLAGS[@]}" "$PORTAINER_URL/api/stacks?endpointId=${ENDPOINT_ID}" -H "Authorization: Bearer ${JWT}" \
      | jq -r --arg n "${stack_name}" '.[] | select(.Name==$n) | .Id' | head -n1 )"
    if [ -n "${existing_id}" ]; then
      echo "[Stack] Atualizando ${stack_name} (${existing_id})"
      curl "${CURL_FLAGS[@]}" -X PUT "$PORTAINER_URL/api/stacks/${existing_id}?endpointId=${ENDPOINT_ID}" -H "Authorization: Bearer ${JWT}" \
        -H "Content-Type: application/json" -d "$(jq -n --arg c "${content}" '{StackFileContent:$c, Prune:true}')" >/dev/null
    else
      echo "[Stack] Criando ${stack_name}"
      curl "${CURL_FLAGS[@]}" -X POST "$PORTAINER_URL/api/stacks?type=3&method=string&endpointId=${ENDPOINT_ID}" -H "Authorization: Bearer ${JWT}" \
        -H "Content-Type: application/json" -d "$(jq -n --arg name "${stack_name}" --arg content "${content}" --arg swarmId "${SWARM_ID}" '{Name:$name, SwarmID:$swarmId, StackFileContent:$content, Env: []}')" >/dev/null
    fi
  }

  create_or_update_stack "traefik" "traefik.yaml"
  create_or_update_stack "portainer" "portainer.yaml"
  create_or_update_stack "redis" "redis.yaml"
  create_or_update_stack "postgres" "postgres.yaml"
  create_or_update_stack "n8n" "n8n.yaml"
  create_or_update_stack "evolution" "evolution_corrigido.yaml"

  echo "[Portainer] Deploy via API concluído. Stacks editáveis na UI."
}

# Executa bootstrap imediatamente após subir Portainer/Traefik
portainer_bootstrap_inline || echo "[Portainer] Bootstrap falhou; verifique logs."
# ===========================================================================
