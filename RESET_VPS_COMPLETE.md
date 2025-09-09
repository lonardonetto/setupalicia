# 🔥 RESET COMPLETO DA VPS - INSTALAÇÃO DO ZERO

## ⚠️ **ATENÇÃO: ESTE PROCESSO APAGARÁ TUDO!**

Este guia irá **COMPLETAMENTE LIMPAR** sua VPS e instalar tudo do zero.

## 🗑️ **PASSO 1: LIMPEZA COMPLETA**

### 1.1 Parar e Remover TODOS os Containers Docker
```bash
# Parar todos os containers
sudo docker stop $(sudo docker ps -aq) 2>/dev/null || true

# Remover todos os containers
sudo docker rm $(sudo docker ps -aq) 2>/dev/null || true

# Remover todas as imagens
sudo docker rmi $(sudo docker images -q) --force 2>/dev/null || true

# Remover todos os volumes
sudo docker volume rm $(sudo docker volume ls -q) --force 2>/dev/null || true

# Remover todas as redes personalizadas
sudo docker network rm $(sudo docker network ls --filter type=custom -q) 2>/dev/null || true

# Limpar sistema Docker completamente
sudo docker system prune -a --volumes --force

# Parar Docker Swarm se estiver ativo
sudo docker swarm leave --force 2>/dev/null || true
```

### 1.2 Remover Docker Completamente
```bash
# Parar serviço Docker
sudo systemctl stop docker
sudo systemctl stop docker.socket
sudo systemctl stop containerd

# Desabilitar Docker
sudo systemctl disable docker
sudo systemctl disable docker.socket
sudo systemctl disable containerd

# Remover pacotes Docker (Ubuntu/Debian)
sudo apt-get purge -y docker-engine docker docker.io docker-ce docker-ce-cli containerd.io
sudo apt-get autoremove -y --purge docker-engine docker docker.io docker-ce docker-ce-cli containerd.io

# Remover pacotes Docker (CentOS/RHEL)
# sudo yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine

# Remover diretórios Docker
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
sudo rm -rf /etc/docker
sudo rm -rf ~/.docker
sudo rm -rf /var/run/docker.sock
sudo rm -rf /usr/local/bin/docker-compose
```

### 1.3 Limpar Arquivos de Configuração
```bash
# Remover arquivos do SetupAlicia
cd ~
rm -rf setupalicia/
rm -f setup.sh
rm -f install_n8n_evolution.sh
rm -f *.yaml
rm -f *.yml
rm -f .env
rm -f instalacao_n8n.log
rm -f traefik.yaml
rm -f portainer.yaml
rm -f postgres.yaml
rm -f redis.yaml
rm -f n8n.yaml
rm -f evolution.yaml

# Limpar comandos personalizados
sudo rm -f /usr/local/bin/atualizar
sudo rm -f /usr/local/bin/ssl.status
sudo rm -f /usr/local/bin/ssl.check
sudo rm -f /usr/local/bin/portainer.restart
sudo rm -f /usr/local/bin/limpar
sudo rm -f /usr/local/bin/ctop
sudo rm -f /usr/local/bin/htop
```

### 1.4 Resetar Configurações de Rede
```bash
# Resetar hostname se foi alterado
sudo hostnamectl set-hostname $(hostname -s)

# Resetar /etc/hosts
sudo cp /etc/hosts.bak /etc/hosts 2>/dev/null || echo "127.0.0.1 localhost" | sudo tee /etc/hosts

# Remover swap se foi criado
sudo swapoff /swapfile 2>/dev/null || true
sudo rm -f /swapfile
sudo sed -i '/\/swapfile/d' /etc/fstab
```

### 1.5 Limpar Logs e Cache
```bash
# Limpar logs
sudo journalctl --vacuum-time=1d
sudo rm -rf /var/log/docker*
sudo rm -rf /var/log/containers*

# Limpar cache de pacotes
sudo apt-get clean
sudo apt-get autoclean
sudo apt-get autoremove -y

# Para CentOS/RHEL
# sudo yum clean all
```

## 🚀 **PASSO 2: INSTALAÇÃO FRESCA**

### 2.1 Atualizar Sistema
```bash
# Ubuntu/Debian
sudo apt-get update -y
sudo apt-get upgrade -y

# CentOS/RHEL
# sudo yum update -y
```

### 2.2 Instalar SetupAlicia do Zero
```bash
# Método 1: Instalação Completa (Recomendado)
bash <(curl -sSL https://raw.githubusercontent.com/lonardonetto/setupalicia/main/setup.sh)
```

**OU**

```bash
# Método 2: N8N + Evolution API Direto (Mais Rápido)
bash <(curl -sSL https://raw.githubusercontent.com/lonardonetto/setupalicia/main/install_n8n_evolution.sh) \
"SEU_EMAIL@gmail.com" \
"n8n.SEUDOMINIO.com" \
"portainer.SEUDOMINIO.com" \
"webhook.SEUDOMINIO.com" \
"evolution.SEUDOMINIO.com"
```

## 📋 **PASSO 3: CONFIGURAÇÃO DOS DOMÍNIOS**

Antes de executar, configure seus domínios apontando para o IP da VPS:

```
Tipo A - n8n.SEUDOMINIO.com → IP_DA_VPS
Tipo A - portainer.SEUDOMINIO.com → IP_DA_VPS
Tipo A - webhook.SEUDOMINIO.com → IP_DA_VPS
Tipo A - evolution.SEUDOMINIO.com → IP_DA_VPS
```

## 🔐 **PASSO 4: VERIFICAÇÕES PÓS-INSTALAÇÃO**

### 4.1 Verificar Serviços
```bash
# Status dos stacks
docker stack ls

# Status dos serviços
docker service ls

# Logs se houver problemas
docker service logs postgres_postgres
docker service logs redis_redis
docker service logs evolution_evolution-api
docker service logs n8n_n8n
```

### 4.2 Testar URLs
- 🐳 **Portainer**: https://portainer.SEUDOMINIO.com
- 🔄 **N8N**: https://n8n.SEUDOMINIO.com
- 📱 **Evolution API**: https://evolution.SEUDOMINIO.com
- 📚 **Evolution Docs**: https://evolution.SEUDOMINIO.com/manager/docs

## 🆘 **EM CASO DE PROBLEMAS**

### Verificar Logs Detalhados
```bash
# Logs do PostgreSQL
docker service logs --tail 100 postgres_postgres

# Logs da Evolution API
docker service logs --tail 100 evolution_evolution-api

# Logs do N8N
docker service logs --tail 100 n8n_n8n

# Status detalhado dos serviços
docker service ps postgres_postgres
docker service ps evolution_evolution-api
docker service ps n8n_n8n
```

### Comandos de Recuperação
```bash
# Reiniciar serviço específico
docker service update --force evolution_evolution-api

# Recriar stack completa
docker stack rm evolution
sleep 30
docker stack deploy -c evolution.yaml evolution
```

## ✅ **CHECKLIST FINAL**

- [ ] VPS completamente limpa
- [ ] Docker removido e reinstalado
- [ ] Domínios configurados no DNS
- [ ] Portas 80 e 443 abertas
- [ ] SetupAlicia v0.2 instalado
- [ ] Todos os serviços funcionando
- [ ] SSL gerado automaticamente
- [ ] Credenciais salvas no arquivo .env

---

## 🎯 **RESULTADO ESPERADO**

Após seguir este guia, você terá:

1. **VPS completamente limpa** 🧹
2. **Instalação fresca** do SetupAlicia v0.2 🆕
3. **Todos os serviços funcionando** sem erros ✅
4. **SSL automático** configurado 🔐
5. **Evolution API v2.2.3** sem erros de PostgreSQL 📱
6. **N8N funcionando** perfeitamente 🔄

**Tempo estimado**: 15-30 minutos

---

⚠️ **IMPORTANTE**: Guarde as credenciais que serão geradas no arquivo `.env`!