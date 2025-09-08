# Comandos para subir para o GitHub

# 1. Inicializar repositório local
git init

# 2. Adicionar remote
git remote add origin https://github.com/lonardonetto/setupalicia.git

# 3. Adicionar todos os arquivos
git add .

# 4. Fazer commit inicial
git commit -m "🚀 Initial commit - SetupAlicia v2.7.1

✨ Features:
- SSL automático com Traefik + Let's Encrypt
- Instalação remota via URL
- Auto-atualização do script
- Interface simplificada
- Aplicações essenciais: Traefik, Portainer, Evolution, N8N, N8N+MCP

🔧 Setup:
- Verificação de pré-requisitos
- Instalação automática do Docker
- Configuração SSL completa
- Documentação detalhada"

# 5. Enviar para GitHub
git branch -M main
git push -u origin main

# 6. Configurar GitHub Pages (fazer manualmente no GitHub):
# - Ir em Settings → Pages
# - Source: Deploy from a branch
# - Branch: main
# - Folder: / (root)