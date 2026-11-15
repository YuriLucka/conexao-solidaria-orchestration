# Plano de desenvolvimento: Conexão Solidária (Hackathon 11NETT, Fase 5)

Versão 2, 14/11/2026 (atualizada com o andamento na seção 12). Substitui a v1 depois da validação por 4 agentes (leitura do enunciado, auditoria do plano, material do grupo vs. enunciado, checagem técnica com testes na máquina).

**Documento oficial único:** `HACKATHON 11NETT.pdf`. A pasta `Desktop/Hackathon` (protótipo, documentação técnica, marca, mascote) é material do grupo: referência visual e de fluxo, não requisito.

## 1. Regras do plano

1. **Obrigatório primeiro.** O caminho obrigatório (API, worker, mensageria, Kubernetes, observabilidade, CI, documentos, vídeo) nunca espera um item extra.
2. **Extras só se o PDF permitir.** Cada extra abaixo foi conferido: nenhum contraria o enunciado.
3. **Marcação:** `[O]` obrigatório · `[B]` bônus do PDF · `[OP]` opcional do PDF · `[G]` decisão do grupo (não pedido, permitido).
4. **Reaproveitar a FCG.** Mesma arquitetura em camadas, MassTransit, Kong, Prometheus/Grafana, padrões de Dockerfile, k8s e CI.
5. **Professor sobe tudo do zero** seguindo um README, sem precisar instalar .NET (imagens prontas no GHCR).

## 2. Matriz de requisitos (só o PDF)

### 2.1 Funcionais `[O]`

| # | PDF | Como atendemos | Prova no vídeo |
|---|---|---|---|
| RF1 | JWT; perfis `GestorONG` e `Doador`; gestão só para `GestorONG` | `POST /api/auth/login`; claim `role`; `[Authorize(Roles = "GestorONG")]` | d.i: token da gestora e do doador; 403 com token de doador |
| RF2 | Criar/Editar campanha: Titulo, Descricao, DataInicio, DataFim, MetaFinanceira, Status (Ativa, Concluida, Cancelada); DataFim não no passado; meta > 0 | `POST /api/campanhas` (sempre cria `Ativa`), `PUT /api/campanhas/{id}` (edita tudo, inclusive status) | d.ii: 400 (data passada, meta 0) e 201 |
| RF3 | Cadastro público: Nome Completo, Email único, CPF (formato), Senha com hash (BCrypt) | `POST /api/doadores`; email e CPF únicos (409); CPF com dígitos verificadores; BCrypt | Scalar |
| RF4 | API pública só com campanhas `Ativa`: Título, Meta, Valor Total Arrecadado (das doações processadas) | `GET /api/campanhas/ativas`, anônimo, cache Redis | d.iii: valor sobe depois do worker |
| RF5 | Doador logado envia IdCampanha e ValorDoacao; não doa para encerrada/cancelada | `POST /api/doacoes` → 202; 422 se não aceita | d.iii: payload e 202 |

### 2.2 Técnicos

| PDF | Tipo | Como atendemos |
|---|---|---|
| Pelo menos 2 microsserviços | `[O]` | `campanhas-api` e `doacoes-worker`, cada um no seu repositório, imagem e deploy |
| API não atualiza o total; publica evento; worker consome e atualiza | `[O]` | API grava doação `Pendente` + evento no outbox do MassTransit (mesma transação) → RabbitMQ → worker soma e marca `Processada` |
| Kubernetes local com `.yaml` (Deployments, Services, ConfigMaps) | `[O]` | kind 0.30; manifests nos repos |
| `/health` ou `/metrics` | `[O]` | os dois, em API e worker |
| Zabbix e Grafana; Grafana com pelo menos 1 dashboard com métricas reais | `[O]` | Prometheus + Grafana (dashboard provisionado); Zabbix 7.0 LTS vigiando `/health` com alerta; painel do Zabbix no Grafana |
| Pipeline a cada push na branch principal: `.NET build` + imagem Docker | `[O]` | GitHub Actions em cada repo de código, sem filtro de caminho; imagem publicada no GHCR |
| Deploy automático no K8s | `[OP]` | fora do plano inicial |
| Testes de unidade no domínio rodando no CI | `[B]` | xUnit no CI (barato, entra desde a Fase 1) |
| API Gateway | `[B]` | Kong DB-less (o PDF cita Ocelot/KrakenD só como exemplo) |

### 2.3 Entregáveis `[O]`

| Entregável | Onde |
|---|---|
| Repositório público com `README.md` passo a passo para subir local | README principal no repo de orquestração, com links dos outros repos |
| Diagrama com microsserviços, bancos, broker, observabilidade (Prometheus, Grafana, Zabbix e banco do Zabbix) | `docs/` |
| PDF justificando os bancos X e Y | `docs/bancos-de-dados.pdf` |
| Vídeo até 15 min (a, b, c, d.i, d.ii, d.iii) | meta 12 a 13 min, roteiro na seção 9 |
| Relatório: nome do grupo, integrantes e usernames do Discord, link da documentação, repositórios e vídeo | `docs/relatorio-entrega.txt` |

### 2.4 Extras `[G]` e por que são permitidos

| Extra | Permitido porque |
|---|---|
| Front Blazor WASM + MudBlazor | o PDF não pede nem proíbe front; a demonstração obrigatória continua sendo via Postman/Swagger |
| Scalar como UI da API | lê o mesmo documento OpenAPI (Swagger); como plano B, coleção Postman e arquivo `.http` |
| Redis | é o "banco Y" justificado no PDF de bancos |
| Docker Compose | só para desenvolver; a entrega roda no Kubernetes |
| Outbox, GHCR, `GET /api/doacoes/minhas`, `GET /api/campanhas` | apoio ao fluxo e ao front; nenhum contraria o PDF |

## 3. Decisões

| Tema | Decisão |
|---|---|
| Repositórios | 4: `conexao-solidaria-campanhas-api`, `conexao-solidaria-doacoes-worker`, `conexao-solidaria-web`, `conexao-solidaria-orchestration` (Compose, k8s de infra, Kong, observabilidade, docs, README principal) |
| Começo | direto em microsserviços (escopo fechado, 2 serviços; monolito antes seria retrabalho) |
| Stack | .NET 10 (SDK 10.0.402, runtime 10.0.13); pacotes fixados em 10.0.x (o .NET 11 já saiu e os pacotes 11.0.0 não rodam em net10.0) |
| Camadas (API) | `Domain`, `Application`, `Infrastructure`, `API` + `tests/`, igual à FCG |
| Código compartilhado | `building-blocks/ConexaoSolidaria.Contracts` (evento) e `ConexaoSolidaria.Messaging` (MassTransit) copiados na API e no worker, como na FCG; mesmo namespace nos dois (o MassTransit roteia pelo nome do tipo) |
| Banco X | PostgreSQL 17: relacional, ACID, unicidade de email/CPF, atualização atômica do total; imagem leve e multi-arquitetura (roda em Mac ARM) |
| Banco Y | Redis 7: cache do painel público (rota mais lida, dado só muda quando o worker processa); worker apaga a chave depois de atualizar, sem valor velho |
| MongoDB | não usado: não há dado de documento natural neste domínio |
| Mensageria | RabbitMQ 4 (imagem `management`) + MassTransit 8.5 (a v9 é paga); outbox EF Core na API; retry e fila `_error` automáticos |
| Worker | host web mínimo (para `/health` e `/metrics`) com consumidor MassTransit; acesso ao banco com SQL direto (Npgsql), sem migrações (o esquema é da API) |
| Gateway | Kong 3 DB-less, `kong.yml` da FCG adaptado |
| Documentação da API | OpenAPI nativo + Scalar 2.21 em `/scalar` (fontes locais, Bearer configurado) |
| Imagens | GHCR (`ghcr.io/yurilucka/...`), públicas, publicadas pelo CI com tag `sha-<commit>` e `latest` |
| Execução | Compose → kind → (Azure depois, opcional) |
| Front | Blazor WebAssembly standalone + MudBlazor 9.13, servido por nginx; visual do protótipo e o mascote Solzinho |

## 4. Regras de negócio

| Regra | Decisão |
|---|---|
| Status na criação | sempre `Ativa`; o POST não recebe status |
| Edição | PUT altera todos os campos, inclusive status; `Concluida` e `Cancelada` podem voltar para `Ativa` |
| Datas | UTC; `DataInicio <= DataFim`; `DataFim` não pode estar no passado na criação, nem quando alterada ou reaberta na edição |
| Meta | maior que zero na criação e na edição |
| Campanha `Ativa` vencida | continua no painel com `prazoEncerrado: true` e recusa doação; sem tarefa automática |
| "Encerrada" (RF5) | status `Concluida`, ou `Ativa` com `DataFim` vencida |
| Doação | valor maior que zero, até 2 casas; `DoadorId` vem do `sub` do token |
| Estados da doação | `Pendente` → `Processada` (worker) ou `Rejeitada` (worker, se a campanha deixou de aceitar no caminho) |
| Rejeição no worker | só se a campanha foi concluída ou cancelada antes do processamento (doação aceita no prazo e processada com atraso ainda soma): marca `Rejeitada` e confirma a mensagem; falha técnica: retry do MassTransit e depois fila `_error` |
| Idempotência | `UPDATE ... WHERE status = 'Pendente'`: mensagem repetida não soma duas vezes |
| Total arrecadado | só o worker escreve; na API a propriedade não tem setter público e o EF ignora a coluna ao salvar (teste garante) |
| CPF | dígitos verificadores; guardado só com números; único (409) |
| Email | minúsculo; único (409) |
| Senha | mínimo 8, letra, número e caractere especial (regra da FCG) |
| GestorONG | só por seed (`helena@esperancasolidaria.demo` / `Gestao@2026`); cadastro público cria sempre `Doador` |
| Seed | `Seed__Enabled=true`; datas relativas à subida (campanhas nunca vencem antes da correção) |
| Token | 120 min |

## 5. Dados (PostgreSQL)

```
usuarios   id uuid PK · nome · email UNIQUE · cpf UNIQUE (11 dígitos) · senha_hash · perfil · criado_em
campanhas  id uuid PK · titulo · descricao · data_inicio · data_fim · meta_financeira numeric(14,2) · status
           valor_arrecadado numeric(14,2) default 0 · criada_em · atualizada_em
doacoes    id uuid PK · campanha_id FK · doador_id FK · valor numeric(14,2) · status · motivo_rejeicao
           criada_em · processada_em
+ tabelas do outbox do MassTransit (inbox_state, outbox_message, outbox_state)
```

## 6. Contrato da API (atrás do Kong, prefixo `/api`)

| Método | Rota | Acesso | Respostas | Tipo |
|---|---|---|---|---|
| POST | `/api/auth/login` | público | 200 · 401 | `[O]` |
| POST | `/api/doadores` | público | 201 · 400 · 409 | `[O]` |
| GET | `/api/campanhas/ativas` | público | 200 | `[O]` |
| POST | `/api/campanhas` | GestorONG | 201 · 400 · 401 · 403 | `[O]` |
| PUT | `/api/campanhas/{id}` | GestorONG | 200 · 400 · 401 · 403 · 404 | `[O]` |
| POST | `/api/doacoes` | Doador | 202 · 400 · 401 · 403 · 404 · 422 | `[O]` |
| GET | `/api/campanhas` | GestorONG | 200 | `[G]` lista da gestão |
| GET | `/api/campanhas/{id}` | público | 200 · 404 | `[G]` página da campanha |
| GET | `/api/doacoes/minhas` | Doador | 200 | `[G]` acompanhamento no front |
| GET | `/health`, `/metrics` | infra | 200 · 503 | `[O]` |

Erros em `ProblemDetails`. JWT HS256 com `sub`, `email`, `name`, `role`, `iss=conexao-solidaria`, `aud=conexao-solidaria`, `exp`.

Evento `DoacaoRecebidaEvent(DoacaoId, IdCampanha, DoadorId, ValorDoacao, OcorridaEm)`. Fila do worker: `doacao-recebida` (padrão kebab do MassTransit), erro em `doacao-recebida_error`.

## 7. Repositórios e estrutura

```
conexao-solidaria-campanhas-api/
  building-blocks/ConexaoSolidaria.Contracts, ConexaoSolidaria.Messaging
  src/Campanhas.Domain, Campanhas.Application, Campanhas.Infrastructure, Campanhas.API
  tests/Campanhas.Tests
  Dockerfile · k8s/ (deployment, service, configmap) · .github/workflows/ci.yml · Campanhas.slnx · README.md

conexao-solidaria-doacoes-worker/
  building-blocks/ (mesmos dois projetos)
  src/Doacoes.Worker
  tests/Doacoes.Tests
  Dockerfile · k8s/ · .github/workflows/ci.yml · Doacoes.slnx · README.md

conexao-solidaria-web/
  src/ConexaoSolidaria.Web (Blazor WASM + MudBlazor) · nginx.conf · Dockerfile · k8s/ · ci.yml

conexao-solidaria-orchestration/
  docker-compose.yml · .env.example · kong/ · prometheus/ · grafana/ · zabbix/
  k8s/ (namespace, infra, observabilidade, kind-config) · scripts/ (up, down, gerar-trafego)
  docs/ (PLANO, arquitetura, ADRs, bancos-de-dados.pdf, roteiro-video, relatorio-entrega) · README.md principal
```

Os `k8s/` de cada serviço ficam no próprio repo (como na FCG); o script `up` da orquestração aplica infra, observabilidade e os serviços.

## 8. Fases

O caminho obrigatório é 0 → 7. A trilha do front (F) começa quando a Fase 1 estiver no Scalar e não bloqueia nada.

| Fase | Entrega | Pronto quando |
|---|---|---|
| 0 Fundação | 4 repos locais, `git init`, `.gitignore`, `global.json`, esqueletos das soluções, CI mínimo (build, test, imagem); kind 0.30 | `dotnet build` verde nos dois serviços |
| 1 API base | domínio (Campanha, Usuario, Doacao, Cpf, Email), EF Core + Npgsql, migração, seed, login, doadores, CRUD de campanhas, Scalar com Bearer, testes de domínio e aplicação | pelo Scalar: login, cadastro, 400/201 na campanha, 403 com doador |
| 2 Doação assíncrona | `POST /api/doacoes` com outbox; worker com consumidor, SQL atômico e idempotente, `/health`, `/metrics`; testes | doação vira `Processada` e o total sobe só pelo worker |
| 3 Painel + Redis | `GET /api/campanhas/ativas` com cache; invalidação na API e no worker; queda do Redis não derruba a API | segunda chamada vem do cache e o valor muda logo após o worker |
| 4 Compose + Kong | Dockerfiles; `docker-compose.yml` com Postgres, RabbitMQ, Redis, API, worker, Kong | `docker compose up -d` do zero e fluxo completo em `http://localhost:8000` |
| 5 Kubernetes (kind) | manifests de tudo, `kind-config` com portas (Kong, RabbitMQ 15672, Grafana, Zabbix), imagens do GHCR, script `up` | todos os pods `Running` e fluxo completo pelo Kong |
| 6 Observabilidade | prometheus-net + métricas de doação; Prometheus; Grafana com dashboard (requisições, CPU/memória, doações, fila); Zabbix 7.0 + banco próprio + setup automático por API (itens HTTP no `/health`, alerta); painel do Zabbix no Grafana | dashboard mexe ao vivo; Zabbix mostra os dois serviços OK e alerta ao derrubar um |
| 7 Entrega | README testado do zero; diagrama; PDF dos bancos; ADRs; coleção Postman; roteiro; gravação; relatório | lista da seção 2.3 completa |
| F1 a F4 Front | F1 base (tema da marca, layouts, HttpClient, auth JWT); F2 telas do fluxo (painel, entrar, cadastro, doar, gestão lista/criar/editar); F3 acompanhamento e minhas doações; F4 polimento (tema escuro, mascote, 404) | fluxo d.i a d.iii funciona pelo site contra a API real |
| 8 Azure | opcional, depois | — |

## 9. Roteiro do vídeo (meta 12 a 13 min, limite 15)

| Tempo | Item | O que mostrar |
|---|---|---|
| 0:00–1:30 | a | diagrama |
| 1:30–3:00 | b | push na `main`, Actions compilando, testando e publicando a imagem |
| 3:00–5:00 | c | `kubectl get pods`, Grafana ao vivo (com `gerar-trafego`), Zabbix |
| 5:00–6:30 | d.i | login da gestora e do doador; 403 com token de doador |
| 6:30–8:00 | d.ii | campanha inválida (400) e válida (201) |
| 8:00–11:30 | d.iii | `kubectl scale deploy/doacoes-worker --replicas=0`; `POST /api/doacoes` (202); RabbitMQ com a mensagem em `Ready` (Get messages mostra o payload); `--replicas=1`; fila esvazia; painel com o valor novo |
| 11:30–12:30 | | recapitulação, bônus (Kong, testes no CI) |

## 10. Grupo

Integrantes da FCG: Carlos Eduardo Menegassi, Pedro Henrique Ribeiro Custódio, Yuri Lucka Carriel Rodrigues, Rafael Moura Gagliard. Sugestão de trilhas: API (Fases 1 e 3), worker e mensageria (Fase 2), infra (Fases 4, 5 e 6), front (F). Pendente: número do grupo, usernames no Discord, data exata de entrega, fluxo de branches.

## 11. Riscos

| Risco | Mitigação |
|---|---|
| Mensagem não aparecer na fila no vídeo | worker em 0 réplicas durante a demonstração (seção 9) |
| Doação publicada antes da primeira subida do worker se perder (visto em teste: exchange sem fila descarta) | fila e bindings declarados no broker na subida (`rabbitmq/definitions.json`, importado pela API de gerenciamento) |
| Seed vencer antes da correção | datas relativas |
| Memória (7,7 GB no Docker) | 1 réplica por serviço; Zabbix com banco pequeno; medido ~2,5 a 3,5 GB |
| Prometheus com várias réplicas atrás de um Service | 1 réplica, ou descoberta de pods se aumentar |
| Scalar/Grafana precisarem de internet | `DisableDefaultFonts()`; plugin do Zabbix baixado na subida (`GF_PLUGINS_PREINSTALL`) |
| Ferramentas desatualizadas | `checkout@v7`, `setup-dotnet@v6`, `docker/*` em versões node24, kind 0.30, pacotes 10.0.x fixados |
| `kind load` falhar com imagens públicas | cluster baixa as imagens públicas; `kind load` só para imagem local |
| Vídeo passar de 15 min | meta 12 a 13 min, gravação em partes |

## 12. Andamento

| Data | Feito |
|---|---|
| 14/11 | Plano v2. Fase 0: 4 repositórios locais (`git init`, sem push). Fase 1 e 3: campanhas-api completa (61 testes). Fase 2: doacoes-worker (13 testes, incluindo integração com PostgreSQL via Testcontainers). Fase 4: Compose com Postgres, RabbitMQ (+ topologia), Redis, API, worker e Kong; fluxo validado pelo Kong, inclusive a demonstração com o worker parado |
