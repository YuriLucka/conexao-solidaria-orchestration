#!/usr/bin/env bash
# Gera tráfego real pelo Kong para o dashboard do Grafana mexer: leituras do painel e doações da doadora de demonstração.
# Uso: ./scripts/gerar-trafego.sh [quantidade de doações, padrão 30] [endereço, padrão http://localhost:8000]
set -euo pipefail

TOTAL="${1:-30}"
BASE="${2:-http://localhost:8000}"

json() { sed -n "s/.*\"$1\":\"\([^\"]*\)\".*/\1/p"; }

TOKEN=$(curl -fsS -H 'Content-Type: application/json' -d '{"email":"mariana@email.demo","senha":"Doar@2026"}' "$BASE/api/auth/login" | json accessToken)
[ -n "$TOKEN" ] || { echo "não foi possível entrar com a doadora de demonstração" >&2; exit 1; }

# Campanhas que ainda recebem doações (Ativa e no prazo).
mapfile -t CAMPANHAS < <(curl -fsS "$BASE/api/campanhas/ativas" | tr '{' '\n' | grep '"prazoEncerrado":false' | json id)
[ "${#CAMPANHAS[@]}" -gt 0 ] || { echo "nenhuma campanha recebendo doações" >&2; exit 1; }

echo "Enviando $TOTAL doações para ${#CAMPANHAS[@]} campanhas em $BASE ..."
for i in $(seq 1 "$TOTAL"); do
  CAMPANHA="${CAMPANHAS[$((RANDOM % ${#CAMPANHAS[@]}))]}"
  VALOR="$((RANDOM % 200 + 10)).$((RANDOM % 90 + 10))"
  STATUS=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
    -d "{\"idCampanha\":\"$CAMPANHA\",\"valorDoacao\":$VALOR}" "$BASE/api/doacoes")
  # Leituras do painel público entre uma doação e outra (cache no Redis).
  for _ in 1 2 3; do curl -s -o /dev/null "$BASE/api/campanhas/ativas"; done
  printf '  %3d/%d  R$ %-7s  HTTP %s\n' "$i" "$TOTAL" "$VALOR" "$STATUS"
  sleep 1
done
echo "Pronto. Veja em http://localhost:3000 (dashboard Conexão Solidária)."
