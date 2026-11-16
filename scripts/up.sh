#!/usr/bin/env bash
# Sobe tudo no Kubernetes local (kind): infraestrutura, microsserviços, Kong e observabilidade.
# Uso (na pasta conexao-solidaria-orchestration, com os outros repositórios ao lado dela):
#   ./scripts/up.sh
# Requisitos: Docker em execução, kind 0.24+ e kubectl. No Windows, rode no Git Bash.
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
REPOS="$(dirname "$RAIZ")"
CLUSTER=conexao-solidaria
NS=conexao-solidaria
cd "$RAIZ"

passo() { printf '\n==> %s\n' "$1"; }
falha() { printf 'ERRO: %s\n' "$1" >&2; exit 1; }
# kubectl apply com nova tentativa: em máquina carregada o etcd do kind às vezes responde "request timed out".
aplicar_yaml() {
  for tentativa in 1 2 3 4 5; do
    kubectl apply "$@" && return 0
    echo "  (falhou; nova tentativa $tentativa/5 em 10 s)"
    sleep 10
  done
  return 1
}

for cmd in docker kind kubectl; do
  command -v "$cmd" >/dev/null || falha "$cmd não encontrado no PATH."
done
docker info >/dev/null 2>&1 || falha "o Docker não está em execução."
for repo in conexao-solidaria-campanhas-api conexao-solidaria-doacoes-worker conexao-solidaria-web; do
  [ -d "$REPOS/$repo/k8s" ] || falha "repositório $repo não encontrado ao lado deste ($REPOS/$repo)."
done

if [ ! -f .env ]; then
  cp .env.example .env
  echo "Criado .env a partir de .env.example (valores de demonstração)."
fi
# tr: tolera .env salvo com quebra de linha do Windows.
set -a; . <(tr -d '\r' < .env); set +a
: "${GESTOR_SENHA:=Gestao@2026}" "${GRAFANA_USER:=admin}" "${GRAFANA_PASSWORD:=Grafana@2026}"
: "${ZABBIX_PASSWORD:=Monitora@2026}" "${ZABBIX_DB_PASSWORD:=zabbix-dev}"

# As portas do cluster (8000, 15672, 3000, 8081, 9090) não podem estar em uso pelo Docker Compose.
if docker ps --format '{{.Names}}' | grep -q '^conexao-solidaria-kong-1$'; then
  falha "o ambiente do Docker Compose está rodando. Pare com: docker compose down"
fi

passo "Cluster kind"
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "Cluster $CLUSTER já existe."
else
  kind create cluster --config k8s/kind-config.yaml --wait 120s
fi
kubectl config use-context "kind-$CLUSTER" >/dev/null

passo "Namespace, segredos e configurações"
aplicar_yaml -f k8s/namespace.yaml
aplicar() { local yaml; yaml=$(cat); for _ in 1 2 3 4 5; do printf '%s\n' "$yaml" | kubectl -n "$NS" apply -f - >/dev/null && return 0; sleep 10; done; return 1; }
kubectl -n "$NS" create secret generic conexao-secrets --dry-run=client -o yaml \
  --from-literal=POSTGRES_USER="$POSTGRES_USER" \
  --from-literal=POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  --from-literal=POSTGRES_CONNECTION="Host=postgres;Database=conexao_solidaria;Username=$POSTGRES_USER;Password=$POSTGRES_PASSWORD" \
  --from-literal=RABBIT_USER="$RABBIT_USER" \
  --from-literal=RABBIT_PASS="$RABBIT_PASS" \
  --from-literal=JWT_SECRET="$JWT_SECRET" \
  --from-literal=GESTOR_SENHA="$GESTOR_SENHA" \
  --from-literal=GRAFANA_USER="$GRAFANA_USER" \
  --from-literal=GRAFANA_PASSWORD="$GRAFANA_PASSWORD" \
  --from-literal=ZABBIX_PASSWORD="$ZABBIX_PASSWORD" \
  --from-literal=ZABBIX_DB_PASSWORD="$ZABBIX_DB_PASSWORD" | aplicar
# kong.yml versionado só tem ${JWT_SECRET}; o valor entra aqui e fica apenas no cluster.
sed "s|\${JWT_SECRET}|$JWT_SECRET|g" kong/kong.yml > .kong.gerado.yml
kubectl -n "$NS" create configmap kong-config --from-file=kong.yml=.kong.gerado.yml --dry-run=client -o yaml | aplicar
rm -f .kong.gerado.yml
kubectl -n "$NS" create configmap rabbitmq-definitions --from-file=definitions.json=rabbitmq/definitions.json --dry-run=client -o yaml | aplicar
kubectl -n "$NS" create configmap grafana-dashboards --from-file=grafana/dashboards --dry-run=client -o yaml | aplicar
echo "ok"

passo "Infraestrutura: PostgreSQL, Redis, RabbitMQ"
aplicar_yaml -f k8s/infra/postgres.yaml -f k8s/infra/redis.yaml -f k8s/infra/rabbitmq.yaml
kubectl -n "$NS" rollout status statefulset/postgres --timeout=300s
kubectl -n "$NS" rollout status deployment/redis --timeout=300s
kubectl -n "$NS" rollout status deployment/rabbitmq --timeout=300s
kubectl -n "$NS" wait --for=condition=complete job/rabbitmq-init --timeout=300s

passo "Microsserviços: campanhas-api, doacoes-worker e site"
aplicar_yaml -f "$REPOS/conexao-solidaria-campanhas-api/k8s"
kubectl -n "$NS" rollout status deployment/campanhas-api --timeout=600s
# O worker usa as tabelas criadas pelas migrações da API: sobe depois dela.
aplicar_yaml -f "$REPOS/conexao-solidaria-doacoes-worker/k8s" -f "$REPOS/conexao-solidaria-web/k8s"
kubectl -n "$NS" rollout status deployment/doacoes-worker --timeout=600s
kubectl -n "$NS" rollout status deployment/web --timeout=300s

passo "API Gateway: Kong"
# Já existia: reinicia para reler o ConfigMap (o Kong DB-less só lê a configuração na subida).
existe() { kubectl -n "$NS" get deployment "$1" >/dev/null 2>&1; }
existe kong && KONG_EXISTIA=1 || KONG_EXISTIA=0
aplicar_yaml -f k8s/infra/kong.yaml
[ "$KONG_EXISTIA" = 1 ] && kubectl -n "$NS" rollout restart deployment/kong >/dev/null
kubectl -n "$NS" rollout status deployment/kong --timeout=300s

passo "Observabilidade: Prometheus, Grafana e Zabbix"
existe prometheus && OBS_EXISTIA=1 || OBS_EXISTIA=0
aplicar_yaml -f k8s/observabilidade/prometheus.yaml -f k8s/observabilidade/zabbix.yaml -f k8s/observabilidade/grafana.yaml
# Já existiam: reinicia para reler os ConfigMaps (configuração do Prometheus, dashboard do Grafana).
[ "$OBS_EXISTIA" = 1 ] && kubectl -n "$NS" rollout restart deployment/prometheus deployment/grafana >/dev/null
kubectl -n "$NS" rollout status deployment/prometheus --timeout=300s
kubectl -n "$NS" rollout status deployment/grafana --timeout=600s
kubectl -n "$NS" rollout status statefulset/zabbix-db --timeout=300s
kubectl -n "$NS" rollout status deployment/zabbix-server --timeout=600s
kubectl -n "$NS" rollout status deployment/zabbix-web --timeout=600s
# Job idempotente: recriado a cada subida para aplicar a configuração atual.
kubectl -n "$NS" delete job zabbix-setup --ignore-not-found >/dev/null
aplicar_yaml -f k8s/observabilidade/zabbix.yaml >/dev/null
kubectl -n "$NS" wait --for=condition=complete job/zabbix-setup --timeout=600s

passo "Pronto"
kubectl -n "$NS" get pods
cat <<EOF

  Site e API (Kong) ... http://localhost:8000          (Scalar: http://localhost:8000/scalar)
  RabbitMQ ............ http://localhost:15672         ($RABBIT_USER / senha do .env)
  Grafana ............. http://localhost:3000          ($GRAFANA_USER / senha do .env)
  Zabbix .............. http://localhost:8081          (Admin / ZABBIX_PASSWORD do .env)
  Prometheus .......... http://localhost:9090

  Gestora: helena@esperancasolidaria.demo / $GESTOR_SENHA
  Doadora: mariana@email.demo / Doar@2026
  Tráfego para o dashboard: ./scripts/gerar-trafego.sh
EOF
