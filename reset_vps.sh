#!/bin/bash

# 🔥 SCRIPT DE RESET COMPLETO DA VPS
# ATENÇÃO: ESTE SCRIPT APAGARÁ TUDO!

echo "🔥 INICIANDO RESET COMPLETO DA VPS..."
echo "⚠️  ATENÇÃO: Este processo irá APAGAR TUDO!"
echo ""
read -p "Tem certeza que deseja continuar? Digite 'CONFIRMO' para prosseguir: " confirmacao

if [ "$confirmacao" != "CONFIRMO" ]; then
    echo "❌ Operação cancelada."
    exit 1
fi

echo ""
echo "🗑️ PASSO 1: Parando e removendo containers..."

# Parar todos os containers
sudo docker stop $(sudo docker ps -aq) 2>/dev/null || true

# Remover todos os containers
sudo docker rm $(sudo docker ps -aq) 2>/dev/null || true

# Parar Docker Swarm
sudo docker swarm leave --force 2>/dev/null || true

echo "🗑️ PASSO 2: Removendo imagens, volumes e redes..."

# Remover todas as imagens
sudo docker rmi $(sudo docker images -q) --force 2>/dev/null || true

# Remover todos os volumes
sudo docker volume rm $(sudo docker volume ls -q) --force 2>/dev/null || true

# Remover todas as redes personalizadas
sudo docker network rm $(sudo docker network ls --filter type=custom -q) 2>/dev/null || true

# Limpar sistema Docker
sudo docker system prune -a --volumes --force

echo "🗑️ PASSO 3: Removendo Docker completamente..."

# Parar serviços
sudo systemctl stop docker 2>/dev/null || true
sudo systemctl stop docker.socket 2>/dev/null || true
sudo systemctl stop containerd 2>/dev/null || true

# Remover pacotes Docker
sudo apt-get purge -y docker-engine docker docker.io docker-ce docker-ce-cli containerd.io 2>/dev/null || true
sudo apt-get autoremove -y --purge docker-engine docker docker.io docker-ce docker-ce-cli containerd.io 2>/dev/null || true

# Remover diretórios
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
sudo rm -rf /etc/docker
sudo rm -rf ~/.docker
sudo rm -rf /var/run/docker.sock

echo "🗑️ PASSO 4: Limpando arquivos de configuração..."

# Limpar arquivos do SetupAlicia
cd ~
rm -rf setupalicia/ 2>/dev/null || true
rm -f setup.sh install_n8n_evolution.sh *.yaml *.yml .env instalacao_n8n.log 2>/dev/null || true

# Limpar comandos personalizados
sudo rm -f /usr/local/bin/atualizar 2>/dev/null || true
sudo rm -f /usr/local/bin/ssl.status 2>/dev/null || true
sudo rm -f /usr/local/bin/ssl.check 2>/dev/null || true
sudo rm -f /usr/local/bin/portainer.restart 2>/dev/null || true
sudo rm -f /usr/local/bin/limpar 2>/dev/null || true

# Remover swap
sudo swapoff /swapfile 2>/dev/null || true
sudo rm -f /swapfile 2>/dev/null || true
sudo sed -i '/\/swapfile/d' /etc/fstab 2>/dev/null || true

echo "🧹 PASSO 5: Limpeza final..."

# Limpar logs e cache
sudo journalctl --vacuum-time=1d 2>/dev/null || true
sudo apt-get clean 2>/dev/null || true
sudo apt-get autoclean 2>/dev/null || true
sudo apt-get autoremove -y 2>/dev/null || true

echo ""
echo "✅ RESET COMPLETO FINALIZADO!"
echo ""
echo "🚀 Próximos passos:"
echo "1. Atualize o sistema: sudo apt-get update && sudo apt-get upgrade -y"
echo "2. Configure seus domínios no DNS apontando para o IP desta VPS"
echo "3. Execute a instalação fresca:"
echo ""
echo "   # Instalação completa:"
echo "   bash <(curl -sSL https://raw.githubusercontent.com/lonardonetto/setupalicia/main/setup.sh)"
echo ""
echo "   # OU instalação direta N8N + Evolution:"
echo "   bash <(curl -sSL https://raw.githubusercontent.com/lonardonetto/setupalicia/main/install_n8n_evolution.sh) \\"
echo "   \"seu@email.com\" \\"
echo "   \"n8n.seudominio.com\" \\"
echo "   \"portainer.seudominio.com\" \\"
echo "   \"webhook.seudominio.com\" \\"
echo "   \"evolution.seudominio.com\""
echo ""
echo "🎯 Sua VPS está agora completamente limpa e pronta para instalação fresca!"