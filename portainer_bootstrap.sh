#!/bin/bash
set -euo pipefail

# Portainer API bootstrap: cria admin, autentica e cria/atualiza stacks editáveis
# Usa 127.0.0.1:9000 para chamadas internas durante a instalação

# Dependências básicas
if ! command -v curl >/dev/null 2>&1; then
  echo "[Deps] Instalando curl..."
  if command -v apt >/dev/null 2>&1; then sudo apt update -y && sudo apt install -y curl; fi
  if command -v yum >/dev/null 2>&1; then sudo yum install -y curl; fi
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "[Deps] Instalando jq..."
  if command -v apt >/dev/null 2>&1; then sudo apt update -y && sudo apt install -y jq; fi
  if command -v yum >/dev/null 2>&1; then sudo yum install -y jq; fi
fi

[ -f .env ] && set -a && source .env && set +a

if [ -z "${PORTAINER_ADMIN_PASSWORD:-}" ]; then
  PORTAINER_ADMIN_PASSWORD="$(tr -dc 'A-Za-z0-9!@#%^&*' </dev/urandom | head -c 20)"
  echo "PORTAINER_ADMIN_PASSWORD=${PORTAINER_ADMIN_PASSWORD}" >> .env
fi

PORTAINER_URL="http://127.0.0.1:9000"
BASE_RAW_URL="https://raw.githubusercontent.com/lonardonetto/setupalicia/main/stacks"

fetch_stack_if_missing() {
  local filename="$1"
  if [ -f "${filename}" ]; then return; fi
  if [ -f "./stacks/${filename}" ]; then return; fi
  echo "[Stacks] Baixando template: ${filename}"
  mkdir -p ./stacks
  if curl -fsSL "${BASE_RAW_URL}/${filename}" -o "./stacks/${filename}"; then
    echo "[Stacks] Baixado ./stacks/${filename}"
  else
    echo "[Stacks] Template não encontrado remoto: ${filename} (seguirá sem esta stack)"
  fi
}

echo "[Portainer] Aguardando serviço..."
for i in $(seq 1 60); do
  if curl -fsS "${PORTAINER_URL}/api/system/status" >/dev/null 2>&1; then
    echo "[Portainer] Online."
    break
  fi
  sleep 2
  [ "$i" -eq 60 ] && { echo "[Portainer] Timeout"; exit 1; }
done

# Inicializar admin se necessário
curl -fsS -X POST "${PORTAINER_URL}/api/users/admin/init" \
  -H "Content-Type: application/json" \
  -d "{\"Password\": \"${PORTAINER_ADMIN_PASSWORD}\"}" \
  >/dev/null 2>&1 || true

# Autenticar
JWT="$(
  curl -fsS -X POST "${PORTAINER_URL}/api/auth" \
    -H "Content-Type: application/json" \
    -d "{\"Username\":\"admin\",\"Password\":\"${PORTAINER_ADMIN_PASSWORD}\"}" \
  | jq -r .jwt
)"
[ -z "${JWT}" ] || [ "${JWT}" = "null" ] && { echo "[Portainer] Falha auth"; exit 1; }

# Endpoint local
ENDPOINT_ID="$(
  curl -fsS "${PORTAINER_URL}/api/endpoints" -H "Authorization: Bearer ${JWT}" \
  | jq 'map(select(.Name=="local")) | .[0].Id'
)"
if [ -z "${ENDPOINT_ID}" ] || [ "${ENDPOINT_ID}" = "null" ]; then
  curl -fsS -X POST "${PORTAINER_URL}/api/endpoints" \
    -H "Authorization: Bearer ${JWT}" -H "Content-Type: application/json" \
    -d '{"Name":"local","EndpointCreationType":1,"URL":"unix:///var/run/docker.sock"}' >/dev/null
  ENDPOINT_ID="$(
    curl -fsS "${PORTAINER_URL}/api/endpoints" -H "Authorization: Bearer ${JWT}" \
    | jq 'map(select(.Name=="local")) | .[0].Id'
  )"
fi

echo "[Portainer] endpointId=${ENDPOINT_ID}"

# Swarm
SWARM_ID="$(docker info -f '{{.Swarm.Cluster.ID}}' 2>/dev/null || true)"
if [ -z "${SWARM_ID}" ]; then
  docker swarm init >/dev/null 2>&1 || true
  SWARM_ID="$(docker info -f '{{.Swarm.Cluster.ID}}')"
fi

create_or_update_stack() {
  local stack_name="$1"
  local file_path="$2"

  # tentar baixar template se não existir
  fetch_stack_if_missing "$(basename "${file_path}")"

  # tenta no caminho informado, depois em ./stacks/
  if [ ! -f "${file_path}" ]; then
    if [ -f "./stacks/$(basename "${file_path}")" ]; then
      file_path="./stacks/$(basename "${file_path}")"
    else
      echo "[Stack] Arquivo não encontrado: ${file_path} (ignorando ${stack_name})"
      return
    fi
  fi
  local content
  content="$(cat "${file_path}")"

  local existing_id
  existing_id="$(
    curl -fsS "${PORTAINER_URL}/api/stacks?endpointId=${ENDPOINT_ID}" -H "Authorization: Bearer ${JWT}" \
    | jq -r --arg n "${stack_name}" '.[] | select(.Name==$n) | .Id' | head -n1
  )"

  if [ -n "${existing_id}" ]; then
    echo "[Stack] Atualizando ${stack_name} (${existing_id})"
    curl -fsS -X PUT "${PORTAINER_URL}/api/stacks/${existing_id}?endpointId=${ENDPOINT_ID}" \
      -H "Authorization: Bearer ${JWT}" -H "Content-Type: application/json" \
      -d "$(jq -n --arg c "${content}" '{StackFileContent:$c, Prune:true}')" >/dev/null
  else
    echo "[Stack] Criando ${stack_name}"
    curl -fsS -X POST "${PORTAINER_URL}/api/stacks?type=3&method=string&endpointId=${ENDPOINT_ID}" \
      -H "Authorization: Bearer ${JWT}" -H "Content-Type: application/json" \
      -d "$(jq -n --arg name "${stack_name}" --arg content "${content}" --arg swarmId "${SWARM_ID}" '{Name:$name, SwarmID:$swarmId, StackFileContent:$content, Env: []}')" >/dev/null
  fi
}

# Ajuste os nomes/arquivos conforme seu projeto (se não existir, será ignorado)
create_or_update_stack "traefik" "traefik.yaml"
create_or_update_stack "portainer" "portainer.yaml"
create_or_update_stack "redis" "redis.yaml"
create_or_update_stack "postgres" "postgres.yaml"
create_or_update_stack "n8n" "n8n.yaml"
create_or_update_stack "evolution" "evolution_corrigido.yaml"

echo "[Portainer] Deploy via API concluído. Stacks editáveis na UI."
