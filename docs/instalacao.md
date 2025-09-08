# 📖 Documentação de Instalação - SetupAlicia

## 🎯 Visão Geral

O SetupAlicia é um instalador automatizado que configura aplicações Docker com SSL automático via Traefik e Let's Encrypt. Desenvolvido para simplificar a instalação de aplicações essenciais em servidores.

## 🚀 Instalação Rápida

### Método 1: Instalação Direta (Recomendado)

```bash
bash <(curl -sSL https://raw.githubusercontent.com/lonardonetto/setupalicia/main/setup.sh)
```

### Método 2: Download e Execução

```bash
# Download do script
curl -sSL https://raw.githubusercontent.com/lonardonetto/setupalicia/main/setup.sh -o setup.sh

# Dar permissão de execução
chmod +x setup.sh

# Executar
./setup.sh
```

## 🔧 Aplicações Disponíveis

### 1. Traefik & Portainer
- **Traefik**: Proxy reverso com SSL automático
- **Portainer**: Interface web para gerenciar Docker
- **SSL**: Configurado automaticamente via Let's Encrypt

### 2. Evolution API
- API para integração com WhatsApp
- SSL automático configurado
- Pronto para produção

### 3. N8N
- Plataforma de automação visual
- Interface drag-and-drop
- SSL e HTTPS configurados

### 4. N8N + MCP
- N8N com Model Context Protocol
- Suporte avançado para IA
- Integração com LLMs

## 🌐 Configuração DNS

Antes da instalação, configure seus registros DNS:

```
# Registros A necessários (substitua pelo IP do seu servidor)
traefik.seudominio.com    A    123.456.789.123
portainer.seudominio.com  A    123.456.789.123
evolution.seudominio.com  A    123.456.789.123
n8n.seudominio.com        A    123.456.789.123
```

## 🔐 Como Funciona o SSL

### Processo Automático
1. **Detecção**: Traefik detecta novos serviços automaticamente
2. **Solicitação**: Requisita certificado SSL via Let's Encrypt
3. **Validação**: ACME TLS Challenge valida o domínio
4. **Instalação**: Certificado é instalado automaticamente
5. **Renovação**: Renovação automática a cada 90 dias

### Verificação SSL
```bash
# Verificar status geral
ssl.status

# Verificar domínio específico
ssl.check meudominio.com
```

## 📋 Pré-requisitos do Sistema

### Sistema Operacional
- Ubuntu 18.04 LTS ou superior
- Debian 10 ou superior
- CentOS 7 ou superior
- Amazon Linux 2

### Requisitos de Hardware
- **RAM**: Mínimo 2GB (Recomendado 4GB+)
- **Armazenamento**: Mínimo 20GB livres
- **CPU**: 1 vCore (Recomendado 2+ vCores)

### Requisitos de Rede
- **Portas**: 80 (HTTP) e 443 (HTTPS) abertas
- **Domínio**: Apontando para o IP do servidor
- **Internet**: Conexão estável para downloads

### Usuário
- **Não usar root**: Execute com usuário normal
- **Sudo**: Usuário deve ter privilégios sudo
- **Docker**: Será instalado automaticamente se não existir

## ⚙️ Comandos Disponíveis

### Comandos do Sistema
```bash
atualizar              # Atualiza o SetupAlicia
portainer.restart      # Reinicia o Portainer
ctop                   # Instala CTOP (monitor containers)
htop                   # Instala HTOP (monitor sistema)
limpar                 # Limpa sistema Docker
```

### Comandos SSL
```bash
ssl.status             # Status dos certificados
ssl.check <dominio>    # Verifica SSL específico
```

## 🐳 Estrutura Docker

### Rede Traefik
```bash
# Rede criada automaticamente
docker network ls | grep traefik_proxy
```

### Volumes Persistentes
```bash
# Volumes criados
portainer_data         # Dados do Portainer
n8n_data              # Dados do N8N
n8n_mcp_data          # Dados do N8N+MCP
```

### Configurações Traefik
```bash
# Diretórios criados
/opt/traefik/data/     # Configurações
/opt/traefik/rules/    # Regras personalizadas
```

## 🔍 Resolução de Problemas

### Docker não instalado
```bash
# O script instala automaticamente, mas se falhar:
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Fazer logout e login novamente
```

### Certificados SSL não funcionando
```bash
# Verificar Traefik
docker logs traefik

# Verificar arquivo ACME
ls -la /opt/traefik/data/acme.json

# Verificar DNS
nslookup seudominio.com
```

### Portas ocupadas
```bash
# Verificar portas em uso
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443

# Parar serviços conflitantes
sudo systemctl stop apache2 nginx
```

### Aplicação não acessível
```bash
# Verificar containers
docker ps

# Verificar logs
docker logs nome-do-container

# Verificar rede
docker network inspect traefik_proxy
```

## 📊 Monitoramento

### Status dos Serviços
```bash
# Ver todos os containers
docker ps

# Ver status detalhado
docker stats

# Com CTOP (mais visual)
ctop
```

### Logs dos Serviços
```bash
# Traefik
docker logs traefik -f

# Portainer
docker logs portainer -f

# Evolution API
docker logs evolution-api -f

# N8N
docker logs n8n -f
```

## 🔄 Atualizações

### Auto-atualização
O script verifica automaticamente por atualizações quando executado remotamente.

### Atualização Manual
```bash
# Dentro do script
atualizar

# Ou re-executar a instalação
bash <(curl -sSL https://lonardonetto.github.io/setupalicia/setup.sh)
```

## 🛡️ Segurança

### Configurações de Segurança
- **SSL/TLS**: Criptografia automática
- **Firewall**: Configure apenas portas 80/443
- **Usuário**: Nunca execute como root
- **Senhas**: Use senhas fortes para Portainer

### Recomendações
```bash
# Configurar firewall básico
sudo ufw allow 22      # SSH
sudo ufw allow 80      # HTTP
sudo ufw allow 443     # HTTPS
sudo ufw enable

# Atualizar sistema
sudo apt update && sudo apt upgrade -y
```

## 🤝 Suporte

### Canais de Suporte
- **GitHub Issues**: Para bugs e feature requests
- **WhatsApp**: Para suporte direto
- **Email**: Para questões comerciais

### Informações Úteis para Suporte
Ao solicitar suporte, inclua:
```bash
# Versão do SO
cat /etc/os-release

# Versão do Docker
docker --version

# Status dos containers
docker ps

# Logs do Traefik
docker logs traefik --tail 50
```

## 📝 Changelog

### v2.7.1
- ✅ SSL automático com Traefik
- ✅ Instalação via URL remota
- ✅ Auto-atualização
- ✅ Verificação de pré-requisitos
- ✅ Interface simplificada

---

💡 **Dica**: Mantenha sempre backups dos seus dados antes de fazer mudanças importantes no sistema.