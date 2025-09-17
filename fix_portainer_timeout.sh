#!/bin/bash

# Script para corrigir timeout do Portainer e criar API Key
# Uso: ./fix_portainer_timeout.sh DOMINIO_PORTAINER

set -e

# Funções de log
log_info() { echo -e "\033[34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[32m[SUCESSO]\033[0m $1"; }
log_warning() { echo -e "\033[33m[AVISO]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERRO]\033[0m $1"; }

DOMINIO_PORTAINER=$1

if [ -z "$DOMINIO_PORTAINER" ]; then
    echo "Uso: $0 DOMINIO_PORTAINER"
    echo "Exemplo: $0 portainer.publiczap.com.br"
    exit 1
fi

echo "🔧 CORREÇÃO AUTOMÁTICA DO TIMEOUT DO PORTAINER"
echo "================================================"

# 1. Verificar se Portainer está com timeout
log_info "🔍 Verificando estado do Portainer..."
TIMEOUT_CHECK=$(curl -s "https://$DOMINIO_PORTAINER" --max-time 10 2>/dev/null || true)

if echo "$TIMEOUT_CHECK" | grep -qi "timed out for security" || echo "$TIMEOUT_CHECK" | grep -qi "timeout"; then
    log_warning "⚠️ TIMEOUT DE SEGURANÇA DETECTADO!"
    
    # 2. Reiniciar Portainer
    log_info "🔄 Reiniciando Portainer..."
    docker service update --force portainer_portainer
    
    # 3. Aguardar reinicialização
    log_info "⏳ Aguardando reinicialização (60 segundos)..."
    sleep 60
    
    # 4. Verificar se voltou
    for i in {1..20}; do
        if curl -s "https://$DOMINIO_PORTAINER/api/status" --max-time 5 >/dev/null 2>&1; then
            log_success "✅ Portainer reiniciado com sucesso!"
            break
        fi
        log_info "   ... aguardando ($i/20)..."
        sleep 10
    done
else
    log_success "✅ Portainer funcionando normalmente!"
fi

# 5. Tentar criar API Key agora
log_info "🔑 Tentando criar API Key..."

# Carregar credenciais do .env
if [ -f .env ]; then
    source .env
    log_info "📋 Credenciais carregadas do .env"
else
    log_error "❌ Arquivo .env não encontrado"
    exit 1
fi

# Fazer login
portainer_url="https://$DOMINIO_PORTAINER"
LOGIN_RESPONSE=$(curl -s -X POST "$portainer_url/api/auth" \
    -H "Content-Type: application/json" \
    -d "{
        \"Username\": \"$PORTAINER_USER\",
        \"Password\": \"$PORTAINER_PASS\"
    }" 2>/dev/null)

if echo "$LOGIN_RESPONSE" | grep -qi "jwt"; then
    JWT_TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"[Jj][Ww][Tt]":"[^"]*' | cut -d'"' -f4)
    log_success "✅ Login realizado com sucesso!"
    
    # Criar API Key
    API_RESPONSE=$(curl -s -X POST "$portainer_url/api/users/1/tokens" \
        -H "Authorization: Bearer $JWT_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"description\": \"setupalicia-fix-$(date +%s)\"
        }" 2>/dev/null)
    
    if echo "$API_RESPONSE" | grep -q "rawAPIKey"; then
        NEW_API_KEY=$(echo "$API_RESPONSE" | grep -o '"rawAPIKey":"[^"]*' | cut -d'"' -f4)
        
        # Atualizar .env
        sed -i "s/PORTAINER_API_KEY=.*/PORTAINER_API_KEY=$NEW_API_KEY/" .env
        
        log_success "🎉 API KEY CRIADA COM SUCESSO!"
        log_success "🔑 Nova API Key: ${NEW_API_KEY:0:20}..."
        log_success "💾 Arquivo .env atualizado"
        
        echo ""
        echo "┌──────────────────────────────────────────────────────────────┐"
        echo "│                    ✅ CORREÇÃO CONCLUÍDA!                     │"
        echo "├──────────────────────────────────────────────────────────────┤"
        echo "│ 🎉 Timeout corrigido e API Key criada                       │"
        echo "│ 🚀 Agora você pode usar stacks editáveis no Portainer       │"
        echo "│ 🌐 Acesse: https://$DOMINIO_PORTAINER                       │"
        echo "│ 🔑 Usuário: $PORTAINER_USER                                 │"
        echo "│ 🔐 Senha: $PORTAINER_PASS                                   │"
        echo "└──────────────────────────────────────────────────────────────┘"
        
    else
        log_error "❌ Falha ao criar API Key: $API_RESPONSE"
    fi
else
    log_error "❌ Falha no login: $LOGIN_RESPONSE"
fi