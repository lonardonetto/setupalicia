# 🚀 INSTALAÇÃO DEFINITIVA - SETUPALICIA

## ✨ Script que GARANTE que TUDO FUNCIONA! ✨

### 📋 COMANDO ÚNICO PARA INSTALAÇÃO COMPLETA:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/lonardonetto/setupalicia/main/install_definitivo.sh) \
"seu@email.com" \
"n8n.seudominio.com" \
"portainer.seudominio.com" \
"webhook.seudominio.com" \
"evolution.seudominio.com"
```

### 🎯 SUBSTITUA OS VALORES:
- `seu@email.com` → Seu email para SSL
- `n8n.seudominio.com` → Domínio para N8N
- `portainer.seudominio.com` → Domínio para Portainer  
- `webhook.seudominio.com` → Domínio para Webhook N8N
- `evolution.seudominio.com` → Domínio para Evolution API

### 📱 EXEMPLO REAL:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/lonardonetto/setupalicia/main/install_definitivo.sh) \
"joao@gmail.com" \
"n8n.minhaempresa.com" \
"portainer.minhaempresa.com" \
"webhook.minhaempresa.com" \
"evolution.minhaempresa.com"
```

## ✅ O QUE SERÁ INSTALADO:

1. **🐋 Docker + Docker Swarm** - Orquestração de containers
2. **🔒 Traefik** - Proxy reverso com SSL automático
3. **🐳 Portainer** - Interface de gerenciamento Docker
4. **🗄️ PostgreSQL** - Banco de dados
5. **🔴 Redis** - Cache e filas
6. **📱 Evolution API v2.2.3** - API para WhatsApp
7. **🔄 N8N** - Automação de workflows

## ⚙️ PRÉ-REQUISITOS:

- ✅ VPS com Ubuntu 18.04+, Debian 10+ ou CentOS 7+
- ✅ Usuário com sudo (não root)
- ✅ Portas 80 e 443 abertas
- ✅ Domínios apontando para o IP do servidor

## 🌐 CONFIGURAR DOMÍNIOS:

Configure seus subdomínios no DNS para apontar para o IP do seu VPS:

```
n8n.seudominio.com        → IP_DO_VPS
portainer.seudominio.com  → IP_DO_VPS
webhook.seudominio.com    → IP_DO_VPS
evolution.seudominio.com  → IP_DO_VPS
```

## ⏰ TEMPO DE INSTALAÇÃO:

- **Instalação completa**: 10-15 minutos
- **SSL automático**: +2-3 minutos
- **Evolution API**: Pode levar até 5 minutos para ficar 100% ativa

## 🎉 APÓS A INSTALAÇÃO:

Você receberá:

### 🌐 URLs de Acesso:
- **Portainer**: https://portainer.seudominio.com
- **N8N**: https://n8n.seudominio.com  
- **Evolution API**: https://evolution.seudominio.com
- **Evolution Docs**: https://evolution.seudominio.com/manager/docs
- **Webhook N8N**: https://webhook.seudominio.com

### 🔑 Credenciais:
- **Evolution API Key**: Gerada automaticamente
- **PostgreSQL Password**: Gerada automaticamente
- **N8N Encryption Key**: Gerada automaticamente

*Todas as credenciais são salvas no arquivo `.env` no servidor*

## 🔧 COMANDOS ÚTEIS:

```bash
# Ver status dos serviços
docker service ls

# Ver containers ativos  
docker ps

# Ver logs da Evolution API
docker service logs evolution_evolution-api --follow

# Reiniciar Evolution API
docker service update --force evolution_evolution-api

# Ver todas as stacks
docker stack ls
```

## 🆘 SUPORTE:

Se algo não funcionar:

1. **Aguarde 5 minutos** - A Evolution API pode demorar para inicializar
2. **Verifique DNS** - Domínios devem apontar para o IP correto
3. **Portas abertas** - 80 e 443 devem estar liberadas no firewall
4. **Logs** - Use os comandos acima para verificar logs

## ✨ DIFERENCIAIS DESTE SCRIPT:

- ✅ **Sequência otimizada** de instalação
- ✅ **Verificação rigorosa** de cada serviço
- ✅ **Health checks** automáticos
- ✅ **Evolution API garantida** para funcionar
- ✅ **Auto-recovery** em caso de falhas
- ✅ **Diagnósticos detalhados** ao final
- ✅ **Timeouts inteligentes** para cada serviço

## 🎯 RESULTADO FINAL:

**TODOS OS SERVIÇOS FUNCIONANDO 100%** com SSL automático e domínios configurados!

---

**🚀 Execute o comando acima no seu VPS e tenha tudo funcionando em minutos!**