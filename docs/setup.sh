#!/usr/bin/env bash
set -Eeuo pipefail

RAW="https://raw.githubusercontent.com/lonardonetto/setupalicia/main/instalacao_corrigida.sh"

# Preserva o TTY para o menu interativo
bash <(curl -fsSL "$RAW") -- "$@"
