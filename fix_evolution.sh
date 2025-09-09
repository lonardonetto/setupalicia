#!/bin/bash

# 🔧 SCRIPT DE RECUPERAÇÃO EVOLUTION API
# Este script irá recriar a stack Evolution API seguindo a sequência correta

echo "🔧 INICIANDO RECUPERAÇÃO DA EVOLUTION API"
echo "======================================================="

# Verificar se estamos no diretório correto
if [ ! -f ".env" ]; then
    echo "❌ Arquivo .env não encontrado!"
    echo "Execute este script no diretório onde foi feita a instalação."
    exit 1
fi

echo "✅ Arquivo .env encontrado"

# Carregar variáveis de ambiente
source .env

echo "📋 PASSO 1: Verificando estado atual..."
echo "Stacks atuais:"
docker stack ls

echo ""
echo "Serviços atuais:"
docker service ls

echo ""
echo "📋 PASSO 2: Verificando dependências..."

# Verificar PostgreSQL
postgres_ready=false
if docker service ps postgres_postgres >/dev/null 2>&1; then
    echo "✅ PostgreSQL stack encontrado"
    postgres_container=$(docker ps --filter "name=postgres_postgres" --format "{{.Names}}")
    if [ ! -z "$postgres_container" ]; then
        if docker exec $postgres_container pg_isready -U postgres >/dev/null 2>&1; then
            echo "✅ PostgreSQL está funcionando"
            postgres_ready=true
        else
            echo "⚠️ PostgreSQL não está respondendo"
        fi
    else
        echo "❌ Container PostgreSQL não encontrado"
    fi
else
    echo "❌ Stack PostgreSQL não encontrado"
fi

# Verificar Redis
redis_ready=false
if docker service ps redis_redis >/dev/null 2>&1; then
    echo "✅ Redis stack encontrado"
    redis_container=$(docker ps --filter "name=redis_redis" --format "{{.Names}}")
    if [ ! -z "$redis_container" ]; then
        if docker exec $redis_container redis-cli ping >/dev/null 2>&1; then
            echo "✅ Redis está funcionando"
            redis_ready=true
        else
            echo "⚠️ Redis não está respondendo"
        fi
    else
        echo "❌ Container Redis não encontrado"
    fi
else
    echo "❌ Stack Redis não encontrado"
fi

if [ "$postgres_ready" = false ] || [ "$redis_ready" = false ]; then
    echo ""
    echo "❌ ERRO: Dependências não estão prontas!"
    echo "PostgreSQL ready: $postgres_ready"
    echo "Redis ready: $redis_ready"
    echo ""
    echo "Execute primeiro:"
    echo "1. Verificar logs: docker service logs postgres_postgres"
    echo "2. Verificar logs: docker service logs redis_redis"
    echo "3. Aguardar serviços estabilizarem"
    exit 1
fi

echo ""
echo "📋 PASSO 3: Removendo stack Evolution antiga (se existir)..."
if docker stack ps evolution >/dev/null 2>&1; then
    echo "Removendo stack evolution existente..."
    docker stack rm evolution
    echo "Aguardando limpeza..."
    sleep 30
    echo "✅ Stack removida"
else
    echo "Nenhuma stack evolution encontrada para remover"
fi

echo ""
echo "📋 PASSO 4: Verificando arquivo de configuração..."
if [ ! -f "evolution.yaml" ]; then
    echo "⚠️ Arquivo evolution.yaml não encontrado. Criando..."
    
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
      - DATABASE_CONNECTION_URI=postgresql://postgres:\${POSTGRES_PASSWORD}@postgres_postgres:5432/evolution?schema=public&sslmode=disable
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
      - AUTHENTICATION_API_KEY=\${EVOLUTION_API_KEY}
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
        - traefik.http.routers.evolution.rule=Host(\`\${DOMINIO_EVOLUTION}\`)
        - traefik.http.routers.evolution.tls=true
        - traefik.http.routers.evolution.tls.certresolver=letsencryptresolver
        - traefik.http.routers.evolution.entrypoints=websecure
        - traefik.http.services.evolution.loadbalancer.server.port=8080
        - traefik.http.routers.evolution.service=evolution
        - traefik.http.routers.evolution-redirect.rule=Host(\`\${DOMINIO_EVOLUTION}\`)
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
    echo "✅ Arquivo evolution.yaml criado"
else
    echo "✅ Arquivo evolution.yaml encontrado"
fi

echo ""
echo "📋 PASSO 5: Verificando volumes..."
# Criar volumes se não existirem
docker volume create evolution_instances >/dev/null 2>&1
docker volume create evolution_store >/dev/null 2>&1
echo "✅ Volumes verificados"

echo ""
echo "📋 PASSO 6: Verificando variáveis obrigatórias..."
if [ -z "$POSTGRES_PASSWORD" ]; then
    echo "❌ POSTGRES_PASSWORD não encontrada no .env"
    exit 1
fi

if [ -z "$EVOLUTION_API_KEY" ]; then
    echo "❌ EVOLUTION_API_KEY não encontrada no .env"
    exit 1
fi

if [ -z "$DOMINIO_EVOLUTION" ]; then
    echo "❌ DOMINIO_EVOLUTION não encontrada no .env"
    exit 1
fi

echo "✅ Todas as variáveis obrigatórias encontradas"
echo "   - POSTGRES_PASSWORD: [CONFIGURADA]"
echo "   - EVOLUTION_API_KEY: [CONFIGURADA]"
echo "   - DOMINIO_EVOLUTION: $DOMINIO_EVOLUTION"

echo ""
echo "📋 PASSO 7: Deployando stack Evolution..."
env DOMINIO_EVOLUTION="$DOMINIO_EVOLUTION" POSTGRES_PASSWORD="$POSTGRES_PASSWORD" EVOLUTION_API_KEY="$EVOLUTION_API_KEY" docker stack deploy --prune --resolve-image always -c evolution.yaml evolution

if [ $? -eq 0 ]; then
    echo "✅ Stack evolution deployada com sucesso!"
else
    echo "❌ Erro ao deployar stack evolution"
    exit 1
fi

echo ""
echo "📋 PASSO 8: Aguardando serviço inicializar..."
echo "Aguardando 30 segundos..."
sleep 30

echo ""
echo "📋 PASSO 9: Verificando resultado..."
echo "Stacks atuais:"
docker stack ls

echo ""
echo "Serviços Evolution:"
docker service ls | grep evolution

echo ""
echo "Status detalhado:"
docker stack ps evolution

echo ""
echo "Últimos logs:"
docker service logs evolution_evolution-api --tail 10

echo ""
echo "======================================================="
echo "✅ RECUPERAÇÃO CONCLUÍDA!"
echo ""
echo "🌐 Verifique o acesso em: https://$DOMINIO_EVOLUTION"
echo "📚 Documentação: https://$DOMINIO_EVOLUTION/manager/docs"
echo ""
echo "🔧 Se ainda houver problemas:"
echo "1. docker service logs evolution_evolution-api --tail 50"
echo "2. docker service update --force evolution_evolution-api"
echo "======================================================="