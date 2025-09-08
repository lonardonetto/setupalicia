# 🚀 SetupAlicia - Instalador Automatizado com SSL

Instalador simplificado para aplicações essenciais com SSL automático via Traefik + Let's Encrypt.

## ⚡ Instalação Rápida

```bash
bash <(curl -sSL https://raw.githubusercontent.com/lonardonetto/setupalicia/main/setup.sh)
```

## 📦 Aplicações Incluídas

- **🔒 Traefik** - Proxy reverso com SSL automático
- **🐳 Portainer** - Interface de gerenciamento Docker  
- **📱 Evolution API** - API para WhatsApp
- **🔄 N8N** - Automação de workflows
- **🤖 N8N + MCP** - N8N com Model Context Protocol

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

## 🔐 Segurança SSL

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