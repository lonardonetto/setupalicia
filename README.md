# 🚀 SetupAlicia - Instalador Automatizado com SSL

Instalador simplificado para aplicações essenciais com SSL automático via Traefik + Let's Encrypt.

## ⚡ Instalação Rápida

### SetupAlicia Completo
```bash
bash <(curl -sSL https://raw.githubusercontent.com/lonardonetto/setupalicia/main/setup.sh)
```

### N8N + Evolution API (Instalação Direta) - v0.2
```bash
bash <(curl -sSL https://raw.githubusercontent.com/lonardonetto/setupalicia/main/install_n8n_evolution.sh) \
"email@gmail.com" \
"n8n.seudominio.com" \
"portainer.seudominio.com" \
"webhook.seudominio.com" \
"evolution.seudominio.com"
```

> ✨ **Novidades v0.2**: Correções de autenticação PostgreSQL, verificação de saúde dos serviços, configuração otimizada da Evolution API e melhor sincronização entre serviços.

## 📦 Aplicações Incluídas

### SetupAlicia Principal
- **🔒 Traefik** - Proxy reverso com SSL automático
- **🐳 Portainer** - Interface de gerenciamento Docker  
- **📱 Evolution API** - API para WhatsApp
- **🔄 N8N** - Automação de workflows
- **🤖 N8N + MCP** - N8N com Model Context Protocol

### N8N + Evolution (install_n8n_evolution.sh) - v0.2
- **🔒 Traefik** - Proxy reverso com SSL automático
- **🐳 Portainer** - Interface de gerenciamento Docker
- **📦 PostgreSQL** - Banco de dados com autenticação corrigida
- **♾️ Redis** - Cache e filas
- **📱 Evolution API v2.2.3** - API para WhatsApp com configuração otimizada
- **🔄 N8N** - Automação de workflows
- **🔍 Verificação de Saúde** - Monitoramento automático dos serviços

## ✨ Recursos

- ✅ SSL automático com Let's Encrypt
- ✅ Renovação automática de certificados
- ✅ Redirecionamento HTTP → HTTPS  
- ✅ Interface simplificada
- ✅ Atualização automática do script
- ✅ Verificação de pré-requisitos
- ✅ Instalação automática do Docker

## 🔧 Comandos Especiais

- `atualizar` - Atualiza o SetupAlicia
- `ssl.status` - Status dos certificados SSL
- `ssl.check <dominio>` - Verifica SSL de um domínio
- `portainer.restart` - Reinicia o Portainer
- `ctop` - Instala o CTOP (monitoramento containers)
- `htop` - Instala o HTOP (monitoramento sistema)
- `limpar` - Limpa sistema Docker

## 🌐 Configuração de Domínios

Configure seus subdomínios apontando para o IP do servidor:

```
traefik.seudominio.com    → IP_DO_SERVIDOR
portainer.seudominio.com  → IP_DO_SERVIDOR  
evolution.seudominio.com  → IP_DO_SERVIDOR
n8n.seudominio.com        → IP_DO_SERVIDOR
```

## 📋 Pré-requisitos

- Ubuntu 18.04+ / Debian 10+ / CentOS 7+
- Usuário com sudo (não root)
- Portas 80 e 443 abertas
- Domínio apontando para o servidor

## 🛠️ Instalação Manual

Se preferir baixar e executar localmente:

```bash
# Download
curl -sSL https://raw.githubusercontent.com/lonardonetto/setupalicia/main/setup.sh -o setup.sh

# Executar
chmod +x setup.sh
./setup.sh
```

## 📅 Changelog

### v0.2 - install_n8n_evolution.sh (2025-09-09)
**🔄 Grandes Melhorias:**
- ✅ **Correção crítica**: Resolvidos erros de autenticação PostgreSQL
- 🕰️ **Melhor sincronização**: Timing otimizado entre serviços
- 🐞 **Evolution API v2.2.3**: Versão estável com configuração aprimorada
- 🔍 **Health Checks**: Verificação automática de saúde dos serviços
- 🔄 **Restart Policy**: Política de reinicialização automática
- 📊 **Melhor UX**: Mensagens detalhadas e guia de troubleshooting
- 🔐 **Segurança**: Geração segura de senhas e API keys

**🔧 Correções Técnicas:**
- Aguarda PostgreSQL estar 100% operacional antes de criar bancos
- Verificação ativa de Redis antes da Evolution API
- Fallback para arquivo local se download de config falhar
- Política de restart para recuperação automática
- Configuração de dados persistentes habilitada

## 🔍 Troubleshooting

### Problemas Comuns
**Evolution API não conecta ao PostgreSQL:**
```bash
# Verificar logs
docker service logs evolution_evolution-api

# Verificar PostgreSQL
docker exec $(docker ps --filter "name=postgres_postgres" --format "{{.Names}}") pg_isready -U postgres
```

**Serviços não iniciando:**
```bash
# Status dos stacks
docker stack ps postgres
docker stack ps redis
docker stack ps evolution
docker stack ps n8n

# Forçar restart
docker service update --force evolution_evolution-api
```

## 🕲️ Segurança SSL

- 🔒 Certificados Let's Encrypt gratuitos
- 🔄 Renovação automática a cada 90 dias
- 🚀 HTTP redirecionado automaticamente para HTTPS
- 🛡️ Configuração segura do Traefik

## 📞 Suporte

- 📱 **WhatsApp**: [Grupo 1](https://alicia.setup.com/whatsapp2) | [Grupo 2](https://alicia.setup.com/whatsapp3)
- 📧 **Email**: contato@alicia.setup.com
- 🐛 **Issues**: [GitHub Issues](https://github.com/lonardonetto/setupalicia/issues)

## 📄 Licença

Este projeto está licenciado sob a Licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.

## 🤝 Contribuindo

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📊 Status

![Bash](https://img.shields.io/badge/Shell-Bash-green)
![Docker](https://img.shields.io/badge/Docker-Supported-blue)
![SSL](https://img.shields.io/badge/SSL-Let's%20Encrypt-orange)
![License](https://img.shields.io/badge/License-MIT-yellow)

---

⭐ Se este projeto te ajudou, considere dar uma estrela no repositório!