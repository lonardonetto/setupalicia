# 📱 Instalador N8N + Evolution API

Instalador completo que inclui N8N e Evolution API com PostgreSQL e Redis, baseado no instalador original do Maicon Ramos.

## 🚀 Instalação Única

```bash
bash <(curl -sSL https://raw.githubusercontent.com/lonardonetto/setupalicia/main/install_n8n_evolution.sh) \
"seu-email@gmail.com" \
"n8n.seudominio.com" \
"portainer.seudominio.com" \
"webhook.seudominio.com" \
"evolution.seudominio.com"
```

## 📦 O que será instalado

1. **🐳 Docker & Swarm** - Containerização e orquestração
2. **🔒 Traefik** - Proxy reverso com SSL automático  
3. **🎛️ Portainer** - Interface de gerenciamento
4. **🗃️ PostgreSQL** - Banco de dados principal
5. **⚡ Redis** - Cache e filas
6. **📱 Evolution API** - API completa para WhatsApp
7. **🔄 N8N** - Automação de workflows

## 🔧 Parâmetros de Instalação

| Parâmetro | Descrição | Exemplo |
|-----------|-----------|---------|
| `SSL_EMAIL` | Email para certificados SSL | `contato@empresa.com` |
| `DOMINIO_N8N` | Domínio para N8N | `n8n.empresa.com` |  
| `DOMINIO_PORTAINER` | Domínio para Portainer | `portainer.empresa.com` |
| `WEBHOOK_N8N` | Domínio para webhooks | `webhook.empresa.com` |
| `DOMINIO_EVOLUTION` | Domínio para Evolution | `evolution.empresa.com` |

## 🌐 Configuração DNS

Configure os seguintes subdomínios no seu provedor DNS:

```
n8n.seudominio.com        → IP_DO_SERVIDOR
portainer.seudominio.com  → IP_DO_SERVIDOR
webhook.seudominio.com    → IP_DO_SERVIDOR  
evolution.seudominio.com  → IP_DO_SERVIDOR
```

## 🔑 Credenciais Importantes

Após a instalação, você receberá:

- **Evolution API Key**: Chave para autenticação da API
- **PostgreSQL Password**: Senha do banco de dados
- **N8N Encryption Key**: Chave de criptografia do N8N

> ⚠️ **IMPORTANTE**: Todas as credenciais são salvas automaticamente no arquivo `.env`

## 🎯 URLs de Acesso

Após a instalação concluída:

- **Portainer**: `https://portainer.seudominio.com`
- **N8N**: `https://n8n.seudominio.com`  
- **Evolution API**: `https://evolution.seudominio.com`

## 📱 Usando a Evolution API

### Autenticação
```bash
curl -X GET https://evolution.seudominio.com/manager/fetchInstances \
-H "apikey: SUA_EVOLUTION_API_KEY"
```

### Criar Instância
```bash
curl -X POST https://evolution.seudominio.com/manager/create \
-H "Content-Type: application/json" \
-H "apikey: SUA_EVOLUTION_API_KEY" \
-d '{
  "instanceName": "minha_instancia",
  "qrcode": true,
  "integration": "WHATSAPP-BAILEYS"
}'
```

## 🔄 Integração N8N + Evolution

O N8N e Evolution API estão configurados para trabalhar em conjunto:

1. **Webhooks**: Configure webhooks da Evolution para disparar workflows no N8N
2. **Database**: Ambos compartilham o mesmo PostgreSQL
3. **Network**: Comunicação interna via rede Docker Swarm

## 📊 Monitoramento

### Logs da Instalação
```bash
tail -f instalacao_n8n_evolution.log
```

### Status dos Serviços
```bash
docker service ls
```

### Verificar Stacks
```bash
docker stack ls
```

## 🛠️ Resolução de Problemas

### Evolution API não inicia
```bash
# Verificar logs
docker service logs evolution_evolution-api --follow

# Reiniciar serviço
docker service update --force evolution_evolution-api
```

### N8N não conecta ao banco
```bash
# Verificar PostgreSQL
docker service logs postgres_postgres --follow

# Verificar conectividade
docker exec -it $(docker ps -q -f name=postgres_postgres) psql -U postgres -l
```

## 💾 Backup

### Backup dos dados
```bash
# Volumes importantes
docker volume ls | grep -E "(evolution|n8n|postgres)"

# Backup Evolution
docker run --rm -v evolution_instances:/source -v $(pwd):/backup alpine tar czf /backup/evolution_backup.tar.gz -C /source .

# Backup N8N  
docker run --rm -v n8n_data:/source -v $(pwd):/backup alpine tar czf /backup/n8n_backup.tar.gz -C /source .
```

## ⚙️ Requisitos do Sistema

- **SO**: Ubuntu 18.04+ / Debian 10+ / CentOS 7+
- **RAM**: Mínimo 4GB (recomendado 8GB)
- **Disco**: Mínimo 20GB livres
- **CPU**: 2 vCPUs
- **Portas**: 80, 443 abertas
- **Root**: Executar como root

## 📞 Suporte

- 📧 **Email Original**: Maicon Ramos - Automação sem Limites
- 💬 **WhatsApp**: [Grupos SetupAlicia](https://alicia.setup.com/whatsapp2)
- 🐛 **Issues**: [GitHub Issues](https://github.com/lonardonetto/setupalicia/issues)

---

⚡ **Desenvolvido baseado no trabalho original do Maicon Ramos**