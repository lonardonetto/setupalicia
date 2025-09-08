#!/bin/bash

## SetupAlicia v2.7.1 - Simplified Version
## Only essential applications: Traefik, Portainer, Evolution, N8N, N8N+MCP
## Instalação: bash <(curl -sSL https://raw.githubusercontent.com/lonardonetto/setupalicia/main/setup.sh)

# Verificar conectividade
if ! curl -sSf https://www.google.com >/dev/null 2>&1; then
    echo "❌ Erro: Sem conexão com a internet"
    exit 1
fi

# Verificar se Docker está instalado
if ! command -v docker &> /dev/null; then
    echo "⚠️  Docker não encontrado. Instalando Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    echo "✅ Docker instalado!"
fi

# Inicializar Docker Swarm se não estiver ativo
SWARM_STATUS=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)
if [ "$SWARM_STATUS" != "active" ]; then
    echo "⚠️  Inicializando Docker Swarm..."
    docker swarm init --advertise-addr $(hostname -I | awk '{print $1}') 2>/dev/null
    echo "✅ Docker Swarm inicializado!"
fi

# Criar diretórios necessários
mkdir -p /root/dados_vps

# Configurar rede do Docker Swarm
docker network create --driver overlay --attachable traefik_proxy 2>/dev/null || true

## Colors
amarelo="\e[33m"
verde="\e[32m"
branco="\e[97m"
vermelho="\e[91m"
reset="\e[0m"

## Version info
versao() {
echo -e "                     \e[97mSetupAlicia: \e[32mv. 2.7.1 (Simplified)\e[0m"
echo -e "\e[32mraw.githubusercontent.com/lonardonetto/setupalicia/main    \e[97m<----- Instalação Remota ----->     \e[32mbash <(curl -sSL raw.githubusercontent.com/lonardonetto/setupalicia/main/setup.sh)\e[0m"
echo -e "\e[32malicia.setup.com/whatsapp2      \e[97m<----- Grupos no WhatsApp ----->     \e[32malicia.setup.com/whatsapp3\e[0m"
}

## Atualizar script
atualizar_script() {
    echo -e "${verde}Verificando atualizações...${reset}"
    
    # Download da versão mais recente
    curl -sSL https://raw.githubusercontent.com/lonardonetto/setupalicia/main/setup.sh -o /tmp/setupalicia_new.sh
    
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
    echo -e "${branco} • ${amarelo}ctop${reset} - ${branco}Instala o CTOP${reset}"
    echo -e "${branco} • ${amarelo}htop${reset} - ${branco}Instala o HTOP${reset}"
    echo -e "${branco} • ${amarelo}limpar${reset} - ${branco}Limpa Docker${reset}"
    echo -e ""
    echo -e "${verde}Instalação Remota:${reset}"
    echo -e "${branco} • ${amarelo}bash <(curl -sSL raw.githubusercontent.com/lonardonetto/setupalicia/main/setup.sh)${reset}"
    echo -e ""
    echo -e "${verde}Acesso aos Serviços:${reset}"
    echo -e "${branco} • Traefik Dashboard: ${amarelo}http://IP_SERVIDOR:8080${reset}"
    echo -e "${branco} • Portainer: ${amarelo}http://IP_SERVIDOR:9000${reset}"
    echo -e "${branco} • Evolution/N8N/MCP: ${amarelo}https://SEU_DOMINIO.com${reset}"
    echo -e ""
    echo -e "${verde}Funcionalidades SSL:${reset}"
    echo -e "${branco} • Traefik: ${verde}Não precisa de domínio (somente IP)${reset}"
    echo -e "${branco} • Aplicações: ${verde}SSL automático via Let's Encrypt${reset}"
    echo -e "${branco} • Redirecionamento: ${verde}HTTP -> HTTPS automático${reset}"
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

## Installation functions with Docker Swarm support
ferramenta_traefik_e_portainer() {
    clear
    echo -e "${verde}=== INSTALAÇÃO TRAEFIK & PORTAINER COM DOCKER SWARM ===${reset}"
    echo ""
    
    echo -e "${amarelo}Configuração Docker Swarm:${reset}"
    echo -e "• Rede: ${verde}traefik_proxy${reset}"
    echo -e "• Acesso Traefik: ${amarelo}http://IP_SERVIDOR:8080${reset}"
    echo -e "• Acesso Portainer: ${amarelo}http://IP_SERVIDOR:9000${reset}"
    echo -e "• Modo: ${verde}Docker Swarm Stack${reset}"
    echo -e "• SSL: ${verde}Automático via Let's Encrypt${reset}"
    echo ""
    
    read -p "Confirma a instalação? (Y/N): " confirm
    case $confirm in
        Y|y)
            echo -e "${verde}Iniciando instalação...${reset}"
            install_traefik_swarm
            install_portainer_swarm
            echo -e "${verde}✅ Traefik & Portainer instalados com Docker Swarm!${reset}"
            echo -e "${verde}✅ Traefik Dashboard: http://$(hostname -I | awk '{print $1}'):8080${reset}"
            echo -e "${verde}✅ Portainer: http://$(hostname -I | awk '{print $1}'):9000${reset}"
            echo -e "${verde}✅ SSL automático configurado para outras aplicações${reset}"
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
    
    read -p "Digite o domínio para Evolution API (ex: evolution.meudominio.com): " dominio_evolution
    
    echo ""
    echo -e "${verde}Configuração Evolution API:${reset}"
    echo -e "• Domínio: ${amarelo}$dominio_evolution${reset}"
    echo -e "• SSL: ${verde}Automático via Traefik + Let's Encrypt${reset}"
    echo -e "• Modo: ${verde}Docker Swarm Stack${reset}"
    echo ""
    
    read -p "Confirma a instalação? (Y/N): " confirm
    case $confirm in
        Y|y)
            echo -e "${verde}Instalando Evolution API...${reset}"
            install_evolution_swarm_ssl "$dominio_evolution"
            echo -e "${verde}✅ Evolution API instalada!${reset}"
            echo -e "${verde}✅ Acesso: https://$dominio_evolution${reset}"
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
    
    read -p "Digite o domínio para N8N (ex: n8n.meudominio.com): " dominio_n8n
    
    echo ""
    echo -e "${verde}Configuração N8N:${reset}"
    echo -e "• Domínio: ${amarelo}$dominio_n8n${reset}"
    echo -e "• SSL: ${verde}Automático via Traefik + Let's Encrypt${reset}"
    echo -e "• Workflows: ${verde}Interface visual para automação${reset}"
    echo -e "• Modo: ${verde}Docker Swarm Stack${reset}"
    echo ""
    
    read -p "Confirma a instalação? (Y/N): " confirm
    case $confirm in
        Y|y)
            echo -e "${verde}Instalando N8N...${reset}"
            install_n8n_swarm_ssl "$dominio_n8n"
            echo -e "${verde}✅ N8N instalado!${reset}"
            echo -e "${verde}✅ Acesso: https://$dominio_n8n${reset}"
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
    
    read -p "Digite o domínio para N8N+MCP (ex: n8n-mcp.meudominio.com): " dominio_n8n_mcp
    
    echo ""
    echo -e "${verde}Configuração N8N + MCP:${reset}"
    echo -e "• Domínio: ${amarelo}$dominio_n8n_mcp${reset}"
    echo -e "• SSL: ${verde}Automático via Traefik + Let's Encrypt${reset}"
    echo -e "• MCP: ${verde}Model Context Protocol integrado${reset}"
    echo -e "• AI Integration: ${verde}Suporte avançado para IA${reset}"
    echo -e "• Modo: ${verde}Docker Swarm Stack${reset}"
    echo ""
    
    read -p "Confirma a instalação? (Y/N): " confirm
    case $confirm in
        Y|y)
            echo -e "${verde}Instalando N8N+MCP...${reset}"
            install_n8n_mcp_swarm_ssl "$dominio_n8n_mcp"
            echo -e "${verde}✅ N8N+MCP instalado!${reset}"
            echo -e "${verde}✅ Acesso: https://$dominio_n8n_mcp${reset}"
            ;;
        *)
            echo "Instalação cancelada."
            ;;
    esac
}

## Docker Swarm Implementation Functions
install_traefik_swarm() {
    echo -e "${verde}⚙️ Configurando Traefik com Docker Swarm e SSL...${reset}"
    
    # Create traefik.yaml stack
    cat > traefik.yaml << EOF
version: "3.7"
services:

## --------------------------- ALICIA --------------------------- ##

  traefik:
    image: traefik:v3.0
    command:
      - --api.dashboard=true
      - --api.insecure=true
      - --providers.docker=true
      - --providers.docker.swarmmode=true
      - --providers.docker.exposedbydefault=false
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --certificatesresolvers.letsencryptresolver.acme.httpchallenge=true
      - --certificatesresolvers.letsencryptresolver.acme.httpchallenge.entrypoint=web
      - --certificatesresolvers.letsencryptresolver.acme.email=admin@exemplo.com
      - --certificatesresolvers.letsencryptresolver.acme.storage=/etc/traefik/acme/acme.json
      - --certificatesresolvers.letsencryptresolver.acme.caserver=https://acme-v02.api.letsencrypt.org/directory
      - --log.level=INFO

    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"

    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - traefik_acme:/etc/traefik/acme

    networks:
      - traefik_proxy

    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.http.routers.traefik.rule=Host(\`traefik\`)
        - traefik.http.routers.traefik.service=api@internal
        - traefik.http.services.traefik.loadbalancer.server.port=8080

## --------------------------- ALICIA --------------------------- ##

volumes:
  traefik_acme:
    external: true
    name: traefik_acme

networks:
  traefik_proxy:
    external: true
    name: traefik_proxy
EOF

    # Create ACME volume
    docker volume create traefik_acme 2>/dev/null || true
    
    # Deploy Traefik stack
    docker stack deploy --prune --resolve-image always -c traefik.yaml traefik
    if [ $? -eq 0 ]; then
        echo -e "${verde}✅ Traefik configurado com Docker Swarm e SSL${reset}"
    else
        echo -e "${vermelho}❌ Erro ao configurar Traefik${reset}"
    fi
}

install_portainer_swarm() {
    echo -e "${verde}⚙️ Configurando Portainer com Docker Swarm...${reset}"
    
    # Create portainer.yaml stack
    cat > portainer.yaml << EOF
version: "3.7"
services:

## --------------------------- ALICIA --------------------------- ##

  portainer:
    image: portainer/portainer-ce:latest
    command: -H unix:///var/run/docker.sock

    ports:
      - "9000:9000"

    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data

    networks:
      - traefik_proxy

    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.http.routers.portainer.rule=Host(\`portainer\`)
        - traefik.http.services.portainer.loadbalancer.server.port=9000

## --------------------------- ALICIA --------------------------- ##

volumes:
  portainer_data:
    external: true
    name: portainer_data

networks:
  traefik_proxy:
    external: true
    name: traefik_proxy
EOF

    # Create Portainer volume
    docker volume create portainer_data 2>/dev/null || true
    
    # Deploy Portainer stack
    docker stack deploy --prune --resolve-image always -c portainer.yaml portainer
    if [ $? -eq 0 ]; then
        echo -e "${verde}✅ Portainer configurado com Docker Swarm${reset}"
    else
        echo -e "${vermelho}❌ Erro ao configurar Portainer${reset}"
    fi
}

install_evolution_swarm() {
    echo -e "${verde}⚙️ Configurando Evolution API com Docker Swarm...${reset}"
    
    # Create evolution.yaml stack
    cat > evolution.yaml << EOF
version: "3.7"
services:

## --------------------------- ALICIA --------------------------- ##

  evolution:
    image: atendai/evolution-api:v1.7.1

    ports:
      - "8081:8080"

    networks:
      - traefik_proxy

    environment:
      - AUTHENTICATION_API_KEY=\$(openssl rand -base64 32)
      - AUTHENTICATION_EXPOSE_IN_FETCH_INSTANCES=true
      - QRCODE_LIMIT=30
      - EVOLUTION_API_URL=http://\$(hostname -I | awk '{print \$1}'):8081

    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.http.routers.evolution.rule=Host(\`evolution\`)
        - traefik.http.services.evolution.loadbalancer.server.port=8080

## --------------------------- ALICIA --------------------------- ##

networks:
  traefik_proxy:
    external: true
    name: traefik_proxy
EOF

    # Deploy Evolution stack
    docker stack deploy --prune --resolve-image always -c evolution.yaml evolution
    if [ $? -eq 0 ]; then
        echo -e "${verde}✅ Evolution API configurada com Docker Swarm${reset}"
    else
        echo -e "${vermelho}❌ Erro ao configurar Evolution API${reset}"
    fi
}

install_n8n_swarm() {
    echo -e "${verde}⚙️ Configurando N8N com Docker Swarm...${reset}"
    
    # Create n8n.yaml stack
    cat > n8n.yaml << EOF
version: "3.7"
services:

## --------------------------- ALICIA --------------------------- ##

  n8n:
    image: n8nio/n8n:latest

    ports:
      - "5678:5678"

    volumes:
      - n8n_data:/home/node/.n8n

    networks:
      - traefik_proxy

    environment:
      - NODE_ENV=production
      - N8N_HOST=\$(hostname -I | awk '{print \$1}')
      - N8N_PROTOCOL=http
      - N8N_PORT=5678

    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.http.routers.n8n.rule=Host(\`n8n\`)
        - traefik.http.services.n8n.loadbalancer.server.port=5678

## --------------------------- ALICIA --------------------------- ##

volumes:
  n8n_data:
    external: true
    name: n8n_data

networks:
  traefik_proxy:
    external: true
    name: traefik_proxy
EOF

    # Create N8N volume
    docker volume create n8n_data 2>/dev/null || true
    
    # Deploy N8N stack
    docker stack deploy --prune --resolve-image always -c n8n.yaml n8n
    if [ $? -eq 0 ]; then
        echo -e "${verde}✅ N8N configurado com Docker Swarm${reset}"
    else
        echo -e "${vermelho}❌ Erro ao configurar N8N${reset}"
    fi
}

install_n8n_mcp_swarm() {
    echo -e "${verde}⚙️ Configurando N8N+MCP com Docker Swarm...${reset}"
    
    # Create n8n-mcp.yaml stack
    cat > n8n-mcp.yaml << EOF
version: "3.7"
services:

## --------------------------- ALICIA --------------------------- ##

  n8n-mcp:
    image: n8nio/n8n:latest

    ports:
      - "5679:5678"

    volumes:
      - n8n_mcp_data:/home/node/.n8n

    networks:
      - traefik_proxy

    environment:
      - NODE_ENV=production
      - N8N_HOST=\$(hostname -I | awk '{print \$1}')
      - N8N_PROTOCOL=http
      - N8N_PORT=5678
      - N8N_AI_ENABLED=true
      - N8N_MCP_ENABLED=true

    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.http.routers.n8n-mcp.rule=Host(\`n8n-mcp\`)
        - traefik.http.services.n8n-mcp.loadbalancer.server.port=5678

## --------------------------- ALICIA --------------------------- ##

volumes:
  n8n_mcp_data:
    external: true
    name: n8n_mcp_data

networks:
  traefik_proxy:
    external: true
    name: traefik_proxy
EOF

    # Create N8N MCP volume
    docker volume create n8n_mcp_data 2>/dev/null || true
    
    # Deploy N8N MCP stack
    docker stack deploy --prune --resolve-image always -c n8n-mcp.yaml n8n-mcp
    if [ $? -eq 0 ]; then
        echo -e "${verde}✅ N8N+MCP configurado com Docker Swarm${reset}"
    else
        echo -e "${vermelho}❌ Erro ao configurar N8N+MCP${reset}"
    fi
}

portainer.restart() {
    echo "Reiniciando Portainer..."
    docker service update --force portainer_portainer 2>/dev/null || echo "Portainer stack não encontrado"
}

ctop() {
    echo "Instalando CTOP..."
    curl -Lo ctop https://github.com/bcicen/ctop/releases/download/v0.7.7/ctop-0.7.7-linux-amd64
    sudo mv ctop /usr/local/bin/ && sudo chmod +x /usr/local/bin/ctop
    echo "CTOP instalado!"
}

htop() {
    echo "Instalando HTOP..."
    apt update && apt install htop -y
    echo "HTOP instalado!"
}

limpar() {
    echo "Limpando sistema Docker..."
    docker system prune -af
}

install_evolution_swarm_ssl() {
    local dominio="$1"
    echo -e "${verde}⚙️ Configurando Evolution API com Docker Swarm e SSL...${reset}"
    
    # Create evolution.yaml stack
    cat > evolution.yaml << EOF
version: "3.7"
services:

## --------------------------- ALICIA --------------------------- ##

  evolution:
    image: atendai/evolution-api:v1.7.1

    networks:
      - traefik_proxy

    environment:
      - AUTHENTICATION_API_KEY=\$(openssl rand -base64 32)
      - AUTHENTICATION_EXPOSE_IN_FETCH_INSTANCES=true
      - QRCODE_LIMIT=30
      - EVOLUTION_API_URL=https://$dominio

    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.http.routers.evolution.rule=Host(\`$dominio\`)
        - traefik.http.routers.evolution.tls=true
        - traefik.http.routers.evolution.tls.certresolver=letsencryptresolver
        - traefik.http.routers.evolution.entrypoints=websecure
        - traefik.http.services.evolution.loadbalancer.server.port=8080
        - traefik.http.routers.evolution-redirect.rule=Host(\`$dominio\`)
        - traefik.http.routers.evolution-redirect.entrypoints=web
        - traefik.http.routers.evolution-redirect.middlewares=redirect-to-https
        - traefik.http.middlewares.redirect-to-https.redirectscheme.scheme=https

## --------------------------- ALICIA --------------------------- ##

networks:
  traefik_proxy:
    external: true
    name: traefik_proxy
EOF

    # Deploy Evolution stack
    docker stack deploy --prune --resolve-image always -c evolution.yaml evolution
    if [ $? -eq 0 ]; then
        echo -e "${verde}✅ Evolution API configurada com Docker Swarm e SSL${reset}"
    else
        echo -e "${vermelho}❌ Erro ao configurar Evolution API${reset}"
    fi
}

install_n8n_swarm_ssl() {
    local dominio="$1"
    echo -e "${verde}⚙️ Configurando N8N com Docker Swarm e SSL...${reset}"
    
    # Create n8n.yaml stack
    cat > n8n.yaml << EOF
version: "3.7"
services:

## --------------------------- ALICIA --------------------------- ##

  n8n:
    image: n8nio/n8n:latest

    volumes:
      - n8n_data:/home/node/.n8n

    networks:
      - traefik_proxy

    environment:
      - NODE_ENV=production
      - N8N_HOST=$dominio
      - N8N_PROTOCOL=https
      - N8N_PORT=443
      - WEBHOOK_URL=https://$dominio/

    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.http.routers.n8n.rule=Host(\`$dominio\`)
        - traefik.http.routers.n8n.tls=true
        - traefik.http.routers.n8n.tls.certresolver=letsencryptresolver
        - traefik.http.routers.n8n.entrypoints=websecure
        - traefik.http.services.n8n.loadbalancer.server.port=5678
        - traefik.http.routers.n8n-redirect.rule=Host(\`$dominio\`)
        - traefik.http.routers.n8n-redirect.entrypoints=web
        - traefik.http.routers.n8n-redirect.middlewares=redirect-to-https

## --------------------------- ALICIA --------------------------- ##

volumes:
  n8n_data:
    external: true
    name: n8n_data

networks:
  traefik_proxy:
    external: true
    name: traefik_proxy
EOF

    # Create N8N volume
    docker volume create n8n_data 2>/dev/null || true
    
    # Deploy N8N stack
    docker stack deploy --prune --resolve-image always -c n8n.yaml n8n
    if [ $? -eq 0 ]; then
        echo -e "${verde}✅ N8N configurado com Docker Swarm e SSL${reset}"
    else
        echo -e "${vermelho}❌ Erro ao configurar N8N${reset}"
    fi
}

install_n8n_mcp_swarm_ssl() {
    local dominio="$1"
    echo -e "${verde}⚙️ Configurando N8N+MCP com Docker Swarm e SSL...${reset}"
    
    # Create n8n-mcp.yaml stack
    cat > n8n-mcp.yaml << EOF
version: "3.7"
services:

## --------------------------- ALICIA --------------------------- ##

  n8n-mcp:
    image: n8nio/n8n:latest

    volumes:
      - n8n_mcp_data:/home/node/.n8n

    networks:
      - traefik_proxy

    environment:
      - NODE_ENV=production
      - N8N_HOST=$dominio
      - N8N_PROTOCOL=https
      - N8N_PORT=443
      - WEBHOOK_URL=https://$dominio/
      - N8N_AI_ENABLED=true
      - N8N_MCP_ENABLED=true

    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.http.routers.n8n-mcp.rule=Host(\`$dominio\`)
        - traefik.http.routers.n8n-mcp.tls=true
        - traefik.http.routers.n8n-mcp.tls.certresolver=letsencryptresolver
        - traefik.http.routers.n8n-mcp.entrypoints=websecure
        - traefik.http.services.n8n-mcp.loadbalancer.server.port=5678
        - traefik.http.routers.n8n-mcp-redirect.rule=Host(\`$dominio\`)
        - traefik.http.routers.n8n-mcp-redirect.entrypoints=web
        - traefik.http.routers.n8n-mcp-redirect.middlewares=redirect-to-https

## --------------------------- ALICIA --------------------------- ##

volumes:
  n8n_mcp_data:
    external: true
    name: n8n_mcp_data

networks:
  traefik_proxy:
    external: true
    name: traefik_proxy
EOF

    # Create N8N MCP volume
    docker volume create n8n_mcp_data 2>/dev/null || true
    
    # Deploy N8N MCP stack
    docker stack deploy --prune --resolve-image always -c n8n-mcp.yaml n8n-mcp
    if [ $? -eq 0 ]; then
        echo -e "${verde}✅ N8N+MCP configurado com Docker Swarm e SSL${reset}"
    else
        echo -e "${vermelho}❌ Erro ao configurar N8N+MCP${reset}"
    fi
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
            verificar_stack "n8n-mcp${opcao2:+_$opcao2}" && continue
            if verificar_docker_e_portainer_traefik; then
                n8n.mcp "$opcao2"
            fi
            ;;
        portainer.restart) portainer.restart ;;
        atualizar|update|ATUALIZAR|UPDATE) atualizar_script ;;
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
            verificar_stack "n8n-mcp${opcao2:+_$opcao2}" && continue
            if verificar_docker_e_portainer_traefik; then
                n8n.mcp "$opcao2"
            fi
            ;;
        portainer.restart) portainer.restart ;;
        atualizar|update|ATUALIZAR|UPDATE) atualizar_script ;;
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