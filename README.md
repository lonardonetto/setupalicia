# 🚀 SetupAlicia - Instalador Automatizado com SSL CORRIGIDO

## 🎆 NOVIDADE: Portainer Totalmente Automatizado + Stacks Editáveis

### ✅ **CONFIGURAÇÃO AUTOMÁTICA DO PORTAINER:**
- **👤 Conta criada automaticamente**: `setupalicia` + senha gerada
- **🔑 API Key criada automaticamente** para stacks editáveis
- **📝 Credenciais exibidas no final** da instalação
- **⏱️ Zero timeout** - não precisa configurar em 5 minutos

### 🚀 **STACKS EDITÁVEIS AUTOMATICAMENTE:**
- **Antes**: Stacks via CLI = não editáveis
- **Agora**: Stacks via API = **TOTALMENTE EDITÁVEIS** no Portainer
- **Método**: Click na stack > Editor > Alterar > Update
- **Fallback**: Se API falhar, usa CLI + backup dos YAMLs

### 📁 **Stacks Automaticamente Editáveis:**
- `postgres` - Banco de dados ✅
- `redis` - Cache ✅
- `evolution` - WhatsApp API ✅
- `n8n` - Automação ✅
- `traefik` + `portainer` - Via CLI (bootstrap necessário)

---

Instalador DEFINITIVO para aplicações essenciais com SSL automático via Traefik + Let's Encrypt.

## ⚡ INSTALAÇÃO CORRIGIDA - SSL FUNCIONANDO 100%

### ✅ COMANDO ÚNICO CORRIGIDO (FUNCIONA DE PRIMEIRA):
```bash
bash <(curl -sSL https://raw.githubusercontent.com/lonardonetto/setupalicia/main/instalacao_corrigida.sh) \
"seu@email.com" \
"editor.seudominio.com" \
"painel.seudominio.com" \
"webhook.seudominio.com" \
"evo.seudominio.com"
```

### 🎯 OU USE O MENU INTERATIVO:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/lonardonetto/setupalicia/main/instalacao_corrigida.sh)
```

**🎯 OPÇÕES DO MENU:**
1. **📦 Instalação Completa** - Instala todos os serviços
2. **🔄 Reset Portainer** - Resolve timeout de 5 minutos
3. **🔐 Fix SSL** - Força certificados pendentes
4. **📊 Status** - Mostra status de todos os serviços

## 🎊 CORREÇÕES IMPLEMENTADAS:

### ✅ **PROBLEMA SSL RESOLVIDO:**
- **Redirecionamento HTTP→HTTPS CORRIGIDO** em todos os serviços
- **Tempos de SSL aumentados** de 3 para 15+ minutos
- **Labels Traefik padronizadas** para Portainer, N8N e Evolution
- **Agora funciona sem precisar digitar https://**

### 🧹 **LIMPEZA REALIZADA:**
- Removidos 20+ arquivos desnecessários 
- Mantidos apenas os essenciais
- Repositório mais limpo e organizado

## 📦 Aplicações Incluídas

### SetupAlicia Principal (instalacao_corrigida.sh)
- **🔒 Traefik** - Proxy reverso com SSL automático + REDIRECIONAMENTO HTTP→HTTPS
- **🐳 Portainer** - Interface de gerenciamento Docker  
- **📱 Evolution API v2.2.3** - API para WhatsApp com banco PostgreSQL
- **🔄 N8N** - Automação de workflows
- **🗿 PostgreSQL** - Banco de dados robusto
- **♾️ Redis** - Cache e filas

## ✨ Recursos CORRIGIDOS

- ✅ **SSL automático com Let's Encrypt**
- ✅ **Renovação automática de certificados**
- ✅ **Redirecionamento HTTP → HTTPS FUNCIONANDO**  
- ✅ **Interface simplificada com menu**
- ✅ **Atualização automática do script**
- ✅ **Verificação de pré-requisitos**
- ✅ **Instalação automática do Docker**
- ✅ **Tempos de SSL aumentados para 15+ minutos**

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

### 🚀 Instalação Definitiva (install_definitivo.sh) - NOVO!
**🎯 Grandes Melhorias:**
- ✅ **Instalação que FUNCIONA**: Script testado e otimizado para garantir que todos os serviços funcionem
- 🕰️ **Sequência otimizada**: Deploy dos serviços na ordem correta com aguardo inteligente
- 🔍 **Verificação rigorosa**: Cada serviço é testado antes de continuar para o próximo
- 📱 **Evolution API garantida**: Configuração especial para garantir que a Evolution API funcione
- ⚙️ **Health checks**: Monitoramento ativo da saúde de todos os serviços
- 📊 **Diagnósticos detalhados**: Relatórios completos do status de cada componente
- 🔄 **Auto-recovery**: Mecanismos de recuperação automática para falhas comuns

**🔧 Correções Técnicas:**
- Função wait_service_ready com timeouts adequados para cada serviço
- Verificação ativa de PostgreSQL e Redis antes da Evolution API
- Criação automática e verificação de bancos de dados
- Configuração otimizada de recursos e políticas de restart
- Health checks nativos do Docker para monitoramento contínuo

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