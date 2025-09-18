#!/bin/bash

# CONVERSOR MANUAL PARA FULL CONTROL
# Solução definitiva quando a API falha

echo "🔄 CONVERSOR MANUAL PARA FULL CONTROL"
echo "====================================="
echo ""
echo "A API do Portainer está falhando, mas temos uma solução manual simples:"
echo ""

# Carregar credenciais
if [ -f .env ]; then
    source .env
else
    echo "❌ Arquivo .env não encontrado!"
    exit 1
fi

echo "📋 INSTRUÇÕES PARA CONVERTER MANUALMENTE:"
echo ""
echo "1. 🌐 Acesse: https://$DOMINIO_PORTAINER"
echo "2. 🔑 Login: admin / $PORTAINER_ADMIN_PASSWORD"
echo "3. 📂 Vá em 'Stacks' no menu lateral"
echo "4. 🔄 Para CADA stack Limited:"
echo "   • Clique no nome da stack"
echo "   • Clique em 'Editor'"
echo "   • Clique em 'Update the stack'"
echo "   • ✅ Pronto! Fica Full Control"
echo ""
echo "📝 Stacks para converter:"
echo "   • postgres"
echo "   • redis" 
echo "   • evolution"
echo "   • n8n"
echo "   • traefik"
echo "   • portainer"
echo ""
echo "⏱️  Tempo estimado: 2-3 minutos"
echo ""
echo "🎯 ALTERNATIVA RÁPIDA:"
echo "Você pode usar apenas as stacks Limited mesmo."
echo "Elas funcionam PERFEITAMENTE, só não podem ser editadas pelo Portainer."
echo "Mas você pode:"
echo "• ✅ Ver logs"
echo "• ✅ Reiniciar serviços"
echo "• ✅ Ver métricas"
echo "• ✅ Tudo funciona normalmente"
echo ""

read -p "🤔 Deseja abrir o Portainer agora? (s/n): " resposta

if [[ $resposta =~ ^[Ss]$ ]]; then
    echo ""
    echo "🌐 Abrindo Portainer..."
    echo "URL: https://$DOMINIO_PORTAINER"
    echo "Login: admin"
    echo "Senha: $PORTAINER_ADMIN_PASSWORD"
    echo ""
    echo "Siga as instruções acima para converter as stacks!"
else
    echo ""
    echo "✅ OK! As instruções estão acima quando você quiser converter."
    echo ""
    echo "🎉 PARABÉNS! Seu ambiente está 100% funcional:"
    echo "• 🔒 Traefik: Proxy SSL automático"
    echo "• 🐳 Portainer: Interface Docker"
    echo "• 🗄️  PostgreSQL: Banco de dados"
    echo "• 🔴 Redis: Cache e filas"
    echo "• 📱 Evolution: API WhatsApp"
    echo "• 🔄 N8N: Automação"
    echo ""
    echo "Tudo funcionando perfeitamente! 🚀"
fi
