# Comandos para subir para o GitHub

# 1. Inicializar repositório local
git init

# 2. Adicionar remote
git remote add origin https://github.com/lonardonetto/setupalicia.git

# 3. Adicionar todos os arquivos
git add .

# 4. Fazer commit com as correções da v0.2
git commit -m "🚀 Update install_n8n_evolution.sh to v0.2 - PostgreSQL Auth Fix

✨ New Features:
- ✅ Fixed critical PostgreSQL authentication errors
- 🕰️ Improved service synchronization and timing
- 🐛 Evolution API v2.2.3 with optimized configuration
- 🔍 Automatic health checks for all services
- 🔄 Auto-restart policy for service recovery
- 📊 Better UX with detailed messages and troubleshooting
- 🔐 Secure password and API key generation

🔧 Technical Fixes:
- Wait for PostgreSQL to be 100% operational before creating databases
- Active Redis verification before Evolution API deployment
- Fallback to local config file if download fails
- Persistent data configuration enabled
- Enhanced error handling and logging

📱 Applications:
- Traefik with automatic SSL
- Portainer for Docker management
- PostgreSQL with corrected authentication
- Redis for caching and queues
- Evolution API v2.2.3 for WhatsApp integration
- N8N for workflow automation
- Health monitoring for all services"

# 5. Enviar para GitHub
git branch -M main
git push -u origin main

# 6. Configurar GitHub Pages (fazer manualmente no GitHub):
# - Ir em Settings → Pages
# - Source: Deploy from a branch
# - Branch: main
# - Folder: / (root)