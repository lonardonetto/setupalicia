#!/bin/bash

# 🔍 DIAGNÓSTICO EVOLUTION API - Troubleshooting Script
# Execute este script para diagnosticar problemas com Evolution API

echo "🔍 DIAGNÓSTICO EVOLUTION API"
echo "======================================================="
echo ""

echo "📋 PASSO 1: Verificando Stacks Docker..."
echo "Stacks disponíveis:"
docker stack ls
echo ""

echo "📋 PASSO 2: Verificando serviços Evolution..."
echo "Serviços Evolution:"
docker service ls | grep -i evolution || echo "❌ Nenhum serviço Evolution encontrado"
echo ""

echo "📋 PASSO 3: Status detalhado do stack Evolution..."
if docker stack ps evolution >/dev/null 2>&1; then
    echo "Status do stack Evolution:"
    docker stack ps evolution
else
    echo "❌ Stack Evolution não encontrado"
fi
echo ""

echo "📋 PASSO 4: Verificando containers Evolution..."
echo "Containers Evolution (ativos e parados):"
docker ps -a | grep -i evolution || echo "❌ Nenhum container Evolution encontrado"
echo ""

echo "📋 PASSO 5: Verificando logs da Evolution API..."
if docker service logs evolution_evolution-api >/dev/null 2>&1; then
    echo "🔍 Últimos logs da Evolution API:"
    docker service logs evolution_evolution-api --tail 20
else
    echo "❌ Serviço evolution_evolution-api não encontrado"
fi
echo ""

echo "📋 PASSO 6: Verificando recursos do sistema..."
echo "Uso de memória:"
docker system df
echo ""
echo "Espaço em disco:"
df -h /var/lib/docker
echo ""

echo "📋 PASSO 7: Verificando arquivo de configuração..."
if [ -f "evolution.yaml" ]; then
    echo "✅ Arquivo evolution.yaml encontrado"
    echo "Verificando configuração:"
    grep -E "(image|environment)" evolution.yaml | head -10
else
    echo "❌ Arquivo evolution.yaml não encontrado"
fi
echo ""

echo "📋 PASSO 8: Verificando variáveis de ambiente..."
if [ -f ".env" ]; then
    echo "✅ Arquivo .env encontrado"
    echo "Variáveis Evolution:"
    grep -E "(EVOLUTION|POSTGRES|REDIS)" .env || echo "❌ Variáveis Evolution não encontradas"
else
    echo "❌ Arquivo .env não encontrado"
fi
echo ""

echo "======================================================="
echo "🔧 COMANDOS DE RECUPERAÇÃO SUGERIDOS:"
echo ""
echo "Se o stack não existe ou falhou:"
echo "1. docker stack deploy -c evolution.yaml evolution"
echo ""
echo "Se o serviço existe mas não funciona:"
echo "2. docker service update --force evolution_evolution-api"
echo ""
echo "Se houver problemas de imagem:"
echo "3. docker service update --image atendai/evolution-api:v2.2.3 evolution_evolution-api"
echo ""
echo "Recriar stack completamente:"
echo "4. docker stack rm evolution && sleep 30 && docker stack deploy -c evolution.yaml evolution"
echo ""
echo "======================================================="