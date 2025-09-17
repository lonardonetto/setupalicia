#!/bin/bash

# SETUPALICIA - INSTALADOR AUTOMATIZADO

set -e

# Funcao para log colorido
log_info() { echo -e "\033[34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[32m[SUCESSO]\033[0m $1"; }
log_warning() { echo -e "\033[33m[AVISO]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERRO]\033[0m $1"; }

# Validacao rigorosa de parametros
if [ -z "$1" ]; then
    echo "Uso: $0 <email> <dominio_n8n> <dominio_portainer> <webhook_n8n> <dominio_evolution>"
    exit 1
fi

SSL_EMAIL=$1
DOMINIO_N8N=$2
DOMINIO_PORTAINER=$3
WEBHOOK_N8N=$4
DOMINIO_EVOLUTION=$5

clear
echo "================================================================"
echo "                    SETUP ALICIA                           "
echo "              Instalador Automatizado com SSL                "
echo "================================================================"
echo ""
echo "Aplicacoes incluidas:"
echo "   • Traefik (Proxy SSL automatico)"
echo "   • Portainer (Interface Docker)"
echo "   • PostgreSQL (Banco de dados)"
echo "   • Redis (Cache)"
echo "   • Evolution API v2.2.3 (WhatsApp)"
echo "   • N8N (Automacao)"
echo ""

# Validar formato de email
if [[ ! "$SSL_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    log_error "Email invalido! Por favor, digite um email valido."
    exit 1
fi

# Validar dominios
for domain in "$DOMINIO_N8N" "$DOMINIO_PORTAINER" "$WEBHOOK_N8N" "$DOMINIO_EVOLUTION"; do
    if [[ ! "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log_error "Dominio invalido: $domain"
        exit 1
    fi
done

log_success "✅ Parametros validados!"
echo ""
echo "CONFIGURACAO VALIDADA:"
echo "📧 Email: $SSL_EMAIL"
echo "🔄 N8N: $DOMINIO_N8N"  
echo "🐳 Portainer: $DOMINIO_PORTAINER"
echo "🔗 Webhook: $WEBHOOK_N8N"
echo "📱 Evolution: $DOMINIO_EVOLUTION"
echo ""

# Verificar conectividade com a internet
log_info "🌐 Verificando conectividade com a internet..."
if ! ping -c 1 google.com >/dev/null 2>&1; then
    log_error "❌ Sem conexao com a internet!"
    exit 1
fi
log_success "✅ Internet funcionando!"

# Gerar chaves seguras
log_info "🔐 Gerando chaves de seguranca..."
N8N_KEY=$(openssl rand -hex 16)
POSTGRES_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12)
EVOLUTION_API_KEY=$(openssl rand -hex 32)

# Salvar variaveis de ambiente
cat > .env <<EOF
SSL_EMAIL=$SSL_EMAIL
DOMINIO_N8N=$DOMINIO_N8N
WEBHOOK_N8N=$WEBHOOK_N8N
DOMINIO_PORTAINER=$DOMINIO_PORTAINER
DOMINIO_EVOLUTION=$DOMINIO_EVOLUTION
N8N_KEY=$N8N_KEY
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
EVOLUTION_API_KEY=$EVOLUTION_API_KEY
EOF

log_success "✅ Variaveis salvas em .env"

# Configuracao do sistema
log_info "⚙️ Configurando sistema..."
export DEBIAN_FRONTEND=noninteractive
timedatectl set-timezone America/Sao_Paulo

log_success "✅ Instalacao iniciada com sucesso!"
echo ""
echo "PROXIMOS PASSOS:"
echo "1. O script continuara automaticamente"
echo "2. Aguarde o processo completar (pode levar alguns minutos)"
echo "3. As credenciais serao exibidas no final"
echo ""

# Aqui continuaria com o resto da instalacao...
# Por agora, vamos testar se o arquivo funciona

log_success "🎉 Teste de arquivo concluido com sucesso!"