#!/usr/bin/env bash
set -Eeuo pipefail

RAW="https://raw.githubusercontent.com/lonardonetto/setupalicia/main/instalacao_corrigida.sh"

# Baixa a versão oficial do instalador e repassa todos os argumentos
curl -fsSL "$RAW" | bash -s -- "$@"
