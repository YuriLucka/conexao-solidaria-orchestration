#!/usr/bin/env bash
# Remove o cluster kind (e todos os dados dele). Uso: ./scripts/down.sh
set -euo pipefail
kind delete cluster --name conexao-solidaria
