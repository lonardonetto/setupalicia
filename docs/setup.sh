#!/usr/bin/env bash
set -Eeuo pipefail

RAW="https://raw.githubusercontent.com/lonardonetto/setupalicia/main/instalacao_corrigida.sh"

# Preserva o TTY e repassa só os argumentos reais (sem placeholder)
bash <(curl -fsSL "$RAW") "$@"
