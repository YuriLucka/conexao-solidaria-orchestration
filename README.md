# Conexão Solidária

Plataforma de doações da ONG **Esperança Solidária**: campanhas de arrecadação, doações com processamento assíncrono e um painel público de transparência. Hackathon FIAP Pós Tech 11NETT, **Grupo 31**.

Este repositório é a **orquestração**: sobe a solução inteira (Kubernetes ou Docker Compose), o API Gateway, a observabilidade e reúne a documentação.

| Repositório | O que é |
|---|---|
| [conexao-solidaria-campanhas-api](https://github.com/YuriLucka/conexao-solidaria-campanhas-api) | Microsserviço de autenticação, doadores, campanhas, painel e intenção de doação (.NET 10) |
| [conexao-solidaria-doacoes-worker](https://github.com/YuriLucka/conexao-solidaria-doacoes-worker) | Microsserviço que consome a fila e soma as doações nas campanhas (.NET 10) |
| [conexao-solidaria-web](https://github.com/YuriLucka/conexao-solidaria-web) | Site (Blazor WebAssembly + MudBlazor), servido por nginx |
| **conexao-solidaria-orchestration** | Kubernetes (kind), Docker Compose, Kong, Prometheus, Grafana, Zabbix e documentação |

## Arquitetura

```
 Navegador / Postman
        │ http://localhost:8000
        ▼
 ┌──────────────┐   /            ┌─────────┐
 │  Kong 3.9    ├───────────────►│   web   │  nginx + Blazor WASM
 │  (JWT)       │   /api         └─────────┘
 │              ├──────────────► ┌───────────────┐  outbox   ┌──────────┐  consome  ┌────────────────┐
 └──────────────┘                │ campanhas-api ├──────────►│ RabbitMQ ├──────────►│ doacoes-worker │
                                 └──┬─────────┬──┘           └──────────┘           └──┬──────────┬──┘
                                    │ EF Core │ cache                        SQL atômico │          │ DEL cache
                                    ▼         ▼                                        ▼          │
                              ┌────────────┐ ┌─────────┐◄──────────────────────────────────────────┘
                              │ PostgreSQL │ │ Redis 7 │
                              │ 17 (X)     │ │ (Y)     │      Prometheus ─► Grafana ◄─ Zabbix 7.0 ─► zabbix-db
                              └────────────┘ └─────────┘      (/metrics)              (/health)
```

Diagrama técnico completo: [docs/arquitetura.md](docs/arquitetura.md).

**Fluxo da doação.** O doador chama `POST /api/doacoes`. A API grava a doação como `Pendente` e o evento `DoacaoRecebidaEvent` no outbox, na mesma transação, e responde `202`. O MassTransit entrega o evento na fila `doacao-recebida`. O `doacoes-worker` consome, soma o valor na campanha (transação com as linhas travadas, idempotente), marca a doação como `Processada` e apaga o cache do painel no Redis. **A API nunca altera o valor arrecadado.**

**Bancos.** PostgreSQL 17 (banco X) para usuários, campanhas e doações; Redis 7 (banco Y) como cache do painel público. Justificativa em [docs/bancos-de-dados.pdf](docs/bancos-de-dados.pdf) (texto também em [docs/bancos-de-dados.md](docs/bancos-de-dados.md)).

## Subir no Kubernetes (entrega)

Pré-requisitos: **Docker** em execução, **[kind](https://kind.sigs.k8s.io/) 0.24+**, **kubectl** e **Git**. No Windows, use o **Git Bash**. Memória livre recomendada para o Docker: 4 GB.

```bash
mkdir conexao-solidaria && cd conexao-solidaria
git clone https://github.com/YuriLucka/conexao-solidaria-orchestration.git
git clone https://github.com/YuriLucka/conexao-solidaria-campanhas-api.git
git clone https://github.com/YuriLucka/conexao-solidaria-doacoes-worker.git
git clone https://github.com/YuriLucka/conexao-solidaria-web.git

cd conexao-solidaria-orchestration
./scripts/up.sh
```

O script cria o cluster `conexao-solidaria`, os segredos (a partir do `.env`, criado do `.env.example` se não existir), a infraestrutura, os microsserviços (imagens públicas do GHCR, publicadas pelo CI), o Kong e a observabilidade. A primeira subida leva de 5 a 10 minutos (download das imagens).

| Endereço | O que é | Acesso |
|---|---|---|
| http://localhost:8000 | Site | gestora `helena@esperancasolidaria.demo` / `Gestao@2026` · doadora `mariana@email.demo` / `Doar@2026` |
| http://localhost:8000/scalar | Documentação interativa da API (OpenAPI) | botão Authorize com o token do login |
| http://localhost:15672 | RabbitMQ | `RABBIT_USER` / `RABBIT_PASS` do `.env` (`conexao` / `conexao-dev`) |
| http://localhost:3000 | Grafana (dashboard **Conexão Solidária**) | `GRAFANA_USER` / `GRAFANA_PASSWORD` (`admin` / `Grafana@2026`) |
| http://localhost:8081 | Zabbix | `Admin` / `ZABBIX_PASSWORD` (`Monitora@2026`) |
| http://localhost:9090 | Prometheus | sem login |

```bash
kubectl -n conexao-solidaria get pods        # tudo Running
./scripts/gerar-trafego.sh 30                # 30 doações reais pelo Kong para o dashboard mexer
./scripts/down.sh                            # apaga o cluster
```

### Mensagem parada na fila (roteiro do vídeo)

```bash
kubectl -n conexao-solidaria scale deploy/doacoes-worker --replicas=0
# faça uma doação pelo site ou Postman: 202, doação Pendente
# RabbitMQ > Queues > doacao-recebida: 1 mensagem em Ready (Get messages mostra o evento)
kubectl -n conexao-solidaria scale deploy/doacoes-worker --replicas=1
# a fila esvazia, a doação vira Processada e o painel mostra o valor novo
```

## Subir com Docker Compose (desenvolvimento)

Compila as imagens a partir dos repositórios ao lado. Use um ou outro: os dois publicam a porta 8000.

```bash
cp .env.example .env
docker compose up -d --build
```

Site e API em http://localhost:8000; RabbitMQ em http://localhost:15672. O Compose não sobe a observabilidade.

## Observabilidade

- **Prometheus** coleta, a cada 5 s, o `/metrics` da API e do worker (requisições, latência, CPU, memória, `doacoes_processadas_total`, `doacoes_valor_processado_reais_total`), do Kong e do RabbitMQ (mensagens na fila).
- **Grafana** abre direto no dashboard **Conexão Solidária**, provisionado em `grafana/dashboards/`: doações processadas e valor arrecadado ao vivo, fila e consumidores, requisições, p95, CPU e memória por serviço, requisições no Kong e a saúde vinda do Zabbix.
- **Zabbix 7.0 LTS**, com banco próprio (`zabbix-db`, PostgreSQL separado do banco X). O Job `zabbix-setup` configura tudo pela API do Zabbix: host **Conexão Solidária**, um item HTTP no `/health` de cada microsserviço e um alerta quando algum sai do ar. Para ver o alerta: `kubectl -n conexao-solidaria scale deploy/doacoes-worker --replicas=0` e aguarde cerca de 90 s.

## Segurança

- JWT HS256 de 15 minutos, conferido no Kong e na API; perfis `GestorONG` e `Doador` (403 fora do perfil).
- Refresh token de 7 dias em cookie HttpOnly (`SameSite=Strict`, `Path=/api/auth`), trocado a cada uso; o site mantém o JWT só em memória. Logout revoga a sessão no servidor.
- Senhas com BCrypt; CPF e e-mail únicos; segredos só no `.env` e em Secrets do Kubernetes, nunca no repositório.

## CI/CD

Cada repositório de serviço tem um GitHub Actions que, a cada push na `main`, compila, roda os testes (unidade e integração com Testcontainers) e publica a imagem no GHCR (`ghcr.io/yurilucka/...`, tags `latest` e `sha-<commit>`).

## Estrutura

```
docker-compose.yml        ambiente de desenvolvimento
kong/kong.yml             rotas e plugins do gateway (JWT, Prometheus)
rabbitmq/definitions.json fila doacao-recebida declarada antes da primeira doação
k8s/                      kind-config, namespace, infra (PostgreSQL, Redis, RabbitMQ, Kong), observabilidade
grafana/dashboards/       dashboard provisionado
scripts/                  up.sh, down.sh, gerar-trafego.sh
tools/carga/              dados de demonstração e de carga (SQL)
docs/                     arquitetura, bancos de dados (PDF), coleção Postman, plano, relatório de entrega
tools/docs/               gera o PDF dos bancos a partir do Markdown (python tools/docs/md_para_pdf.py ...)
```
