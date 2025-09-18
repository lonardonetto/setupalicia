#!/bin/bash

# Função para criar conta admin do Portainer automaticamente
create_portainer_admin() {
    local DOMINIO_PORTAINER=$1
    local ADMIN_USERNAME=${2:-"admin"}
    local ADMIN_PASSWORD=${3:-$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-24)}
    
    log_info "🔑 Configurando conta admin do Portainer automaticamente..."
    
    # Aguardar Portainer estar acessível
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s "https://$DOMINIO_PORTAINER/api/status" --insecure >/dev/null 2>&1; then
            log_success "✅ Portainer está acessível!"
            break
        fi
        
        # Tentar também via HTTP caso SSL ainda não esteja pronto
        if curl -s "http://$DOMINIO_PORTAINER/api/status" >/dev/null 2>&1; then
            log_warning "⚠️ Portainer acessível via HTTP (SSL pendente)"
            PORTAINER_URL="http://$DOMINIO_PORTAINER"
            break
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 2
    done
    
    if [ $attempt -eq $max_attempts ]; then
        log_error "❌ Timeout aguardando Portainer ficar acessível"
        return 1
    fi
    
    # Determinar URL do Portainer (HTTPS preferencial)
    if [ -z "$PORTAINER_URL" ]; then
        PORTAINER_URL="https://$DOMINIO_PORTAINER"
    fi
    
    # Verificar se já foi inicializado
    local init_status=$(curl -s "$PORTAINER_URL/api/users/admin/check" --insecure 2>/dev/null)
    
    if echo "$init_status" | grep -q "true"; then
        log_warning "⚠️ Portainer já foi inicializado. Admin já existe."
        return 0
    fi
    
    # Criar usuário admin via API
    log_info "📝 Criando usuário admin: $ADMIN_USERNAME"
    
    local response=$(curl -s -X POST \
        "$PORTAINER_URL/api/users/admin/init" \
        -H "Content-Type: application/json" \
        --insecure \
        -d "{
            \"Username\": \"$ADMIN_USERNAME\",
            \"Password\": \"$ADMIN_PASSWORD\"
        }" 2>/dev/null)
    
    # Verificar se a criação foi bem-sucedida
    if echo "$response" | grep -q "Username"; then
        log_success "✅ Conta admin criada com sucesso!"
        
        # Salvar credenciais no arquivo .env
        echo "" >> .env
        echo "# Portainer Admin Credentials (Auto-generated)" >> .env
        echo "PORTAINER_ADMIN_USER=$ADMIN_USERNAME" >> .env
        echo "PORTAINER_ADMIN_PASSWORD=$ADMIN_PASSWORD" >> .env
        
        # Exibir credenciais
        echo ""
        echo "┌──────────────────────────────────────────────────────────────┐"
        echo "│             🔐 CREDENCIAIS PORTAINER (GUARDE!)                │"
        echo "├──────────────────────────────────────────────────────────────┤"
        echo "│ 👤 Usuário: $ADMIN_USERNAME"
        echo "│ 🔑 Senha: $ADMIN_PASSWORD"
        echo "│ 🌐 URL: $PORTAINER_URL"
        echo "└──────────────────────────────────────────────────────────────┘"
        echo ""
        
        return 0
    else
        log_error "❌ Falha ao criar conta admin"
        echo "Resposta: $response"
        return 1
    fi
}

# Função auxiliar para fazer login e obter token JWT (para operações futuras)
portainer_login() {
    local DOMINIO_PORTAINER=$1
    local USERNAME=$2
    local PASSWORD=$3
    
    local PORTAINER_URL="https://$DOMINIO_PORTAINER"
    
    # Tentar HTTPS primeiro, depois HTTP
    local response=$(curl -s -X POST \
        "$PORTAINER_URL/api/auth" \
        -H "Content-Type: application/json" \
        --insecure \
        -d "{
            \"Username\": \"$USERNAME\",
            \"Password\": \"$PASSWORD\"
        }" 2>/dev/null)
    
    # Extrair token JWT
    local jwt_token=$(echo "$response" | grep -oP '"jwt":"[^"]*' | cut -d'"' -f4)
    
    if [ ! -z "$jwt_token" ]; then
        echo "$jwt_token"
        return 0
    else
        return 1
    fi
}

# Função para configurar endpoints automaticamente
configure_portainer_endpoints() {
    local DOMINIO_PORTAINER=$1
    local JWT_TOKEN=$2
    
    local PORTAINER_URL="https://$DOMINIO_PORTAINER"
    
    log_info "⚙️ Configurando endpoints do Docker..."
    
    # Criar endpoint local
    local response=$(curl -s -X POST \
        "$PORTAINER_URL/api/endpoints" \
        -H "Authorization: Bearer $JWT_TOKEN" \
        -H "Content-Type: application/json" \
        --insecure \
        -d '{
            "Name": "local",
            "EndpointCreationType": 1,
            "URL": "unix:///var/run/docker.sock"
        }' 2>/dev/null)
    
    if echo "$response" | grep -q "Id"; then
        log_success "✅ Endpoint Docker local configurado!"
        return 0
    else
        log_warning "⚠️ Endpoint pode já estar configurado"
        return 1
    fi
}

# Exemplo de uso integrado
setup_portainer_complete() {
    local DOMINIO_PORTAINER=$1
    local ADMIN_USER=${2:-"admin"}
    local ADMIN_PASSWORD=${3:-$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-24)}
    
    # Criar conta admin
    if create_portainer_admin "$DOMINIO_PORTAINER" "$ADMIN_USER" "$ADMIN_PASSWORD"; then
        
        # Fazer login para obter token
        local jwt_token=$(portainer_login "$DOMINIO_PORTAINER" "$ADMIN_USER" "$ADMIN_PASSWORD")
        
        if [ ! -z "$jwt_token" ]; then
            log_success "✅ Login realizado com sucesso!"
            
            # Configurar endpoints (opcional)
            configure_portainer_endpoints "$DOMINIO_PORTAINER" "$jwt_token"
        fi
    fi
}
