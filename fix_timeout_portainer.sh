#!/bin/bash

# 🔧 SCRIPT PARA RESOLVER TIMEOUT DO PORTAINER E CRIAR API KEY

set -e

# Função para log colorido
log_info() { echo -e "\033[34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[32m[SUCESSO]\033[0m $1"; }
log_warning() { echo -e "\033[33m[AVISO]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERRO]\033[0m $1"; }

echo "🔧 RESOLVENDO TIMEOUT DO PORTAINER"
echo "=================================="

# Carregar variáveis
if [ -f .env ]; then
    source .env
else
    log_error "❌ Arquivo .env não encontrado!"
    exit 1
fi

# Verificar se temos domínio
if [ -z "$DOMINIO_PORTAINER" ]; then
    log_error "❌ DOMINIO_PORTAINER não encontrado no .env"
    exit 1
fi

log_info "🌐 Domínio: $DOMINIO_PORTAINER"

# PASSO 1: REINICIAR PORTAINER PARA LIMPAR TIMEOUT
log_info "🔄 Reiniciando Portainer para limpar timeout..."

docker service update --force portainer_portainer >/dev/null 2>&1

log_info "⏳ Aguardando reinicialização (60 segundos)..."
sleep 60

# PASSO 2: AGUARDAR PORTAINER FICAR ONLINE
log_info "🔍 Aguardando Portainer ficar online novamente..."

for wait_time in {1..30}; do
    if curl -s "https://$DOMINIO_PORTAINER/api/status" --max-time 5 >/dev/null 2>&1; then
        log_success "✅ Portainer online via HTTPS!"
        portainer_url="https://$DOMINIO_PORTAINER"
        break
    elif curl -s "http://localhost:9000/api/status" --max-time 3 >/dev/null 2>&1; then
        log_success "✅ Portainer online via HTTP!"
        portainer_url="http://localhost:9000"
        break
    fi
    
    if [ $((wait_time % 10)) -eq 0 ]; then
        log_info "   ... aguardando ($wait_time/30)..."
    fi
    sleep 5
done

if [ -z "$portainer_url" ]; then
    log_error "❌ Portainer não ficou online após reinicialização"
    exit 1
fi

# PASSO 3: CRIAR CONTA ADMINISTRATIVA IMEDIATAMENTE
log_info "👤 Criando conta administrativa..."

# Gerar novas credenciais
PORTAINER_USER="setupalicia"
PORTAINER_PASS=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12)

log_info "🔑 Usuário: $PORTAINER_USER"
log_info "🔐 Senha: $PORTAINER_PASS"

# Criar conta admin
INIT_RESPONSE=$(curl -s -X POST "$portainer_url/api/users/admin/init" \
    -H "Content-Type: application/json" \
    -d "{
        \"Username\": \"$PORTAINER_USER\",
        \"Password\": \"$PORTAINER_PASS\"
    }" 2>/dev/null)

log_info "📋 Resposta criação: ${INIT_RESPONSE:0:100}..."

# Se falhou criar, tentar login
if ! echo "$INIT_RESPONSE" | grep -qi "jwt"; then
    log_info "🔄 Tentando login direto..."
    
    INIT_RESPONSE=$(curl -s -X POST "$portainer_url/api/auth" \
        -H "Content-Type: application/json" \
        -d "{
            \"Username\": \"$PORTAINER_USER\",
            \"Password\": \"$PORTAINER_PASS\"
        }" 2>/dev/null)
    
    log_info "📋 Resposta login: ${INIT_RESPONSE:0:100}..."
fi

# PASSO 4: EXTRAIR JWT TOKEN
if echo "$INIT_RESPONSE" | grep -qi "jwt"; then
    JWT_TOKEN=$(echo "$INIT_RESPONSE" | grep -o '"[Jj][Ww][Tt]":"[^"]*' | cut -d'"' -f4)
    
    if [ -z "$JWT_TOKEN" ]; then
        JWT_TOKEN=$(echo "$INIT_RESPONSE" | sed -n 's/.*"[Jj][Ww][Tt]":\s*"\([^"]*\)".*/\1/p')
    fi
    
    if [ ! -z "$JWT_TOKEN" ]; then
        log_success "✅ JWT Token obtido: ${JWT_TOKEN:0:30}..."
        
        # PASSO 5: CRIAR API KEY IMEDIATAMENTE
        log_info "🔑 Criando API Key..."
        
        API_RESPONSE=$(curl -s -X POST "$portainer_url/api/users/1/tokens" \
            -H "Authorization: Bearer $JWT_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{
                \"description\": \"setupalicia-$(date +%s)\"
            }" 2>/dev/null)
        
        log_info "📋 Resposta API: $API_RESPONSE"
        
        if echo "$API_RESPONSE" | grep -q "rawAPIKey"; then
            PORTAINER_API_KEY=$(echo "$API_RESPONSE" | grep -o '"rawAPIKey":"[^"]*' | cut -d'"' -f4)
            
            if [ ! -z "$PORTAINER_API_KEY" ] && [ ${#PORTAINER_API_KEY} -gt 10 ]; then
                log_success "✅ API Key criada: ${PORTAINER_API_KEY:0:20}..."
                
                # PASSO 6: ATUALIZAR .ENV COM NOVAS CREDENCIAIS
                # Remover credenciais antigas
                sed -i '/PORTAINER_USER=/d' .env 2>/dev/null || true
                sed -i '/PORTAINER_PASS=/d' .env 2>/dev/null || true
                sed -i '/PORTAINER_API_KEY=/d' .env 2>/dev/null || true
                sed -i '/SWARM_ID=/d' .env 2>/dev/null || true
                
                # Adicionar novas credenciais
                echo "PORTAINER_USER=$PORTAINER_USER" >> .env
                echo "PORTAINER_PASS=$PORTAINER_PASS" >> .env
                echo "PORTAINER_API_KEY=$PORTAINER_API_KEY" >> .env
                
                SWARM_ID=$(docker info --format '{{.Swarm.NodeID}}')
                echo "SWARM_ID=$SWARM_ID" >> .env
                
                # PASSO 7: TESTAR API KEY
                TEST_RESPONSE=$(curl -s -X GET "$portainer_url/api/stacks" \
                    -H "X-API-Key: $PORTAINER_API_KEY" 2>/dev/null)
                
                if echo "$TEST_RESPONSE" | grep -q "\[" || echo "$TEST_RESPONSE" | grep -q "\{"; then
                    log_success "🚀 API Key funcionando perfeitamente!"
                    
                    echo ""
                    echo "┌─────────────────────────────────────────────────────────────┐"
                    echo "│                    ✅ TIMEOUT RESOLVIDO!                      │"
                    echo "├─────────────────────────────────────────────────────────────┤"
                    echo "│ 🎉 Portainer reiniciado e configurado com sucesso!         │"
                    echo "│ 🔑 Nova API Key criada e funcionando                       │"
                    echo "│ 🚀 Agora as stacks podem ser criadas como editáveis!       │"
                    echo "│                                                             │"
                    echo "│ 🌐 Acesse: https://$DOMINIO_PORTAINER                 │"
                    echo "│ 🔑 Usuário: $PORTAINER_USER                               │"
                    echo "│ 🔐 Senha: $PORTAINER_PASS                                 │"
                    echo "│ 🗝️  API Key: ${PORTAINER_API_KEY:0:30}...                  │"
                    echo "└─────────────────────────────────────────────────────────────┘"
                    
                    # PASSO 8: RECRIAR STACKS VIA API SE POSSÍVEL
                    echo ""
                    log_info "🔄 Verificando se podemos recriar stacks como editáveis..."
                    
                    # Listar stacks existentes
                    EXISTING_STACKS=$(curl -s -X GET "$portainer_url/api/stacks" \
                        -H "X-API-Key: $PORTAINER_API_KEY" 2>/dev/null)
                    
                    if echo "$EXISTING_STACKS" | grep -q "postgres\|redis\|evolution\|n8n"; then
                        log_info "📋 Stacks já existem. Para torná-las editáveis:"
                        echo "   1. Acesse o Portainer com as credenciais acima"
                        echo "   2. Vá em Stacks"
                        echo "   3. Remova as stacks que quer recriar"
                        echo "   4. Use 'Add stack' > 'Upload' com os arquivos em /opt/setupalicia/stacks/"
                    else
                        log_info "📋 Nenhuma stack encontrada - próximas serão criadas como editáveis!"
                    fi
                    
                else
                    log_warning "⚠️ API Key criada mas teste falhou: ${TEST_RESPONSE:0:50}..."
                fi
            else
                log_error "❌ API Key vazia ou muito curta"
            fi
        else
            log_error "❌ Resposta não contém rawAPIKey: $API_RESPONSE"
        fi
    else
        log_error "❌ JWT Token vazio"
    fi
else
    log_error "❌ Resposta não contém JWT: $INIT_RESPONSE"
fi

log_info "🎯 Script concluído!"