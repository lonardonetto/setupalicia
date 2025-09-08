#!/bin/bash

# Script de teste local para SetupAlicia
# Execute: chmod +x test_local.sh && ./test_local.sh

echo "🧪 Testando SetupAlicia localmente..."
echo ""

# Verificar se o arquivo existe
if [ ! -f "setup.sh" ]; then
    echo "❌ Arquivo setup.sh não encontrado!"
    exit 1
fi

# Verificar sintaxe bash
echo "🔍 Verificando sintaxe bash..."
if bash -n setup.sh; then
    echo "✅ Sintaxe bash OK"
else
    echo "❌ Erro de sintaxe bash"
    exit 1
fi

# Verificar permissões
echo "🔍 Verificando permissões..."
chmod +x setup.sh
echo "✅ Permissões configuradas"

# Simular download (teste da estrutura)
echo "🔍 Testando estrutura do script..."
if grep -q "SetupAlicia v2.7.1" setup.sh; then
    echo "✅ Versão encontrada"
else
    echo "❌ Versão não encontrada"
fi

if grep -q "lonardonetto.github.io" setup.sh; then
    echo "✅ URL do GitHub encontrada"
else
    echo "❌ URL do GitHub não encontrada"
fi

# Verificar funções principais
echo "🔍 Verificando funções principais..."
functions=(
    "nome_instalador"
    "ferramenta_traefik_e_portainer"
    "ferramenta_evolution"
    "ferramenta_n8n"
    "ssl.status"
    "ssl.check"
    "atualizar_script"
)

for func in "${functions[@]}"; do
    if grep -q "^$func()" setup.sh; then
        echo "✅ Função $func encontrada"
    else
        echo "❌ Função $func não encontrada"
    fi
done

echo ""
echo "🎉 Teste concluído!"
echo ""
echo "📋 Próximos passos:"
echo "1. git init"
echo "2. git remote add origin https://github.com/lonardonetto/setupalicia.git"
echo "3. git add ."
echo "4. git commit -m 'Initial commit'"
echo "5. git push -u origin main"
echo "6. Configurar GitHub Pages em Settings → Pages"
echo ""
echo "🌐 URL final será: https://lonardonetto.github.io/setupalicia/setup.sh"