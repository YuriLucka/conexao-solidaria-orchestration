# Roteiro do vídeo (máximo 15 minutos; meta 12 a 13)

O enunciado pede que o vídeo comprove a arquitetura e o funcionamento, sem ler código linha a linha. Cada bloco abaixo corresponde a um item obrigatório (a, b, c, d.i, d.ii, d.iii).

## Antes de gravar

- Cluster no ar: `./scripts/up.sh` (todos os pods `Running`).
- Abas abertas no navegador:
  - diagrama: [docs/arquitetura.md](arquitetura.md) no GitHub, ou a versão visual (whiteboard);
  - GitHub Actions do repositório `conexao-solidaria-campanhas-api`;
  - Grafana em http://localhost:3000, no dashboard **Conexão Solidária** (intervalo "Last 15 minutes");
  - RabbitMQ em http://localhost:15672, aba **Queues and Streams**;
  - Zabbix em http://localhost:8081, em **Monitoring > Problems**;
  - Postman com a coleção `docs/postman/conexao-solidaria.postman_collection.json` importada (variável `base` = `http://localhost:8000`).
- Um terminal (Git Bash) na pasta `conexao-solidaria-orchestration`.
- Um commit pequeno pronto para o push do bloco b (por exemplo, uma linha no README de um serviço).
- Gerar algum tráfego antes, para o dashboard não começar vazio: `./scripts/gerar-trafego.sh 20`.

## 0:00 a 1:30 · a. Diagrama de arquitetura

Mostrar o diagrama e explicar, nesta ordem:

1. Entrada única pelo **Kong** (API Gateway, bônus): site em `/`, API em `/api`, JWT conferido no gateway.
2. Dois microsserviços: **campanhas-api** (usuários, campanhas, painel, intenção de doação) e **doacoes-worker** (único que soma o valor arrecadado).
3. **RabbitMQ**: a API publica `DoacaoRecebidaEvent` (pelo outbox, na mesma transação da doação); o worker consome a fila `doacao-recebida`.
4. Bancos: **PostgreSQL** (banco X, dados de negócio) e **Redis** (banco Y, cache do painel público). Justificativa no PDF `docs/bancos-de-dados.pdf`.
5. Observabilidade: **Prometheus** coleta `/metrics`; **Grafana** mostra o dashboard; **Zabbix** vigia o `/health`, com banco próprio.
6. Tudo roda no **Kubernetes (kind)**, no namespace `conexao-solidaria`.

## 1:30 a 3:00 · b. Pipeline de CI gerando a imagem

1. Fazer o push do commit pequeno na `main` de um serviço.
2. Abrir o GitHub Actions: o workflow `ci` dispara sozinho.
3. Mostrar as etapas: `dotnet build`, testes (unidade e integração, bônus) e build e push da imagem Docker.
4. Mostrar a imagem publicada no GHCR (`ghcr.io/yurilucka/...`, tags `latest` e `sha-<commit>`).

Se a execução demorar, mostrar uma execução anterior já concluída e voltar à atual no fim do vídeo.

## 3:00 a 5:00 · c. Pods no Kubernetes e Grafana em tempo real

1. No terminal: `kubectl -n conexao-solidaria get pods` (API, worker, site, Kong, PostgreSQL, Redis, RabbitMQ, Prometheus, Grafana, Zabbix e banco do Zabbix, todos `Running`).
2. No terminal: `./scripts/gerar-trafego.sh 30` (doações reais pelo Kong).
3. No Grafana: os painéis mexendo ao vivo (doações processadas por minuto, valor arrecadado, fila, requisições por segundo, p95, CPU e memória por microsserviço).
4. No fim do dashboard: saúde dos microsserviços vinda do **Zabbix**. Opcional: abrir o Zabbix e mostrar o host **Conexão Solidária** com os dois itens HTTP.

## 5:00 a 6:30 · d.i. Autenticação e token JWT

No Postman, pasta **d.i Autenticação**:

1. **Login gestora**: 200 com `accessToken` (JWT), `perfil = GestorONG`. Colar o token em jwt.io para mostrar as claims (`role`, `exp`).
2. **Login doadora**: 200 com `perfil = Doador`.
3. **Doador na gestão (403)**: token de doador tentando criar campanha recebe 403.

Opcional (bônus): o Scalar em http://localhost:8000/scalar mostra a mesma API documentada.

## 6:30 a 8:00 · d.ii. Criação de uma campanha

No Postman, pasta **d.ii Campanha**, com o token da gestora:

1. **Término no passado (400)**: a regra do enunciado barra a campanha, com a mensagem em português.
2. **Meta zero (400)**: meta financeira precisa ser maior que zero.
3. **Criar campanha (201)**: campanha criada com status `Ativa`.
4. Mostrar a campanha nova no painel público (`GET /api/campanhas/ativas` ou o site).

## 8:00 a 11:30 · d.iii. Doação passando pela fila

Para a mensagem aparecer parada na fila, o worker é desligado antes:

1. Terminal: `kubectl -n conexao-solidaria scale deploy/doacoes-worker --replicas=0`.
2. Postman, pasta **d.iii Doação**, **Doar (202)**: mostrar o payload (`idCampanha`, `valorDoacao`) e a resposta `202` com a doação `Pendente`.
3. RabbitMQ, fila `doacao-recebida`: 1 mensagem em **Ready**. Em **Get messages**, mostrar o `DoacaoRecebidaEvent`.
4. Postman, **Painel público**: o valor da campanha **ainda não mudou** (a API não altera o valor arrecadado).
5. Terminal: `kubectl -n conexao-solidaria scale deploy/doacoes-worker --replicas=1`.
6. RabbitMQ: a fila esvazia. Grafana: o painel "Doações processadas" registra a doação.
7. Postman, **Painel público** de novo: o valor arrecadado subiu, atualizado pelo worker.

Enquanto o worker está em 0 réplicas, o Zabbix abre o alerta **"doacoes-worker fora do ar"** depois de cerca de 90 s. Se houver tempo, mostrar o alerta e ele se resolvendo quando o worker volta.

## 11:30 a 12:30 · Fechamento

- Recapitular: dois microsserviços, mensageria assíncrona, Kubernetes, observabilidade e CI.
- Bônus entregues: Kong como API Gateway, testes de unidade e integração rodando no CI.
- Extra: o site (Blazor) faz o mesmo fluxo pela interface, com sessão por refresh token.
