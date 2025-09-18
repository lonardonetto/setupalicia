#!/bin/bash

# 🔄 MIGRATION TO SETUPALICIA PROFESSIONAL
# Script para migrar instalação existente para versão Professional
# Autor: SetupAlicia - Migration Tool

set -e

# Função para log colorido
log_info() { echo -e "\033[34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[32m[SUCESSO]\033[0m $1"; }
log_warning() { echo -e "\033[33m[AVISO]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERRO]\033[0m $1"; }

clear
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         MIGRAÇÃO PARA SETUPALICIA PROFESSIONAL                ║"
echo "║            De Limited para Full Control                       ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Este script irá:"
echo "  1. Fazer backup dos volumes Docker existentes"
echo "  2. Remover as stacks com controle Limited"
echo "  3. Redeployar via Portainer API com controle Total"
echo "  4. Restaurar os dados dos volumes"
echo ""
echo "⚠️  IMPORTANTE: Certifique-se de ter feito backup dos dados!"
echo ""

read -p "Deseja continuar com a migração? (sim/não): " resposta
if [ "$resposta" != "sim" ]; then
    log_warning "Migração cancelada."
    exit 0
fi

# Verificar se existe arquivo .env
if [ ! -f .env ]; then
    log_error "❌ Arquivo .env não encontrado!"
    echo "Por favor, certifique-se de estar no diretório correto."
    exit 1
fi

# Carregar variáveis
source .env

# Verificar se as credenciais do Portainer existem
if [ -z "$PORTAINER_ADMIN_USER" ] || [ -z "$PORTAINER_ADMIN_PASSWORD" ]; then
    log_error "❌ Credenciais do Portainer não encontradas no .env"
    echo "Por favor, adicione PORTAINER_ADMIN_USER e PORTAINER_ADMIN_PASSWORD ao .env"
    exit 1
fi

# Incluir funções do Stack Manager
if [ ! -f "portainer_stack_manager.sh" ]; then
    log_info "📥 Baixando portainer_stack_manager.sh..."
    curl -sSL https://raw.githubusercontent.com/lonardonetto/setupalicia/main/portainer_stack_manager.sh -o portainer_stack_manager.sh
fi
source portainer_stack_manager.sh

# Criar diretório de backup se não existir
BACKUP_DIR="./backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR
log_info "📁 Diretório de backup: $BACKUP_DIR"

# Função para fazer backup de volume
backup_volume() {
    local volume_name=$1
    local backup_file="$BACKUP_DIR/${volume_name}.tar.gz"
    
    if docker volume inspect $volume_name >/dev/null 2>&1; then
        log_info "💾 Fazendo backup do volume $volume_name..."
        docker run --rm \
            -v $volume_name:/data \
            -v $(pwd)/$BACKUP_DIR:/backup \
            alpine tar czf /backup/${volume_name}.tar.gz -C /data .
        
        if [ -f "$backup_file" ]; then
            log_success "✅ Backup salvo: $backup_file"
        else
            log_warning "⚠️ Falha no backup de $volume_name"
        fi
    else
        log_warning "⚠️ Volume $volume_name não existe"
    fi
}

# Função para restaurar volume
restore_volume() {
    local volume_name=$1
    local backup_file="$BACKUP_DIR/${volume_name}.tar.gz"
    
    if [ -f "$backup_file" ]; then
        log_info "📥 Restaurando volume $volume_name..."
        
        # Criar volume se não existir
        docker volume create $volume_name >/dev/null 2>&1
        
        # Restaurar dados
        docker run --rm \
            -v $volume_name:/data \
            -v $(pwd)/$BACKUP_DIR:/backup \
            alpine tar xzf /backup/${volume_name}.tar.gz -C /data
        
        log_success "✅ Volume $volume_name restaurado"
    else
        log_warning "⚠️ Arquivo de backup não encontrado: $backup_file"
    fi
}

# 1. FAZER BACKUP DOS VOLUMES
echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│                  ETAPA 1: BACKUP DOS DADOS                    │"
echo "└──────────────────────────────────────────────────────────────┘"

# Lista de volumes para backup
VOLUMES=(
    "postgres_data"
    "redis_data"
    "evolution_instances"
    "evolution_store"
    "n8n_data"
)

for volume in "${VOLUMES[@]}"; do
    backup_volume $volume
done

echo ""
echo "✅ Backup concluído!"
echo ""

# 2. CONECTAR AO PORTAINER
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│              ETAPA 2: CONECTANDO AO PORTAINER                 │"
echo "└──────────────────────────────────────────────────────────────┘"

# Determinar URL do Portainer
if [ ! -z "$PORTAINER_URL" ]; then
    PORTAINER_URL_FINAL=$PORTAINER_URL
else
    PORTAINER_URL_FINAL="https://$DOMINIO_PORTAINER"
fi

log_info "🔑 Fazendo login no Portainer..."

# Fazer login
JWT_TOKEN=$(portainer_login "$PORTAINER_URL_FINAL" "$PORTAINER_ADMIN_USER" "$PORTAINER_ADMIN_PASSWORD")
if [ -z "$JWT_TOKEN" ]; then
    log_error "❌ Falha ao autenticar no Portainer"
    exit 1
fi

# Obter endpoint ID
ENDPOINT_ID=$(get_swarm_endpoint_id "$PORTAINER_URL_FINAL" "$JWT_TOKEN")
if [ -z "$ENDPOINT_ID" ]; then
    log_error "❌ Falha ao obter endpoint ID"
    exit 1
fi

log_success "✅ Conectado ao Portainer!"

# 3. REMOVER STACKS ANTIGAS
echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│            ETAPA 3: REMOVENDO STACKS LIMITED                  │"
echo "└──────────────────────────────────────────────────────────────┘"

# Lista de stacks para remover (exceto traefik e portainer)
STACKS_TO_REMOVE=(
    "postgres"
    "redis"
    "evolution"
    "n8n"
)

for stack in "${STACKS_TO_REMOVE[@]}"; do
    if docker stack ls | grep -q "$stack"; then
        log_info "🗑️ Removendo stack $stack..."
        docker stack rm $stack
        
        # Aguardar remoção
        sleep 10
        
        # Aguardar containers pararem
        while docker ps | grep -q "${stack}_"; do
            echo -n "."
            sleep 2
        done
        
        log_success "✅ Stack $stack removida"
    fi
done

echo ""
log_info "⏳ Aguardando limpeza completa..."
sleep 20

# 4. REDEPLOYAR VIA PORTAINER API
echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│         ETAPA 4: REDEPLOY COM CONTROLE TOTAL                  │"
echo "└──────────────────────────────────────────────────────────────┘"

# Deploy PostgreSQL
log_info "📦 Deployando PostgreSQL via Portainer API..."
deploy_postgres_via_portainer "$PORTAINER_URL_FINAL" "$JWT_TOKEN" "$ENDPOINT_ID" "$POSTGRES_PASSWORD"
sleep 20

# Deploy Redis
log_info "📦 Deployando Redis via Portainer API..."
deploy_redis_via_portainer "$PORTAINER_URL_FINAL" "$JWT_TOKEN" "$ENDPOINT_ID"
sleep 15

# Aguardar serviços estabilizarem
log_info "⏳ Aguardando serviços estabilizarem..."
sleep 30

# Deploy Evolution API
log_info "📦 Deployando Evolution API via Portainer API..."
deploy_evolution_via_portainer "$PORTAINER_URL_FINAL" "$JWT_TOKEN" "$ENDPOINT_ID" \
    "$DOMINIO_EVOLUTION" "$EVOLUTION_API_KEY" "$POSTGRES_PASSWORD"
sleep 20

# Deploy N8N
log_info "📦 Deployando N8N via Portainer API..."
deploy_n8n_via_portainer "$PORTAINER_URL_FINAL" "$JWT_TOKEN" "$ENDPOINT_ID" \
    "$DOMINIO_N8N" "$WEBHOOK_N8N" "$N8N_KEY" "$POSTGRES_PASSWORD"

log_success "✅ Todas as stacks redeployadas com controle total!"

# 5. VERIFICAR STATUS
echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│                 ETAPA 5: VERIFICAÇÃO FINAL                    │"
echo "└──────────────────────────────────────────────────────────────┘"

log_info "📊 Verificando stacks no Portainer..."

# Verificar stacks via API
echo ""
curl -s -X GET \
    "$PORTAINER_URL_FINAL/api/stacks" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    --insecure 2>/dev/null | jq -r '.[] | "Stack: \(.Name) - Status: Full Control"' || echo "Verifique manualmente no Portainer"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║            🎉 MIGRAÇÃO CONCLUÍDA COM SUCESSO!                 ║"
echo "║               AGORA COM CONTROLE TOTAL                        ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "✅ Benefícios da migração:"
echo "   • Controle TOTAL de todas as stacks"
echo "   • Possibilidade de editar configurações"
echo "   • Logs completos disponíveis"
echo "   • Backup e migração facilitados"
echo "   • Scaling dinâmico habilitado"
echo ""
echo "📁 Backup salvo em: $BACKUP_DIR"
echo "🌐 Acesse o Portainer: $PORTAINER_URL_FINAL"
echo ""
echo "⚠️  IMPORTANTE: Verifique se todos os serviços estão funcionando!"
echo ""
echo "Comandos úteis:"
echo "  docker service ls        # Ver serviços"
echo "  docker stack ls          # Ver stacks"
echo "  docker ps               # Ver containers"
echo ""

# Salvar informações de migração
echo "# Migração realizada em $(date)" >> .env
echo "MIGRATION_DATE=$(date +%Y%m%d_%H%M%S)" >> .env
echo "MIGRATION_BACKUP_DIR=$BACKUP_DIR" >> .env
echo "PORTAINER_JWT_TOKEN=$JWT_TOKEN" >> .env
echo "PORTAINER_ENDPOINT_ID=$ENDPOINT_ID" >> .env

log_success "🎉 SetupAlicia Professional - Migração concluída!"
