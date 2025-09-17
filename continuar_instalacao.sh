#!/bin/bash

# CONTINUACAO DA INSTALACAO - SETUPALICIA
# Script para resolver problemas de Docker Swarm e continuar instalacao

set -e

# Funcao para log colorido
log_info() { echo -e "\033[34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[32m[SUCESSO]\033[0m $1"; }
log_warning() { echo -e "\033[33m[AVISO]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERRO]\033[0m $1"; }

clear
echo "================================================================"
echo "              CONTINUACAO DA INSTALACAO                       "
echo "           Resolvendo Docker Swarm e Continuando              "
echo "================================================================"
echo ""

# Verificar se arquivo .env existe
if [ ! -f ".env" ]; then
    log_error "Arquivo .env nao encontrado! Execute o script principal primeiro."
    exit 1
fi

# Carregar variaveis do .env
source .env

log_info "Carregando configuracao existente..."
echo "Email: $SSL_EMAIL"
echo "N8N: $DOMINIO_N8N"
echo "Portainer: $DOMINIO_PORTAINER"
echo "Webhook: $WEBHOOK_N8N"
echo "Evolution: $DOMINIO_EVOLUTION"
echo ""

# Obter IP do servidor
server_ip=$(curl -s ifconfig.me || curl -s icanhazip.com || hostname -I | cut -d' ' -f1)
log_info "IP do servidor detectado: $server_ip"

# CORRIGIR DOCKER SWARM
log_info "Corrigindo configuracao do Docker Swarm..."

# Limpar qualquer configuracao anterior
docker swarm leave --force >/dev/null 2>&1 || true

# Metodos alternativos para inicializar Swarm
log_info "Tentativa 1: Inicializacao com IP especifico..."
if docker swarm init --advertise-addr $server_ip >/dev/null 2>&1; then
    log_success "Docker Swarm inicializado com IP especifico!"
else
    log_warning "Tentativa 1 falhou. Tentando metodo 2..."
    
    if docker swarm init --force-new-cluster >/dev/null 2>&1; then
        log_success "Docker Swarm inicializado com force-new-cluster!"
    else
        log_warning "Tentativa 2 falhou. Tentando metodo 3..."
        
        if docker swarm init >/dev/null 2>&1; then
            log_success "Docker Swarm inicializado (metodo basico)!"
        else
            log_error "Todas as tentativas de Swarm falharam!"
            log_info "Tentando diagnostico..."
            
            # Verificar status do Docker
            if ! docker info >/dev/null 2>&1; then
                log_error "Docker nao esta funcionando corretamente!"
                log_info "Reiniciando Docker..."
                systemctl restart docker
                sleep 10
                
                # Tentar novamente apos restart
                if docker swarm init >/dev/null 2>&1; then
                    log_success "Docker Swarm inicializado apos restart!"
                else
                    log_error "Problema persistente com Docker Swarm"
                    exit 1
                fi
            fi
        fi
    fi
fi

# Verificar se Swarm esta ativo
if docker info --format '{{.Swarm.LocalNodeState}}' | grep -q "active"; then
    log_success "Docker Swarm ativo e funcionando!"
else
    log_error "Docker Swarm nao esta ativo!"
    exit 1
fi

# Criar rede overlay
log_info "Criando rede overlay..."
docker network create --driver=overlay network_public >/dev/null 2>&1 || true

if docker network ls | grep -q "network_public"; then
    log_success "Rede overlay criada com sucesso!"
else
    log_error "Falha ao criar rede overlay!"
    exit 1
fi

log_success "Configuracao do Docker Swarm corrigida!"
echo ""
echo "PROXIMOS PASSOS:"
echo "1. O Docker Swarm agora esta funcionando"
echo "2. Execute o script principal novamente:"
echo "   bash setup_definitivo_limpo.sh \\"
echo "     leonardonetto1982@gmail.com \\"
echo "     editor.publiczap.com.br \\"
echo "     portainer.publiczap.com.br \\"
echo "     webhook.publiczap.com.br \\"
echo "     evo.publiczap.com.br"
echo ""
echo "OU continue manualmente com as próximas etapas:"

# OPCAO: Continuar instalacao automaticamente
read -p "Deseja continuar a instalacao agora? (s/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    log_info "Continuando instalacao automaticamente..."
    
    # Funcao para aguardar servico
    wait_service_perfect() {
        local service_name=$1
        local max_wait=${2:-300}
        
        log_info "Aguardando $service_name..."
        
        for i in $(seq 1 60); do
            if docker service ls --filter name=$service_name --format "{{.Name}}" | grep -q "$service_name"; then
                break
            fi
            sleep 5
        done
        
        for i in $(seq 1 $max_wait); do
            if docker ps --filter "name=$service_name" --format "{{.Names}}" | grep -q "$service_name"; then
                log_success "$service_name funcionando!"
                return 0
            fi
            
            if [ $((i % 30)) -eq 0 ]; then
                echo "   ... aguardando $service_name ($i/${max_wait}s)"
            fi
            sleep 1
        done
        
        log_error "Timeout aguardando $service_name"
        return 1
    }
    
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
    
    log_success "Traefik e Portainer instalados!"
    log_info "Aguarde alguns minutos para os certificados SSL serem gerados..."
    log_info "Acesse https://$DOMINIO_PORTAINER para configurar o Portainer"
    
    echo ""
    echo "CREDENCIAIS SALVAS EM .env:"
    echo "- SSL_EMAIL: $SSL_EMAIL"
    echo "- DOMINIO_PORTAINER: $DOMINIO_PORTAINER"
    echo "- DOMINIO_N8N: $DOMINIO_N8N"
    echo "- WEBHOOK_N8N: $WEBHOOK_N8N"
    echo "- DOMINIO_EVOLUTION: $DOMINIO_EVOLUTION"
    
else
    log_info "Instalacao pausada. Execute o script principal quando estiver pronto."
fi

log_success "Script de continuacao concluido!"