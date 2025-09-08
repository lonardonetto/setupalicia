#!/bin/bash

# Instalador do N8N + Evolution API no Docker Swarm
# Autor: Maicon Ramos - Automação sem Limites  
# Versao: 0.2

SSL_EMAIL=$1
DOMINIO_N8N=$2
DOMINIO_PORTAINER=$3
WEBHOOK_N8N=$4
DOMINIO_EVOLUTION=$5

echo "Iniciando instalação.."

N8N_KEY=$(openssl rand -hex 16)
POSTGRES_PASSWORD=$(openssl rand -base64 12)
EVOLUTION_API_KEY=$(openssl rand -hex 32)

echo "SSL_EMAIL=$SSL_EMAIL" > .env
echo "DOMINIO_N8N=$DOMINIO_N8N" >> .env
echo "WEBHOOK_N8N=$WEBHOOK_N8N" >> .env
echo "DOMINIO_PORTAINER=$DOMINIO_PORTAINER" >> .env
echo "DOMINIO_EVOLUTION=$DOMINIO_EVOLUTION" >> .env
echo "N8N_KEY=$N8N_KEY" >> .env
echo "POSTGRES_PASSWORD=$POSTGRES_PASSWORD" >> .env
echo "EVOLUTION_API_KEY=$EVOLUTION_API_KEY" >> .env

#evitar interação
export DEBIAN_FRONTEND=noninteractive

#ajustar fuso horário
sudo timedatectl set-timezone America/Sao_Paulo

echo "Instalando vários pacotes necessários, dependendo do servidor pode demorar um pouco"
# Atualize os pacotes, Curl e outros
{
    DEBIAN_FRONTEND=noninteractive apt update -y &&
    DEBIAN_FRONTEND=noninteractive apt upgrade -y &&
    DEBIAN_FRONTEND=noninteractive apt-get install -y apparmor-utils &&
    DEBIAN_FRONTEND=noninteractive sudo apt install -y curl &&
    DEBIAN_FRONTEND=noninteractive sudo apt install -y lsb-release ca-certificates apt-transport-https software-properties-common gnupg2
} >> instalacao_n8n_evolution.log 2>&1 &
wait

echo "Lista de Pacotes atualizados"
while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
    sleep 10
done

echo "Alocando um arquivo de swap "
# Aloca um arquivo de swap
sudo fallocate -l 4G /swapfile >> instalacao_n8n_evolution.log 2>&1
sudo chmod 600 /swapfile >> instalacao_n8n_evolution.log 2>&1
sudo mkswap /swapfile >> instalacao_n8n_evolution.log 2>&1
sudo swapon /swapfile >> instalacao_n8n_evolution.log 2>&1
sudo cp /etc/fstab /etc/fstab.bak >> instalacao_n8n_evolution.log 2>&1
echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab >> instalacao_n8n_evolution.log 2>&1
echo "Swap alocado!"

echo "Atualizando nome do Servidor"

# Novo hostname que será configurado
novo_hostname="manager1"
# Alterar o arquivo /etc/hosts para atualizar o hostname
sudo sed -i "s/127.0.0.1.*/127.0.0.1 $novo_hostname/" /etc/hosts
# Atualizar o hostname da máquina
sudo hostnamectl set-hostname $novo_hostname

while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
    sleep 10
done
echo "Instalando o Docker..."
# Instalar o Docker
curl -fsSL https://get.docker.com | bash >> instalacao_n8n_evolution.log 2>&1 && echo "Docker instalado com sucesso!"

while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
    sleep 10
done
sudo usermod -aG docker $USER

echo "Configurando o Docker Swarm"
# Obter o endereço IP da interface de rede eth0
endereco_ip=$(ip -o -4 addr show eth0 | awk '{split($4, a, "/"); print a[1]}' | head -n 1)
# Verificar se o endereço IP foi obtido corretamente
if [[ -z $endereco_ip ]]; then
    echo "Não foi possível obter o endereço IP da interface eth0."
    exit 1
fi
# Iniciar o Swarm usando o endereço IP obtido
docker swarm init --advertise-addr $endereco_ip >> instalacao_n8n_evolution.log 2>&1 && echo "Docker Swarm iniciado"
# Configurar a rede do Docker Swarm
docker network create --driver=overlay --attachable traefik_proxy >> instalacao_n8n_evolution.log 2>&1 && echo "Rede Swarm Criada com sucesso!"

#Stack do Traefik 
echo "Configurando o Traefik com o e-mail $SSL_EMAIL"
curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/traefik.yaml" -o "traefik.yaml"
#Executar o Stack do Traefik
env SSL_EMAIL="$SSL_EMAIL" docker stack deploy --prune --resolve-image always -c traefik.yaml traefik >> instalacao_n8n_evolution.log 2>&1 && echo "Traefik instalado com sucesso!"

#Stack do Portainer 
echo "Configurando o Portainer com o domínio $DOMINIO_PORTAINER"
curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/portainer.yaml" -o "portainer.yaml"
env DOMINIO_PORTAINER="$DOMINIO_PORTAINER" docker stack deploy --prune --resolve-image always -c portainer.yaml portainer >> instalacao_n8n_evolution.log 2>&1 && echo "Portainer instalado com sucesso!"

#Stack do Postgres
echo "Configurando o Banco de Dados Postgres"
curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/postgres.yaml" -o "postgres.yaml"
#Executar o Stack do Postgres
env POSTGRES_PASSWORD="$POSTGRES_PASSWORD" docker stack deploy --prune --resolve-image always -c postgres.yaml postgres >> instalacao_n8n_evolution.log 2>&1 && echo "Postgress instalado com sucesso!"

#Stack do Redis 
echo "Configurando o Redis"
curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/redis.yaml" -o "redis.yaml"
#Executar o Stack do Redis
docker stack deploy --prune --resolve-image always -c redis.yaml redis >> instalacao_n8n_evolution.log 2>&1 && echo "Redis instalado com sucesso!"

#Stack do Evolution API
echo "Configurando a Evolution API com domínio $DOMINIO_EVOLUTION"
sleep 30

# Criar banco de dados para Evolution API
postgres_container_name=$(docker ps --filter "name=postgres_postgres" --format "{{.Names}}")
docker exec $postgres_container_name psql -U postgres -d postgres -c "CREATE DATABASE evolution;" < /dev/null >> instalacao_n8n_evolution.log 2>&1 && echo "Banco Evolution criado com sucesso!"

# Criar stack para Evolution API
cat > evolution.yaml <<EOL
version: '3.7'

services:
  evolution-api:
    image: atendai/evolution-api:v2.0.7
    networks:
      - traefik_proxy
    environment:
      - SERVER_TYPE=http
      - SERVER_PORT=8080
      - CORS_ORIGIN=*
      - CORS_METHODS=POST,GET,PUT,DELETE
      - CORS_CREDENTIALS=true
      - LOG_LEVEL=ERROR
      - LOG_COLOR=true
      - LOG_BAILEYS=error
      - DEL_INSTANCE=false
      - DATABASE_ENABLED=true
      - DATABASE_CONNECTION_URI=postgresql://postgres:${POSTGRES_PASSWORD}@postgres_postgres:5432/evolution
      - DATABASE_CONNECTION_CLIENT_NAME=evolution_db
      - REDIS_ENABLED=true
      - REDIS_URI=redis://redis_redis:6379
      - REDIS_PREFIX_KEY=evolution
      - RABBITMQ_ENABLED=false
      - CACHE_REDIS_ENABLED=true
      - CACHE_REDIS_URI=redis://redis_redis:6379
      - CACHE_REDIS_PREFIX_KEY=evolution
      - CACHE_REDIS_SAVE_INSTANCES=false
      - CACHE_LOCAL_ENABLED=false
      - QRCODE_LIMIT=30
      - AUTHENTICATION_TYPE=apikey
      - AUTHENTICATION_API_KEY=${EVOLUTION_API_KEY}
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
    volumes:
      - evolution_instances:/evolution/instances
      - evolution_store:/evolution/store
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.http.routers.evolution.rule=Host(\`${DOMINIO_EVOLUTION}\`)
        - traefik.http.routers.evolution.tls=true
        - traefik.http.routers.evolution.tls.certresolver=letsencryptresolver
        - traefik.http.services.evolution.loadbalancer.server.port=8080
        - traefik.http.routers.evolution.service=evolution
        - traefik.docker.network=traefik_proxy

volumes:
  evolution_instances:
    external: true
  evolution_store:
    external: true

networks:
  traefik_proxy:
    external: true
EOL

# Criar volumes necessários
docker volume create evolution_instances >> instalacao_n8n_evolution.log 2>&1
docker volume create evolution_store >> instalacao_n8n_evolution.log 2>&1

# Executar stack da Evolution API
env DOMINIO_EVOLUTION="$DOMINIO_EVOLUTION" POSTGRES_PASSWORD="$POSTGRES_PASSWORD" EVOLUTION_API_KEY="$EVOLUTION_API_KEY" docker stack deploy --prune --resolve-image always -c evolution.yaml evolution >> instalacao_n8n_evolution.log 2>&1 && echo "Evolution API instalada com sucesso!"

#Stack do n8n
#Nome do banco
echo "Criando o Banco de Dados do n8n"
sleep 40
postgres_container_name=$(docker ps --filter "name=postgres_postgres" --format "{{.Names}}")
#criar banco
docker exec $postgres_container_name psql -U postgres -d postgres -c "CREATE DATABASE n8n;" < /dev/null >> instalacao_n8n_evolution.log 2>&1 && echo "Banco n8n criado com sucesso!"

echo "Configurando o n8n com domínio $DOMINIO_N8N e webhook $WEBHOOK_N8N"
curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/n8n.yaml" -o "n8n.yaml"
#Executar o Stack do n8n
env DOMINIO_N8N="$DOMINIO_N8N" WEBHOOK_N8N="$WEBHOOK_N8N" POSTGRES_PASSWORD="$POSTGRES_PASSWORD" N8N_KEY="$N8N_KEY" docker stack deploy --prune --resolve-image always -c n8n.yaml n8n >> instalacao_n8n_evolution.log 2>&1 && echo "n8n instalado com sucesso!"

echo ""
echo "========================================"
echo "        INSTALAÇÃO CONCLUÍDA           "
echo "========================================"
echo ""
echo "🔗 URLs de acesso:"
echo "• Portainer: https://$DOMINIO_PORTAINER"
echo "• N8N: https://$DOMINIO_N8N"
echo "• Evolution API: https://$DOMINIO_EVOLUTION"
echo ""
echo "🔑 Credenciais importantes:"
echo "• Evolution API Key: $EVOLUTION_API_KEY"
echo "• Postgres Password: $POSTGRES_PASSWORD"
echo "• N8N Encryption Key: $N8N_KEY"
echo ""
echo "📁 Todas as credenciais foram salvas no arquivo .env"
echo ""
echo "Feche essa janela do terminal e acesse os endereços acima."