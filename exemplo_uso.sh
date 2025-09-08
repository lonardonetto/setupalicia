#!/bin/bash

# Exemplo de uso do instalador N8N + Evolution API
# Este arquivo demonstra como usar o instalador

echo "=================================================="
echo "    EXEMPLO DE USO - N8N + Evolution API"
echo "=================================================="
echo ""

# Parâmetros de exemplo
SSL_EMAIL="seu-email@gmail.com"
DOMINIO_N8N="n8n.seudominio.com"
DOMINIO_PORTAINER="portainer.seudominio.com"
WEBHOOK_N8N="webhook.seudominio.com"
DOMINIO_EVOLUTION="evolution.seudominio.com"

echo "Instalação será executada com os seguintes parâmetros:"
echo ""
echo "📧 Email SSL: $SSL_EMAIL"
echo "🔄 N8N: https://$DOMINIO_N8N"
echo "🎛️  Portainer: https://$DOMINIO_PORTAINER"
echo "🔗 Webhook: https://$WEBHOOK_N8N"
echo "📱 Evolution: https://$DOMINIO_EVOLUTION"
echo ""

read -p "Pressione Enter para continuar ou Ctrl+C para cancelar..."

echo ""
echo "Executando instalador..."
echo ""

# Comando de instalação completo
bash <(curl -sSL https://raw.githubusercontent.com/lonardonetto/setupalicia/main/install_n8n_evolution.sh) \
"$SSL_EMAIL" \
"$DOMINIO_N8N" \
"$DOMINIO_PORTAINER" \
"$WEBHOOK_N8N" \
"$DOMINIO_EVOLUTION"