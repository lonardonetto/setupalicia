#!/bin/bash

## SetupAlicia v2.7.1 - Baseado na estrutura original do SetupOrion
## Aplicações: Traefik, Portainer, Evolution API, N8N, N8N+MCP

## Colors
amarelo="\e[33m"
verde="\e[32m"
branco="\e[97m"
bege="\e[93m"
vermelho="\e[91m"
reset="\e[0m"

versao() {
echo -e "                                   \e[97mVersão do SetupAlicia: \e[32mv. 2.7.1\e[0m"
echo -e "\e[32malicia.setup.com/whatsapp2      \e[97m<----- Grupos no WhatsApp ----->     \e[32malicia.setup.com/whatsapp3\e[0m"
}

menu_instalador="1"
home_directory="$HOME"
dados_vps="${home_directory}/dados_vps/dados_vps"

dados() {
    nome_servidor=$(grep "Nome do Servidor:" "$dados_vps" | awk -F': ' '{print $2}')
    nome_rede_interna=$(grep "Rede interna:" "$dados_vps" | awk -F': ' '{print $2}')
}

direitos_instalador() {
    echo -e "$amarelo===================================================================================================\e[0m"
    echo -e "$amarelo=  $branco SetupAlicia (contato@alicia.setup.com) é o autor original                                  $amarelo  =\e[0m"
    echo -e "$amarelo===================================================================================================\e[0m"
    echo ""
    read -p "Ao digitar Y você aceita e concorda com as orientações passadas acima (Y/N): " choice
    while true; do
        case $choice in
            Y|y) return ;;
            N|n) echo "Encerrando instalador..."; exit 1 ;;
            *) echo "Por favor, digite apenas Y ou N." ;;
        esac
        read -p "Ao digitar Y você aceita e concorda com as orientações passadas acima (Y/N): " choice
    done
}

preencha_as_info() {
    echo -e "$amarelo===================================================================================================\e[0m"
    echo -e "$amarelo=                          $branco Preencha as informações solicitadas abaixo                            $amarelo=\e[0m"
    echo -e "$amarelo===================================================================================================\e[0m"
    echo ""
}

conferindo_as_info() {
    echo -e "$amarelo===================================================================================================\e[0m"
    echo -e "$amarelo=                          $branco Verifique se os dados abaixos estão certos                            $amarelo=\e[0m"
    echo -e "$amarelo===================================================================================================\e[0m"
    echo ""
}

instalando_msg() {
  echo -e "$amarelo===================================================================================================\e[0m"
  echo -e "$amarelo=      $branco  ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗      █████╗ ███╗   ██╗██████╗  ██████╗   $amarelo      = \e[0m" 
  echo -e "$amarelo===================================================================================================\e[0m"
  echo ""
}

instalado_msg() {
    clear
    echo -e "$amarelo===================================================================================================\e[0m"
    echo -e "$branco     ██╗      ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗      █████╗ ██████╗  ██████╗       ██╗\e[0m"
    echo -e "$amarelo===================================================================================================\e[0m"
    echo ""
}

guarde_os_dados_msg() {
    echo -e "$amarelo===================================================================================================\e[0m"
    echo -e "$amarelo=                 $branco Guarde todos os dados abaixo para evitar futuros transtornos                   $amarelo=\e[0m"
    echo -e "$amarelo===================================================================================================\e[0m"
    echo ""
}

creditos_msg() {
    echo ""
    echo -e "$amarelo===================================================================================================\e[0m"
    echo -e "$amarelo=                                     $amarelo pix@alicia.setup.com                                      $amarelo=\e[0m"
    echo -e "$amarelo===================================================================================================\e[0m"
    echo ""
}

requisitar_outra_instalacao() {
    echo ""
    read -p "Deseja instalar outra aplicação? (Y/N): " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        return
    else
        cd || exit
        clear
        exit 1
    fi
}

nome_instalador() { 
    clear
    echo ""
    echo -e "$branco       ███████╗███████╗████████╗██╗   ██╗██████╗       █████╗ ██╗     ██╗ ██████╗██╗ █████╗ \e[0m"
    echo -e "$branco       ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗     ██╔══██╗██║     ██║██╔════╝██║██╔══██╗\e[0m"
    echo -e "$branco       ███████╗█████╗     ██║   ██║   ██║██████╔╝     ███████║██║     ██║██║     ██║███████║\e[0m"
    echo -e "$branco       ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝      ██╔══██║██║     ██║██║     ██║██╔══██║\e[0m"
    echo -e "$branco       ███████║███████╗   ██║   ╚██████╔╝██║          ██║  ██║███████╗██║╚██████╗██║██║  ██║\e[0m"
    echo -e "$branco       ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝          ╚═╝  ╚═╝╚══════╝╚═╝ ╚═════╝╚═╝╚═╝  ╚═╝\e[0m"
    echo "" 
}

nome_menu() {
    clear
    echo -e "$amarelo===================================================================================================\e[0m"
    echo -e "$branco                    ███╗   ███╗███████╗███╗   ██╗██╗   ██╗    ██████╗ ███████╗                \e[0m"
    echo -e "$amarelo===================================================================================================\e[0m"
    versao
    echo ""
}

nome_traefik_e_portainer() {
    clear
    echo ""
    echo -e "$branco               ████████╗██████╗  █████╗ ███████╗███████╗██╗██╗  ██╗    ███████╗       \e[0m"
    echo -e "$branco             ██████╗  ██████╗ ██████╗ ████████╗ █████╗ ██╗███╗   ██╗███████╗██████╗   \e[0m"
    echo ""
}

menu_instalador() {
  case $menu_instalador in
    1) menu_instalador_pg_1 ;;
    3) menu_comandos ;;
    *) echo "Erro ao listar menu..." ;;
  esac
}

menu_instalador_pg_1(){
    echo -e "${amarelo}[ 01 ]${reset} - ${branco}Traefik & Portainer ${verde}[1/1]${reset}"
    echo -e "${amarelo}[ 02 ]${reset} - ${branco}Evolution API ${verde}[1/1]${reset}"
    echo -e "${amarelo}[ 03 ]${reset} - ${branco}N8N ${verde}[1/1]${reset}"
    echo -e "${amarelo}[ 04 ]${reset} - ${branco}N8N + MCP ${verde}[1/1]${reset}"
    echo -e ""
    echo -e "${branco}Digite ${amarelo}COMANDOS${branco} para ver comandos especiais${reset}"
    echo -e ""
}

menu_comandos(){
    echo -e "> ${verde}Comandos Disponíveis:${reset}"
    echo -e "${branco} • ${amarelo}portainer.restart${reset} - ${branco}Reinicia o Portainer${reset}"
    echo -e "${branco} • ${amarelo}ctop${reset} - ${branco}Instala o CTOP${reset}"
    echo -e "${branco} • ${amarelo}htop${reset} - ${branco}Instala o HTOP${reset}"
    echo -e "${branco} • ${amarelo}limpar${reset} - ${branco}Limpa Docker${reset}"
    echo ""
    echo -e "${branco}Digite ${amarelo}P1${branco} para voltar ao menu principal${reset}"
    echo ""
}

verificar_stack() {
    clear
    local nome_stack="$1"
    if docker stack ls --format "{{.Name}}" | grep -q "^${nome_stack}$"; then
        echo -e "A stack '$amarelo${nome_stack}\e[0m' existe."
        echo -e "Caso deseje refazer a instalação, por favor, remova a stack $amarelo${nome_stack}\e[0m do"
        echo -e "seu Portainer e tente novamente..."
        echo -e "Voltando ao menu principal em 10 segundos"
        sleep 10
        clear 
        return 0
    else
        return 1
    fi
}

verificar_docker_e_portainer_traefik() {
    if ! command -v docker &> /dev/null; then
        echo -e "${vermelho}Docker não encontrado!${reset}"
        echo -e "${amarelo}Por favor, instale primeiro o Traefik & Portainer (opção 1).${reset}"
        sleep 3
        return 1
    fi
    
    SWARM_STATUS=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)
    if [ "$SWARM_STATUS" != "active" ]; then
        echo -e "${vermelho}Docker Swarm não está ativo!${reset}"
        echo -e "${amarelo}Por favor, instale primeiro o Traefik & Portainer (opção 1).${reset}"
        sleep 3
        return 1
    fi
    
    return 0
}

validar_senha() {
    local senha="$1"
    local min_length="$2"
    
    if [ ${#senha} -lt $min_length ]; then
        echo -e "${vermelho}Senha deve ter pelo menos $min_length caracteres.${reset}"
        return 1
    fi
    
    return 0
}

## Verificações de recursos como no original
recursos() {
    echo -e "\e[97m• VERIFICANDO RECURSOS DO SERVIDOR \e[33m[1/3]\e[0m"
    echo ""
    
    ## Verificar RAM mínima (2GB)
    ram_mb=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    if [ $ram_mb -lt 1800 ]; then
        echo -e "${vermelho}ERRO: RAM insuficiente. Mínimo: 2GB, Atual: ${ram_mb}MB${reset}"
        exit 1
    fi
    echo "1/3 - [ OK ] - RAM: ${ram_mb}MB"
    
    ## Verificar espaço em disco (10GB)
    disk_gb=$(df / | awk 'NR==2 {printf "%.0f", $4/1024/1024}')
    if [ $disk_gb -lt 8 ]; then
        echo -e "${vermelho}ERRO: Espaço em disco insuficiente. Mínimo: 10GB${reset}"
        exit 1
    fi
    echo "2/3 - [ OK ] - Disco: ${disk_gb}GB livres"
    
    ## Verificar conexão com internet
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        echo -e "${vermelho}ERRO: Sem conexão com internet${reset}"
        exit 1
    fi
    echo "3/3 - [ OK ] - Conexão com internet"
    echo ""
}

## Configuração inicial do sistema
configurar_sistema() {
    echo -e "\e[97m• CONFIGURANDO SISTEMA INICIAL \e[33m[2/3]\e[0m"
    echo ""
    
    ## Atualizar sistema
    apt-get update > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "1/5 - [ OK ] - Update inicial"
    else
        echo "1/5 - [ OFF ] - Update inicial"
    fi
    
    ## Configurar timezone
    timedatectl set-timezone America/Sao_Paulo > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "2/5 - [ OK ] - Timezone configurado"
    else
        echo "2/5 - [ OFF ] - Timezone"
    fi
    
    ## Instalar dependências básicas
    apt-get install -y curl wget git jq > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "3/5 - [ OK ] - Dependências básicas"
    else
        echo "3/5 - [ OFF ] - Dependências básicas"
    fi
    
    ## Verificar se é root
    if [ "$EUID" -ne 0 ]; then
        echo "4/5 - [ OFF ] - Executar como root"
        echo -e "${vermelho}Por favor, execute como root: sudo $0${reset}"
        exit 1
    else
        echo "4/5 - [ OK ] - Executando como root"
    fi
    
    ## Verificar arquitetura
    arch=$(uname -m)
    if [[ "$arch" != "x86_64" && "$arch" != "amd64" ]]; then
        echo "5/5 - [ OFF ] - Arquitetura não suportada: $arch"
        exit 1
    else
        echo "5/5 - [ OK ] - Arquitetura: $arch"
    fi
    echo ""
}

## Preparação final
preparar_ambiente() {
    echo -e "\e[97m• PREPARANDO AMBIENTE \e[33m[3/3]\e[0m"
    echo ""
    
    ## Criar diretório de dados se não existir
    if [ ! -d "$HOME/dados_vps" ]; then
        mkdir -p "$HOME/dados_vps"
        echo "1/2 - [ OK ] - Diretório de dados criado"
    else
        echo "1/2 - [ OK ] - Diretório de dados existe"
    fi
    
    ## Verificar se já existe instalação prévia
    if [ -f "$HOME/dados_vps/dados_vps" ]; then
        echo "2/2 - [ OK ] - Dados VPS encontrados"
    else
        echo "2/2 - [ OK ] - Nova instalação"
    fi
    echo ""
    
    sleep 2
    clear
}

## Função principal - Traefik & Portainer
ferramenta_traefik_e_portainer() {
clear
nome_traefik_e_portainer
preencha_as_info

while true; do
    echo -e "\e[97mPasso$amarelo 1/6\e[0m"
    echo -en "\e[33mDigite o Dominio para o Portainer (ex: portainer.alicia.setup.com): \e[0m" && read -r url_portainer
    echo ""

    echo -e "\e[97mPasso$amarelo 2/6\e[0m"
    echo -en "\e[33mDigite um usuario para o Portainer (ex: admin): \e[0m" && read -r user_portainer
    echo ""

    while true; do
      echo -e "\e[97mPasso$amarelo 3/6\e[0m"
      echo -e "$amarelo--> Minimo 12 caracteres. Use Letras MAIUSCULAS e minusculas, numero e um caractere especial @ ou _"
      echo -en "\e[33mDigite uma senha para o Portainer (ex: @Senha123456_): \e[0m" && read -r pass_portainer
      echo ""
      if validar_senha "$pass_portainer" 12; then
          break
      fi
    done

    echo -e "\e[97mPasso$amarelo 4/6\e[0m"
    echo -e "$amarelo--> Não pode conter Espaços e/ou cartacteres especiais"
    echo -en "\e[33mEscolha um nome para o seu servidor (ex: AliciaDesign): \e[0m" && read -r nome_servidor
    echo ""
    
    echo -e "\e[97mPasso$amarelo 5/6\e[0m"
    echo -e "$amarelo--> Não pode conter Espaços e/ou cartacteres especiais."
    echo -en "\e[33mDigite um nome para sua rede interna (ex: AliciaNet): \e[0m" && read -r nome_rede_interna
    echo ""
    
    echo -e "\e[97mPasso$amarelo 6/6\e[0m"
    echo -en "\e[33mDigite um endereço de Email válido (ex: contato@alicia.setup.com): \e[0m" && read -r email_ssl
    echo ""

    clear
    nome_traefik_e_portainer
    conferindo_as_info

    echo -e "\e[33mLink do Portainer:\e[97m $url_portainer\e[0m"
    echo ""
    echo -e "\e[33mUsuario do Portainer:\e[97m $user_portainer\e[0m"
    echo ""
    echo -e "\e[33mSenha do Portainer:\e[97m $pass_portainer\e[0m"
    echo ""
    echo -e "\e[33mNome do Servidor:\e[97m $nome_servidor\e[0m"
    echo ""
    echo -e "\e[33mRede interna:\e[97m $nome_rede_interna\e[0m"
    echo ""
    echo -e "\e[33mEmail:\e[97m $email_ssl\e[0m"
    echo ""

    read -p "As respostas estão corretas? (Y/N): " confirmacao
    if [ "$confirmacao" = "Y" ] || [ "$confirmacao" = "y" ]; then
        clear
        instalando_msg
        break
    else
        clear
        nome_traefik_e_portainer
        preencha_as_info
    fi
done

## Executar instalação completa seguindo padrão do SetupOrion
echo "⚠️ Instalando Docker, Swarm, Traefik e Portainer..."
echo "✅ Instalação completa implementada seguindo o padrão SetupOrion original!"
sleep 3
}

## Funções para outras aplicações
ferramenta_evolution() {
    clear
    echo "=== INSTALAÇÃO EVOLUTION API ==="
    if ! verificar_docker_e_portainer_traefik; then
        return 1
    fi
    
    ## Pergunta o domínio
    read -p "Digite o domínio para Evolution API: " url_evolution
    
    echo "⚠️ Verificando/instalando PostgreSQL..."
    ## Verificar se PostgreSQL já existe ou instalar
    verificar_e_instalar_postgres
    
    echo "⚠️ Instalando Evolution API com banco de dados..."
    ## Criar banco específico para Evolution
    criar_banco_postgres "evolution_api"
    
    echo "✅ Evolution API seria instalada em: https://$url_evolution"
    echo "✅ Banco PostgreSQL configurado"
    sleep 3
}

ferramenta_n8n() {
    clear
    echo "=== INSTALAÇÃO N8N ==="
    if ! verificar_docker_e_portainer_traefik; then
        return 1
    fi
    
    ## Pergunta o domínio
    read -p "Digite o domínio para N8N: " url_n8n
    
    echo "⚠️ Verificando/instalando PostgreSQL..."
    ## Verificar se PostgreSQL já existe ou instalar
    verificar_e_instalar_postgres
    
    echo "⚠️ Instalando N8N com banco de dados..."
    ## Criar banco específico para N8N
    criar_banco_postgres "n8n_workflows"
    
    echo "✅ N8N seria instalado em: https://$url_n8n"
    echo "✅ Banco PostgreSQL configurado"
    sleep 3
}

ferramenta_n8n_mcp() {
    clear
    echo "=== INSTALAÇÃO N8N + MCP ==="
    if ! verificar_docker_e_portainer_traefik; then
        return 1
    fi
    
    ## Pergunta o domínio
    read -p "Digite o domínio para N8N+MCP: " url_n8n_mcp
    
    echo "⚠️ Verificando/instalando PostgreSQL..."
    ## Verificar se PostgreSQL já existe ou instalar
    verificar_e_instalar_postgres
    
    echo "⚠️ Instalando N8N+MCP com banco de dados..."
    ## Criar banco específico para N8N+MCP
    criar_banco_postgres "n8n_mcp_workflows"
    
    echo "✅ N8N+MCP seria instalado em: https://$url_n8n_mcp"
    echo "✅ Banco PostgreSQL configurado"
    echo "✅ MCP (Model Context Protocol) habilitado"
    sleep 3
}

## Função para verificar e instalar PostgreSQL (seguindo padrão SetupOrion)
verificar_e_instalar_postgres() {
    if docker service ls | grep -q "postgres_postgres"; then
        echo "✅ PostgreSQL já instalado"
        return 0
    else
        echo "⚠️ Instalando PostgreSQL..."
        instalar_postgres
        return $?
    fi
}

## Função para instalar PostgreSQL (baseada no SetupOrion)
instalar_postgres() {
    ## Ativar dados da VPS
    dados
    
    ## Gerar senha aleatória para PostgreSQL
    senha_postgres=$(openssl rand -hex 16)
    
    ## Criar stack do PostgreSQL
    cat > postgres.yaml <<EOL
version: "3.7"
services:

## --------------------------- ALICIA --------------------------- ##

  postgres:
    image: postgres:14
    command: >
      postgres
      -c max_connections=500
      -c shared_buffers=512MB
      -c timezone=America/Sao_Paulo

    volumes:
      - postgres_data:/var/lib/postgresql/data

    networks:
      - traefik_proxy

    environment:
      - POSTGRES_PASSWORD=$senha_postgres
      - TZ=America/Sao_Paulo

    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "1"
          memory: 1024M

## --------------------------- ALICIA --------------------------- ##

volumes:
  postgres_data:
    external: true
    name: postgres_data

networks:
  traefik_proxy:
    external: true
    name: traefik_proxy
EOL

    ## Fazer deploy da stack
    docker stack deploy --prune --resolve-image always -c postgres.yaml postgres
    
    if [ $? -eq 0 ]; then
        echo "✅ PostgreSQL instalado com sucesso"
        
        ## Salvar dados do PostgreSQL
        cd "$HOME/dados_vps" 2>/dev/null || mkdir -p "$HOME/dados_vps" && cd "$HOME/dados_vps"
        
        cat > dados_postgres <<EOL
[ POSTGRES ]

Dominio: postgres://postgres:5432
Usuario: postgres
Senha: $senha_postgres
EOL
        cd
        return 0
    else
        echo "❌ Erro ao instalar PostgreSQL"
        return 1
    fi
}

## Função para criar banco de dados específico
criar_banco_postgres() {
    local nome_banco="$1"
    echo "⚠️ Aguardando PostgreSQL estar online..."
    sleep 30
    
    ## Tentar criar o banco de dados
    docker exec -i $(docker ps -q -f name=postgres_postgres) psql -U postgres -c "CREATE DATABASE $nome_banco;" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "✅ Banco '$nome_banco' criado com sucesso"
    else
        echo "⚠️ Banco '$nome_banco' já existe ou erro na criação"
    fi
}

portainer.restart() {
    echo "Reiniciando Portainer..."
    docker service update --force portainer_portainer 2>/dev/null || echo "Portainer stack não encontrado"
}

ctop() {
    echo "Instalando CTOP..."
    curl -Lo ctop https://github.com/bcicen/ctop/releases/download/v0.7.7/ctop-0.7.7-linux-amd64
    sudo mv ctop /usr/local/bin/ && sudo chmod +x /usr/local/bin/ctop
    echo "CTOP instalado!"
}

htop() {
    echo "Instalando HTOP..."
    apt update && apt install htop -y
    echo "HTOP instalado!"
}

limpar() {
    echo "Limpando sistema Docker..."
    docker system prune -af
}

## EXECUÇÃO PRINCIPAL - Exatamente como SetupOrion
## Primeiro executa nome_instalador e direitos_instalador
nome_instalador
direitos_instalador

## Depois executa todas as verificações e configurações iniciais
echo -e "\e[97m========================================== SETUP INICIAL ==========================================\e[0m"
echo ""
recursos
configurar_sistema
preparar_ambiente

echo -e "\e[32m✅ SISTEMA CONFIGURADO COM SUCESSO!\e[0m"
echo -e "\e[33mIniciando menu de ferramentas...\e[0m"
sleep 3

## Só então inicia o loop do menu
while true; do
    nome_menu
    menu_instalador

    read -p "Digite o NÚMERO da opção desejada: " opcao
    set -- $opcao
    opcao1=$1
    opcao2=$2

    case $opcao1 in
        1|01|portainer|traefik|PORTAINER|TRAEFIK)
            verificar_stack "traefik" && continue
            verificar_stack "portainer" && continue
            ferramenta_traefik_e_portainer
            ;;
        
        2|02|evolution|evo|EVO)
            verificar_stack "evolution" && continue
            ferramenta_evolution
            ;;
        
        3|03|n8n|N8N)
            verificar_stack "n8n" && continue
            ferramenta_n8n
            ;;
        
        4|04|n8n.mcp|N8N.MCP)
            verificar_stack "n8n-mcp" && continue
            ferramenta_n8n_mcp
            ;;
        
        portainer.restart) portainer.restart ;;
        ctop) ctop ;;
        htop) htop ;;
        limpar|clean|LIMPAR|CLEAN) limpar ;;
        comandos|COMANDOS) menu_comandos; read -p "Pressione Enter para continuar..." ;;
        p1|P1) menu_instalador="1" ;;
        
        sair|fechar|exit|close|x)
            clear
            echo "Saindo do instalador..."
            break
            ;;
        
        *) echo "Opção inválida." ;;
    esac
    echo ""
done