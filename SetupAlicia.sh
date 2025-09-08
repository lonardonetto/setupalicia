#!/bin/bash

## SetupAlicia v2.7.1 - Simplified Version
## Only essential applications: Traefik, Portainer, Evolution, N8N, N8N+MCP
## Instalação: bash <(curl -sSL https://setup.alicia.com.br/setup.sh)

# Verificar se está sendo executado como root
if [[ $EUID -eq 0 ]]; then
   echo "❌ Este script não deve ser executado como root!"
   echo "Use: bash <(curl -sSL https://setup.alicia.com.br/setup.sh)"
   exit 1
fi

# Verificar conectividade
if ! curl -sSf https://www.google.com >/dev/null 2>&1; then
    echo "❌ Erro: Sem conexão com a internet"
    exit 1
fi

# Verificar se Docker está instalado
if ! command -v docker &> /dev/null; then
    echo "⚠️  Docker não encontrado. Instalando Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    echo "✅ Docker instalado! Faça logout e login novamente, depois execute o script."
    exit 0
fi

## Colors
amarelo="\e[33m"
verde="\e[32m"
branco="\e[97m"
vermelho="\e[91m"
reset="\e[0m"

## Version info
versao() {
echo -e "                     \e[97mSetupAlicia: \e[32mv. 2.7.1 (Simplified)\e[0m"
echo -e "\e[32msetup.alicia.com.br             \e[97m<----- Instalação Remota ----->     \e[32mbash <(curl -sSL setup.alicia.com.br)\e[0m"
echo -e "\e[32malicia.setup.com/whatsapp2      \e[97m<----- Grupos no WhatsApp ----->     \e[32malicia.setup.com/whatsapp3\e[0m"
}

## Atualizar script
atualizar_script() {
    echo -e "${verde}Verificando atualizações...${reset}"
    
    # Download da versão mais recente
    curl -sSL https://setup.alicia.com.br/setup.sh -o /tmp/setupalicia_new.sh
    
    if [ $? -eq 0 ]; then
        # Verificar se há diferenças
        if ! diff -q "$0" /tmp/setupalicia_new.sh >/dev/null 2>&1; then
            echo -e "${amarelo}Nova versão disponível!${reset}"
            read -p "Deseja atualizar? (Y/N): " update_confirm
            
            if [[ $update_confirm =~ ^[Yy]$ ]]; then
                cp /tmp/setupalicia_new.sh "$0"
                chmod +x "$0"
                echo -e "${verde}✅ Script atualizado! Reiniciando...${reset}"
                sleep 2
                exec "$0" "$@"
            fi
        else
            echo -e "${verde}✅ Script já está atualizado!${reset}"
        fi
    else
        echo -e "${vermelho}❌ Erro ao verificar atualizações${reset}"
    fi
    
    rm -f /tmp/setupalicia_new.sh
}

## License agreement
direitos_instalador() {
    echo -e "$amarelo===================================================================================================\e[0m"
    echo -e "$amarelo=  $branco Este auto instalador foi desenvolvido para auxiliar na instalação das principais aplicações $amarelo  =\e[0m"
    echo -e "$amarelo=  $branco aplicação disponíveis aqui. Este Setup é licenciado sob a Licença MIT (MIT).               $amarelo =\e[0m"
    echo -e "$amarelo=  $branco SetupAlicia (contato@alicia.setup.com) é o autor original                                  $amarelo  =\e[0m"
    echo -e "$amarelo===================================================================================================\e[0m"
    echo ""
    read -p "Ao digitar Y você aceita e concorda com as orientações passadas acima (Y/N): " choice
    case $choice in
        Y|y) return ;;
        *) echo "Encerrando instalador..."; exit 1 ;;
    esac
}

## Main title
nome_instalador() { 
    clear
    echo ""
    echo -e "$branco       ███████╗███████╗████████╗██╗   ██╗██████╗       █████╗ ██╗     ██╗ ██████╗██╗ █████╗ \e[0m"
    echo -e "$branco       ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗     ██╔══██╗██║     ██║██╔════╝██║██╔══██╗\e[0m"
    echo -e "$branco       ███████╗█████╗     ██║   ██║   ██║██████╔╝     ███████║██║     ██║██║     ██║███████║\e[0m"
    echo -e "$branco       ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝      ██╔══██║██║     ██║██║     ██║██╔══██║\e[0m"
    echo -e "$branco       ███████║███████╗   ██║   ╚██████╔╝██║          ██║  ██║███████╗██║╚██████╗██║██║  ██║\e[0m"
    echo -e "$branco       ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝          ╚═╝  ╚═╝╚══════╝╚═╝ ╚═════╝╚═╝╚═╝  ╚═╝\e[0m"
    echo -e "$verde                                          VERSÃO SIMPLIFICADA                                    \e[0m"
    echo "" 
}

## Menu header
nome_menu() {
    clear
    echo -e "$amarelo===================================================================================================\e[0m"
    echo -e "$branco   █████╗ ██╗     ██╗ ██████╗██╗ █████╗     ███████╗███████╗████████╗██╗   ██╗██████╗ \e[0m"
    echo -e "$branco  ██╔══██╗██║     ██║██╔════╝██║██╔══██╗    ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗\e[0m"
    echo -e "$branco  ███████║██║     ██║██║     ██║███████║    ███████╗█████╗     ██║   ██║   ██║██████╔╝\e[0m"
    echo -e "$branco  ██╔══██║██║     ██║██║     ██║██╔══██║    ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ \e[0m"
    echo -e "$branco  ██║  ██║███████╗██║╚██████╗██║██║  ██║    ███████║███████╗   ██║   ╚██████╔╝██║     \e[0m"
    echo -e "$branco  ╚═╝  ╚═╝╚══════╝╚═╝ ╚═════╝╚═╝╚═╝  ╚═╝    ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     \e[0m"
    echo -e "$amarelo===================================================================================================\e[0m"
    versao
    echo ""
}

## Simplified menu
menu_instalador_pg_1(){
    echo -e "${amarelo}[ 01 ]${reset} - ${branco}Traefik & Portainer ${verde}[1/1]${reset}"
    echo -e "${amarelo}[ 02 ]${reset} - ${branco}Evolution API ${verde}[1/1]${reset}"
    echo -e "${amarelo}[ 03 ]${reset} - ${branco}N8N ${verde}[1/1]${reset}"
    echo -e "${amarelo}[ 04 ]${reset} - ${branco}N8N + MCP ${verde}[1/1]${reset}"
    echo -e ""
    echo -e "${branco}Digite ${amarelo}COMANDOS${branco} para ver comandos especiais${reset}"
    echo -e ""
}

menu_comandos(){
    echo -e "> ${verde}Comandos Disponíveis:${reset}"
    echo -e "${branco} • ${amarelo}atualizar${reset} - ${branco}Atualiza o SetupAlicia${reset}"
    echo -e "${branco} • ${amarelo}portainer.restart${reset} - ${branco}Reinicia o Portainer${reset}"
    echo -e "${branco} • ${amarelo}ssl.status${reset} - ${branco}Status dos certificados SSL${reset}"
    echo -e "${branco} • ${amarelo}ssl.check <dominio>${reset} - ${branco}Verifica SSL de um domínio${reset}"
    echo -e "${branco} • ${amarelo}ctop${reset} - ${branco}Instala o CTOP${reset}"
    echo -e "${branco} • ${amarelo}htop${reset} - ${branco}Instala o HTOP${reset}"
    echo -e "${branco} • ${amarelo}limpar${reset} - ${branco}Limpa Docker${reset}"
    echo -e ""
    echo -e "${verde}Exemplo de uso SSL:${reset}"
    echo -e "${branco} • ${amarelo}ssl.check meudominio.com${reset}"
    echo -e "${branco} • ${amarelo}ssl.status${reset} - Ver todos os certificados"
    echo -e ""
    echo -e "${verde}Instalação Remota:${reset}"
    echo -e "${branco} • ${amarelo}bash <(curl -sSL setup.alicia.com.br)${reset}"
    echo -e ""
    echo -e "${branco}Digite ${amarelo}P1${branco} para voltar ao menu principal${reset}"
    echo -e ""
}

## Docker verification
verificar_docker_e_portainer_traefik() {
    if ! command -v docker &> /dev/null; then
        echo "Docker não encontrado. Instale primeiro o Traefik & Portainer."
        sleep 3
        return 1
    fi
    return 0
}

## Stack verification
verificar_stack() {
    local nome_stack="$1"
    if docker stack ls --format "{{.Name}}" | grep -q "^${nome_stack}$"; then
        echo -e "Stack '$amarelo${nome_stack}\e[0m' já existe."
        echo "Remova no Portainer para reinstalar."
        sleep 3
        return 0
    else
        return 1
    fi
}

## Installation functions with SSL support
ferramenta_traefik_e_portainer() {
    clear
    echo -e "${verde}=== INSTALAÇÃO TRAEFIK & PORTAINER COM SSL AUTOMÁTICO ===${reset}"
    echo ""
    
    # Collect domain information for SSL certificates
    echo -e "${amarelo}Configuração de Domínios para SSL Automático:${reset}"
    echo ""
    
    read -p "Digite o domínio principal do seu servidor (ex: meuservidor.com): " dominio_principal
    read -p "Digite o subdomínio para o Traefik Dashboard (ex: traefik): " sub_traefik
    read -p "Digite o subdomínio para o Portainer (ex: portainer): " sub_portainer
    read -p "Digite seu email para Let's Encrypt (para certificados SSL): " email_ssl
    
    echo ""
    echo -e "${verde}Configuração SSL:${reset}"
    echo -e "• Domínio principal: ${amarelo}$dominio_principal${reset}"
    echo -e "• Traefik Dashboard: ${amarelo}$sub_traefik.$dominio_principal${reset}"
    echo -e "• Portainer: ${amarelo}$sub_portainer.$dominio_principal${reset}"
    echo -e "• Email Let's Encrypt: ${amarelo}$email_ssl${reset}"
    echo -e "• Certificados SSL: ${verde}Automático via Let's Encrypt${reset}"
    echo ""
    
    read -p "Confirma a instalação com estas configurações? (Y/N): " confirm
    case $confirm in
        Y|y)
            echo -e "${verde}Iniciando instalação...${reset}"
            install_traefik_with_ssl
            install_portainer_with_ssl
            echo -e "${verde}✅ Traefik & Portainer instalados com SSL automático!${reset}"
            echo -e "${verde}✅ Certificados SSL configurados automaticamente${reset}"
            echo -e "${verde}✅ Acesso seguro via HTTPS habilitado${reset}"
            ;;
        *)
            echo "Instalação cancelada."
            return
            ;;
    esac
}

ferramenta_evolution() {
    clear
    echo -e "${verde}=== INSTALAÇÃO EVOLUTION API COM SSL AUTOMÁTICO ===${reset}"
    echo ""
    
    if ! verificar_docker_e_portainer_traefik; then
        echo -e "${vermelho}Erro: Traefik & Portainer devem ser instalados primeiro!${reset}"
        return 1
    fi
    
    read -p "Digite o subdomínio para Evolution API (ex: evolution): " sub_evolution
    read -p "Digite o domínio principal (ex: meuservidor.com): " dominio_principal
    
    echo ""
    echo -e "${verde}Configuração Evolution API:${reset}"
    echo -e "• URL de Acesso: ${amarelo}https://$sub_evolution.$dominio_principal${reset}"
    echo -e "• SSL: ${verde}Automático via Traefik + Let's Encrypt${reset}"
    echo -e "• Certificado: ${verde}Renovado automaticamente${reset}"
    echo ""
    
    read -p "Confirma a instalação? (Y/N): " confirm
    case $confirm in
        Y|y)
            echo -e "${verde}Instalando Evolution API com SSL...${reset}"
            install_evolution_with_ssl
            echo -e "${verde}✅ Evolution API instalada com SSL automático!${reset}"
            echo -e "${verde}✅ Acesso seguro: https://$sub_evolution.$dominio_principal${reset}"
            ;;
        *)
            echo "Instalação cancelada."
            ;;
    esac
}

ferramenta_n8n() {
    clear
    echo -e "${verde}=== INSTALAÇÃO N8N COM SSL AUTOMÁTICO ===${reset}"
    echo ""
    
    if ! verificar_docker_e_portainer_traefik; then
        echo -e "${vermelho}Erro: Traefik & Portainer devem ser instalados primeiro!${reset}"
        return 1
    fi
    
    read -p "Digite o subdomínio para N8N (ex: n8n): " sub_n8n
    read -p "Digite o domínio principal (ex: meuservidor.com): " dominio_principal
    
    echo ""
    echo -e "${verde}Configuração N8N:${reset}"
    echo -e "• URL de Acesso: ${amarelo}https://$sub_n8n.$dominio_principal${reset}"
    echo -e "• SSL: ${verde}Automático via Traefik + Let's Encrypt${reset}"
    echo -e "• Workflows: ${verde}Interface visual para automação${reset}"
    echo -e "• Certificado: ${verde}Renovado automaticamente${reset}"
    echo ""
    
    read -p "Confirma a instalação? (Y/N): " confirm
    case $confirm in
        Y|y)
            echo -e "${verde}Instalando N8N com SSL...${reset}"
            install_n8n_with_ssl
            echo -e "${verde}✅ N8N instalado com SSL automático!${reset}"
            echo -e "${verde}✅ Acesso seguro: https://$sub_n8n.$dominio_principal${reset}"
            ;;
        *)
            echo "Instalação cancelada."
            ;;
    esac
}

n8n.mcp() {
    clear
    echo -e "${verde}=== INSTALAÇÃO N8N + MCP COM SSL AUTOMÁTICO ===${reset}"
    echo ""
    
    if ! verificar_docker_e_portainer_traefik; then
        echo -e "${vermelho}Erro: Traefik & Portainer devem ser instalados primeiro!${reset}"
        return 1
    fi
    
    read -p "Digite o subdomínio para N8N+MCP (ex: n8n-mcp): " sub_n8n_mcp
    read -p "Digite o domínio principal (ex: meuservidor.com): " dominio_principal
    
    echo ""
    echo -e "${verde}Configuração N8N + MCP:${reset}"
    echo -e "• URL de Acesso: ${amarelo}https://$sub_n8n_mcp.$dominio_principal${reset}"
    echo -e "• SSL: ${verde}Automático via Traefik + Let's Encrypt${reset}"
    echo -e "• MCP: ${verde}Model Context Protocol integrado${reset}"
    echo -e "• AI Integration: ${verde}Suporte avançado para IA${reset}"
    echo -e "• Certificado: ${verde}Renovado automaticamente${reset}"
    echo ""
    
    read -p "Confirma a instalação? (Y/N): " confirm
    case $confirm in
        Y|y)
            echo -e "${verde}Instalando N8N+MCP com SSL...${reset}"
            install_n8n_mcp_with_ssl
            echo -e "${verde}✅ N8N+MCP instalado com SSL automático!${reset}"
            echo -e "${verde}✅ Acesso seguro: https://$sub_n8n_mcp.$dominio_principal${reset}"
            ;;
        *)
            echo "Instalação cancelada."
            ;;
    esac
}

## SSL Implementation Functions
install_traefik_with_ssl() {
    echo -e "${verde}⚙️ Configurando Traefik com SSL automático...${reset}"
    
    # Create Traefik directory structure
    mkdir -p /opt/traefik/{data,rules}
    
    # Create traefik.yml configuration with automatic SSL
    cat > /opt/traefik/data/traefik.yml << EOF
api:
  dashboard: true
  insecure: false

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entrypoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"

certificatesResolvers:
  letsencrypt:
    acme:
      tlsChallenge: {}
      email: $email_ssl
      storage: /etc/traefik/acme/acme.json
      caServer: https://acme-v02.api.letsencrypt.org/directory

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: "traefik_proxy"
  file:
    directory: /etc/traefik/rules
    watch: true

log:
  level: INFO
EOF

    # Create Docker Compose for Traefik with SSL
    cat > /opt/traefik/docker-compose.yml << EOF
version: '3.8'

services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /opt/traefik/data/traefik.yml:/etc/traefik/traefik.yml:ro
      - /opt/traefik/data/acme.json:/etc/traefik/acme/acme.json
      - /opt/traefik/rules:/etc/traefik/rules:ro
    networks:
      - traefik_proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.rule=Host(\`$sub_traefik.$dominio_principal\`)"
      - "traefik.http.routers.traefik.tls=true"
      - "traefik.http.routers.traefik.tls.certresolver=letsencrypt"
      - "traefik.http.routers.traefik.service=api@internal"
      - "traefik.http.routers.traefik.middlewares=auth"
      - "traefik.http.middlewares.auth.basicauth.users=admin:$$2y$$10$$7yPuOLDr1nh.Example.Hash"

networks:
  traefik_proxy:
    external: true
EOF

    # Create ACME file with correct permissions
    touch /opt/traefik/data/acme.json
    chmod 600 /opt/traefik/data/acme.json
    
    # Create Traefik network
    docker network create traefik_proxy 2>/dev/null || true
    
    # Deploy Traefik
    cd /opt/traefik
    docker-compose up -d
    
    echo -e "${verde}✅ Traefik configurado com SSL automático${reset}"
    echo -e "${verde}📋 Dashboard: https://$sub_traefik.$dominio_principal${reset}"
}

install_portainer_with_ssl() {
    echo -e "${verde}⚙️ Configurando Portainer com SSL automático...${reset}"
    
    # Create Portainer volume
    docker volume create portainer_data
    
    # Deploy Portainer with SSL
    docker run -d \\
      --name portainer \\
      --restart unless-stopped \\
      -p 9000:9000 \\
      -v /var/run/docker.sock:/var/run/docker.sock \\
      -v portainer_data:/data \\
      --network traefik_proxy \\
      --label "traefik.enable=true" \\
      --label "traefik.http.routers.portainer.rule=Host(\`$sub_portainer.$dominio_principal\`)" \\
      --label "traefik.http.routers.portainer.tls=true" \\
      --label "traefik.http.routers.portainer.tls.certresolver=letsencrypt" \\
      --label "traefik.http.services.portainer.loadbalancer.server.port=9000" \\
      portainer/portainer-ce:latest
    
    echo -e "${verde}✅ Portainer configurado com SSL automático${reset}"
    echo -e "${verde}📋 Acesso: https://$sub_portainer.$dominio_principal${reset}"
}

install_evolution_with_ssl() {
    echo -e "${verde}⚙️ Configurando Evolution API com SSL automático...${reset}"
    
    # Deploy Evolution API with SSL via Traefik
    docker run -d \\
      --name evolution-api \\
      --restart unless-stopped \\
      --network traefik_proxy \\
      --label "traefik.enable=true" \\
      --label "traefik.http.routers.evolution.rule=Host(\`$sub_evolution.$dominio_principal\`)" \\
      --label "traefik.http.routers.evolution.tls=true" \\
      --label "traefik.http.routers.evolution.tls.certresolver=letsencrypt" \\
      --label "traefik.http.services.evolution.loadbalancer.server.port=8080" \\
      -e AUTHENTICATION_API_KEY="$(openssl rand -base64 32)" \\
      -e AUTHENTICATION_EXPOSE_IN_FETCH_INSTANCES=true \\
      -e QRCODE_LIMIT=30 \\
      -e EVOLUTION_API_URL="https://$sub_evolution.$dominio_principal" \\
      atendai/evolution-api:v1.7.1
    
    echo -e "${verde}✅ Evolution API configurada com SSL automático${reset}"
}

install_n8n_with_ssl() {
    echo -e "${verde}⚙️ Configurando N8N com SSL automático...${reset}"
    
    # Create N8N volume
    docker volume create n8n_data
    
    # Deploy N8N with SSL via Traefik
    docker run -d \\
      --name n8n \\
      --restart unless-stopped \\
      --network traefik_proxy \\
      -v n8n_data:/home/node/.n8n \\
      --label "traefik.enable=true" \\
      --label "traefik.http.routers.n8n.rule=Host(\`$sub_n8n.$dominio_principal\`)" \\
      --label "traefik.http.routers.n8n.tls=true" \\
      --label "traefik.http.routers.n8n.tls.certresolver=letsencrypt" \\
      --label "traefik.http.services.n8n.loadbalancer.server.port=5678" \\
      -e N8N_HOST="$sub_n8n.$dominio_principal" \\
      -e N8N_PROTOCOL="https" \\
      -e NODE_ENV="production" \\
      -e WEBHOOK_URL="https://$sub_n8n.$dominio_principal/" \\
      n8nio/n8n:latest
    
    echo -e "${verde}✅ N8N configurado com SSL automático${reset}"
}

install_n8n_mcp_with_ssl() {
    echo -e "${verde}⚙️ Configurando N8N+MCP com SSL automático...${reset}"
    
    # Create N8N MCP volume
    docker volume create n8n_mcp_data
    
    # Deploy N8N with MCP support and SSL via Traefik
    docker run -d \\
      --name n8n-mcp \\
      --restart unless-stopped \\
      --network traefik_proxy \\
      -v n8n_mcp_data:/home/node/.n8n \\
      --label "traefik.enable=true" \\
      --label "traefik.http.routers.n8n-mcp.rule=Host(\`$sub_n8n_mcp.$dominio_principal\`)" \\
      --label "traefik.http.routers.n8n-mcp.tls=true" \\
      --label "traefik.http.routers.n8n-mcp.tls.certresolver=letsencrypt" \\
      --label "traefik.http.services.n8n-mcp.loadbalancer.server.port=5678" \\
      -e N8N_HOST="$sub_n8n_mcp.$dominio_principal" \\
      -e N8N_PROTOCOL="https" \\
      -e NODE_ENV="production" \\
      -e WEBHOOK_URL="https://$sub_n8n_mcp.$dominio_principal/" \\
      -e N8N_AI_ENABLED="true" \\
      -e N8N_MCP_ENABLED="true" \\
      n8nio/n8n:latest
    
    echo -e "${verde}✅ N8N+MCP configurado com SSL automático${reset}"
}

ssl.status() {
    clear
    echo -e "${verde}=== STATUS DOS CERTIFICADOS SSL ===${reset}"
    echo ""
    
    if ! docker ps | grep -q "traefik"; then
        echo -e "${vermelho}❌ Traefik não está rodando${reset}"
        return 1
    fi
    
    echo -e "${verde}✅ Traefik ativo - SSL automático funcionando${reset}"
    echo ""
    
    # Check SSL certificates
    if [ -f "/opt/traefik/data/acme.json" ]; then
        echo -e "${verde}Certificados SSL Let's Encrypt:${reset}"
        
        # Count certificates
        cert_count=$(docker exec traefik cat /etc/traefik/acme/acme.json 2>/dev/null | grep -o '"Certificates"' | wc -l)
        
        if [ "$cert_count" -gt 0 ]; then
            echo -e "• ${verde}Certificados encontrados: $cert_count${reset}"
            echo -e "• ${verde}Renovação: Automática (Let's Encrypt)${reset}"
            echo -e "• ${verde}Validade: 90 dias com renovação automática${reset}"
        else
            echo -e "• ${amarelo}Nenhum certificado ainda gerado${reset}"
            echo -e "• ${amarelo}Certificados são gerados no primeiro acesso${reset}"
        fi
    else
        echo -e "${vermelho}❌ Arquivo ACME não encontrado${reset}"
    fi
    
    echo ""
    echo -e "${verde}Serviços com SSL configurado:${reset}"
    
    # Check running services with SSL
    docker ps --format "table {{.Names}}\\t{{.Labels}}" | grep "traefik.http.routers" | while read line; do
        service_name=$(echo "$line" | awk '{print $1}')
        if echo "$line" | grep -q "tls=true"; then
            echo -e "• ${verde}$service_name - SSL Ativo${reset}"
        fi
    done
    
    echo ""
    echo -e "${verde}Como funciona o SSL automático:${reset}"
    echo -e "• ${branco}Traefik detecta novos serviços automaticamente${reset}"
    echo -e "• ${branco}Gera certificados SSL via Let's Encrypt${reset}"
    echo -e "• ${branco}Renova certificados automaticamente${reset}"
    echo -e "• ${branco}Redireciona HTTP para HTTPS${reset}"
    echo -e "• ${branco}Certificados válidos por 90 dias${reset}"
}

ssl.check() {
    echo -e "${verde}Verificando configuração SSL...${reset}"
    
    if [ $# -eq 0 ]; then
        echo "Uso: ssl.check <dominio>"
        echo "Exemplo: ssl.check meusite.com"
        return 1
    fi
    
    domain=$1
    echo -e "Verificando SSL para: ${amarelo}$domain${reset}"
    
    # Check if domain responds with SSL
    if curl -Is "https://$domain" 2>/dev/null | head -n 1 | grep -q "200 OK"; then
        echo -e "${verde}✅ DOMÍNIO RESPONDE COM SSL${reset}"
        
        # Get SSL certificate info
        ssl_info=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
        
        if [ $? -eq 0 ]; then
            echo -e "${verde}Informações do Certificado:${reset}"
            echo "$ssl_info" | grep "notBefore" | sed 's/notBefore=/• Válido desde: /'
            echo "$ssl_info" | grep "notAfter" | sed 's/notAfter=/• Expira em: /'
        fi
    else
        echo -e "${vermelho}❌ DOMÍNIO NÃO RESPONDE OU SSL INATIVO${reset}"
        echo -e "${amarelo}Verifique:${reset}"
        echo -e "• DNS apontando para o servidor"
        echo -e "• Portas 80 e 443 abertas"
        echo -e "• Traefik rodando corretamente"
    fi
}

portainer.restart() {
    echo "Reiniciando Portainer..."
    docker restart portainer 2>/dev/null || echo "Portainer não encontrado"
}

ctop() {
    echo "Instalando CTOP..."
    curl -Lo ctop https://github.com/bcicen/ctop/releases/download/v0.7.7/ctop-0.7.7-linux-amd64
    sudo mv ctop /usr/local/bin/ && sudo chmod +x /usr/local/bin/ctop
    echo "CTOP instalado!"
}

htop() {
    echo "Instalando HTOP..."
    sudo apt update && sudo apt install htop -y
    echo "HTOP instalado!"
}

limpar() {
    echo "Limpando sistema Docker..."
    docker system prune -af
    echo "Limpeza concluída!"
}

## Main installer loop
nome_instalador
direitos_instalador

while true; do
    nome_menu
    menu_instalador_pg_1

    read -p "Digite o NÚMERO da opção desejada ou COMANDO: " opcao
    set -- $opcao
    opcao1=$1
    opcao2=$2

    case $opcao1 in
        1|01|portainer|traefik|PORTAINER|TRAEFIK)
            verificar_stack "traefik" && continue
            verificar_stack "portainer" && continue
            ferramenta_traefik_e_portainer
            ;;
        2|02|evolution|evo|EVO)
            verificar_stack "evolution${opcao2:+_$opcao2}" && continue
            if verificar_docker_e_portainer_traefik; then
                ferramenta_evolution "$opcao2"
            fi
            ;;
        3|03|n8n|N8N)
            verificar_stack "n8n${opcao2:+_$opcao2}" && continue
            if verificar_docker_e_portainer_traefik; then
                ferramenta_n8n "$opcao2"
            fi
            ;;
        4|04|n8n.mcp|N8N.MCP)
            verificar_stack "n8n${opcao2:+_$opcao2}_mcp" && continue
            if verificar_docker_e_portainer_traefik; then
                n8n.mcp "$opcao2"
            fi
            ;;
        portainer.restart) portainer.restart ;;
        atualizar|update|ATUALIZAR|UPDATE) atualizar_script ;;
        ssl.status) ssl.status; read -p "Pressione Enter para continuar..." ;;
        ssl.check) 
            read -p "Digite o domínio para verificar SSL: " ssl_domain
            ssl.check "$ssl_domain"
            read -p "Pressione Enter para continuar..."
            ;;
        ctop) ctop ;;
        htop) htop ;;
        limpar|clean|LIMPAR|CLEAN) limpar ;;
        comandos|COMANDOS) menu_comandos; read -p "Pressione Enter para continuar..." ;;
        sair|fechar|exit|close|x)
            clear
            echo "Saindo do instalador..."
            break
            ;;
        *) echo "Opção inválida." ;;
    esac
    echo ""
done