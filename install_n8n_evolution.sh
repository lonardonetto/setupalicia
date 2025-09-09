#!/bin/bash

# Instalador do N8N + Evolution API em Docker Swarm
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

echo "🔑 Variáveis de ambiente configuradas:"
echo "   • SSL Email: $SSL_EMAIL"
echo "   • Domínio N8N: $DOMINIO_N8N"
echo "   • Domínio Evolution: $DOMINIO_EVOLUTION"
echo "   • Domínio Portainer: $DOMINIO_PORTAINER"
echo "   • Webhook N8N: $WEBHOOK_N8N"
echo "   • PostgreSQL Password: [CONFIGURADA]"
echo "   • Evolution API Key: [CONFIGURADA]"
echo "   • N8N Key: [CONFIGURADA]"
echo ""

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
} >> instalacao_n8n.log 2>&1 &
wait

echo "Lista de Pacotes atualizados"
while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
    sleep 10
done

echo "Alocando um arquivo de swap "
# Aloca um arquivo de swap
sudo fallocate -l 4G /swapfile >> instalacao_n8n.log 2>&1
sudo chmod 600 /swapfile >> instalacao_n8n.log 2>&1
sudo mkswap /swapfile >> instalacao_n8n.log 2>&1
sudo swapon /swapfile >> instalacao_n8n.log 2>&1
sudo cp /etc/fstab /etc/fstab.bak >> instalacao_n8n.log 2>&1
echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab >> instalacao_n8n.log 2>&1
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
curl -fsSL https://get.docker.com | bash >> instalacao_n8n.log 2>&1 && echo "Docker instalado com sucesso!"

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
docker swarm init --advertise-addr $endereco_ip >> instalacao_n8n.log 2>&1 && echo "Docker Swarm iniciado"
# Configurar a rede do Docker Swarm
docker network create --driver=overlay network_public >> instalacao_n8n.log 2>&1 && echo "Rede Swarm Criada com sucesso!"

#Stack do Traefik 
echo "Configurando o Traefik com o e-mail $SSL_EMAIL"
curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/traefik.yaml" -o "traefik.yaml"
#Executar o Stack do Traefik
env SSL_EMAIL="$SSL_EMAIL" docker stack deploy --prune --resolve-image always -c traefik.yaml traefik >> instalacao_n8n.log 2>&1 && echo "Traefik instalado com sucesso!"

#Stack do Portainer 
echo "Configurando o Portainer com o domínio $DOMINIO_PORTAINER"
curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/portainer.yaml" -o "portainer.yaml"
env DOMINIO_PORTAINER="$DOMINIO_PORTAINER" docker stack deploy --prune --resolve-image always -c portainer.yaml portainer >> instalacao_n8n.log 2>&1 && echo "Portainer instalado com sucesso!"

#Stack do Postgres
echo "Configurando o Banco de Dados Postgres"
curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/postgres.yaml" -o "postgres.yaml"
#Executar o Stack do Postgres
env POSTGRES_PASSWORD="$POSTGRES_PASSWORD" docker stack deploy --prune --resolve-image always -c postgres.yaml postgres >> instalacao_n8n.log 2>&1 && echo "Postgress instalado com sucesso!"

#Stack do Redis 
echo "Configurando o Redis"
curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/redis.yaml" -o "redis.yaml"
#Executar o Stack do Redis
docker stack deploy --prune --resolve-image always -c redis.yaml redis >> instalacao_n8n.log 2>&1 && echo "Redis instalado com sucesso!"

#Stack do Evolution API
echo "Aguardando PostgreSQL e Redis ficarem disponíveis..."
sleep 90

# Verificar se PostgreSQL está funcionando e criar banco de dados
echo "Testando conexão com PostgreSQL e criando banco de dados..."
for i in {1..60}; do
    postgres_container_name=$(docker ps --filter "name=postgres_postgres" --format "{{.Names}}")
    if [ ! -z "$postgres_container_name" ]; then
        if docker exec $postgres_container_name pg_isready -U postgres > /dev/null 2>&1; then
            echo "PostgreSQL está funcionando!"
            # Criar banco de dados da Evolution API
            docker exec $postgres_container_name psql -U postgres -d postgres -c "CREATE DATABASE evolution;" < /dev/null >> instalacao_n8n.log 2>&1 && echo "Banco Evolution criado com sucesso!"
            break
        fi
    fi
    echo "Aguardando PostgreSQL... ($i/60)"
    sleep 3
done

# Verificar se Redis está funcionando
echo "Testando conexão com Redis..."
for i in {1..30}; do
    redis_container_name=$(docker ps --filter "name=redis_redis" --format "{{.Names}}")
    if [ ! -z "$redis_container_name" ]; then
        if docker exec $redis_container_name redis-cli ping > /dev/null 2>&1; then
            echo "Redis está funcionando!"
            break
        fi
    fi
    echo "Aguardando Redis... ($i/30)"
    sleep 2
done

echo "Configurando a Evolution API com domínio $DOMINIO_EVOLUTION"
curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/evolution.yaml" -o "evolution.yaml"

# Se não conseguir baixar o arquivo, criar um local
if [ ! -f "evolution.yaml" ]; then
    echo "Criando arquivo evolution.yaml local..."
    cat > evolution.yaml <<EOL
version: '3.7'

services:
  evolution-api:
    image: atendai/evolution-api:v2.2.3
    networks:
      - network_public
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
      - DATABASE_PROVIDER=postgresql
      - DATABASE_CONNECTION_URI=postgresql://postgres:${POSTGRES_PASSWORD}@postgres_postgres:5432/evolution?schema=public&sslmode=disable
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
        condition: on-failure
        delay: 5s
        max_attempts: 3
        window: 120s
      labels:
        - traefik.enable=true
        - traefik.http.routers.evolution.rule=Host(\`${DOMINIO_EVOLUTION}\`)
        - traefik.http.routers.evolution.tls=true
        - traefik.http.routers.evolution.tls.certresolver=letsencryptresolver
        - traefik.http.routers.evolution.entrypoints=websecure
        - traefik.http.services.evolution.loadbalancer.server.port=8080
        - traefik.http.routers.evolution.service=evolution
        - traefik.http.routers.evolution-redirect.rule=Host(\`${DOMINIO_EVOLUTION}\`)
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
EOL
fi

# Criar volumes se não existirem
docker volume create evolution_instances >> instalacao_n8n.log 2>&1
docker volume create evolution_store >> instalacao_n8n.log 2>&1

# Aguardar mais um pouco antes de fazer deploy da Evolution API
echo "Aguardando serviços estabilizarem antes de instalar Evolution API..."
sleep 30

# Executar stack da Evolution API
env DOMINIO_EVOLUTION="$DOMINIO_EVOLUTION" POSTGRES_PASSWORD="$POSTGRES_PASSWORD" EVOLUTION_API_KEY="$EVOLUTION_API_KEY" docker stack deploy --prune --resolve-image always -c evolution.yaml evolution >> instalacao_n8n.log 2>&1 && echo "Evolution API instalada com sucesso!"

#Stack do n8n
echo "Configurando o n8n com domínio $DOMINIO_N8N e webhook $WEBHOOK_N8N"
echo "Aguardando PostgreSQL para criar banco do N8N..."
sleep 20

# Verificar novamente se PostgreSQL está funcionando e criar banco do N8N
for i in {1..30}; do
    postgres_container_name=$(docker ps --filter "name=postgres_postgres" --format "{{.Names}}")
    if [ ! -z "$postgres_container_name" ]; then
        if docker exec $postgres_container_name pg_isready -U postgres > /dev/null 2>&1; then
            echo "PostgreSQL está funcionando para N8N!"
            # Criar banco de dados do N8N (se ainda não existe)
            docker exec $postgres_container_name psql -U postgres -d postgres -c "CREATE DATABASE n8n;" < /dev/null >> instalacao_n8n.log 2>&1 && echo "Banco n8n criado com sucesso!"
            break
        fi
    fi
    echo "Aguardando PostgreSQL para N8N... ($i/30)"
    sleep 2
done

curl -sSL "https://instalador.automacaosemlimites.com.br/arquivos/instalador/stack/n8n.yaml" -o "n8n.yaml"
#Executar o Stack do n8n
env DOMINIO_N8N="$DOMINIO_N8N" WEBHOOK_N8N="$WEBHOOK_N8N" POSTGRES_PASSWORD="$POSTGRES_PASSWORD" N8N_KEY="$N8N_KEY" docker stack deploy --prune --resolve-image always -c n8n.yaml n8n >> instalacao_n8n.log 2>&1 && echo "n8n instalado com sucesso!"

echo "Instalação concluída"

# Verificar status dos serviços
echo ""
echo "======================================================="
echo "           VERIFICANDO STATUS DOS SERVIÇOS            "
echo "======================================================="
echo ""

# Aguardar serviços iniciarem
echo "⏳ Aguardando serviços iniciarem completamente..."
sleep 60

# Verificar PostgreSQL
echo "🔍 Verificando PostgreSQL..."
postgres_container=$(docker ps --filter "name=postgres_postgres" --format "{{.Names}}")
if [ ! -z "$postgres_container" ]; then
    if docker exec $postgres_container pg_isready -U postgres > /dev/null 2>&1; then
        echo "✅ PostgreSQL: FUNCIONANDO"
    else
        echo "❌ PostgreSQL: COM PROBLEMAS"
    fi
else
    echo "❌ PostgreSQL: CONTAINER NÃO ENCONTRADO"
fi

# Verificar Redis
echo "🔍 Verificando Redis..."
redis_container=$(docker ps --filter "name=redis_redis" --format "{{.Names}}")
if [ ! -z "$redis_container" ]; then
    if docker exec $redis_container redis-cli ping > /dev/null 2>&1; then
        echo "✅ Redis: FUNCIONANDO"
    else
        echo "❌ Redis: COM PROBLEMAS"
    fi
else
    echo "❌ Redis: CONTAINER NÃO ENCONTRADO"
fi

# Verificar Evolution API
echo "🔍 Verificando Evolution API..."
evolution_container=$(docker ps --filter "name=evolution_evolution-api" --format "{{.Names}}")
if [ ! -z "$evolution_container" ]; then
    echo "✅ Evolution API: CONTAINER EXECUTANDO"
else
    echo "❌ Evolution API: CONTAINER NÃO ENCONTRADO"
fi

# Verificar N8N
echo "🔍 Verificando N8N..."
n8n_container=$(docker ps --filter "name=n8n" --format "{{.Names}}")
if [ ! -z "$n8n_container" ]; then
    echo "✅ N8N: CONTAINER EXECUTANDO"
else
    echo "❌ N8N: CONTAINER NÃO ENCONTRADO"
fi

echo ""

echo "======================================================="
echo "           INSTALAÇÃO CONCLUÍDA COM SUCESSO!           "
echo "======================================================="
echo ""
echo "🌐 URLs DE ACESSO:"
echo "   • Portainer: https://$DOMINIO_PORTAINER"
echo "   • N8N: https://$DOMINIO_N8N"
echo "   • Evolution API: https://$DOMINIO_EVOLUTION"
echo "   • Webhook N8N: https://$WEBHOOK_N8N"
echo ""
echo "🔑 CREDENCIAIS IMPORTANTES:"
echo "   • Evolution API Key: $EVOLUTION_API_KEY"
echo "   • PostgreSQL Password: $POSTGRES_PASSWORD"
echo "   • N8N Encryption Key: $N8N_KEY"
echo ""
echo "📁 ARQUIVO DE CONFIGURAÇÃO:"
echo "   Todas as credenciais foram salvas em: .env"
echo ""
echo "🚀 DOCUMENTAÇÃO EVOLUTION API:"
echo "   • Endpoint base: https://$DOMINIO_EVOLUTION"
echo "   • Swagger/Docs: https://$DOMINIO_EVOLUTION/manager/docs"
echo "   • Header de autenticação: apikey: $EVOLUTION_API_KEY"
echo ""
echo "🔧 COMANDOS ÚTEIS:"
echo "   • Ver logs dos containers: docker service logs [nome-do-serviço]"
echo "   • Verificar status: docker stack ps [nome-da-stack]"
echo "   • Reiniciar serviço: docker service update --force [nome-do-serviço]"
echo ""
echo "⚠️ IMPORTANTE:"
echo "   • Aguarde 2-3 minutos para todos os serviços iniciarem completamente"
echo "   • Se Evolution API não funcionar, verifique os logs: docker service logs evolution_evolution-api"
echo "   • Se houver erro de SSL, aguarde alguns minutos para certificados serem gerados"
echo ""
echo "======================================================="
echo "  GUARDE ESSAS INFORMAÇÕES EM LOCAL SEGURO!"
echo "======================================================="
echo ""
echo "Feche essa janela do terminal e acesse os endereços acima."