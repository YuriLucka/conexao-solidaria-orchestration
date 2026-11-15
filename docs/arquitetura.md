# Arquitetura

Dois microsserviços .NET 10 (`campanhas-api` e `doacoes-worker`), um site Blazor WebAssembly, um API Gateway, dois bancos (PostgreSQL e Redis), um broker (RabbitMQ) e a observabilidade (Prometheus, Grafana e Zabbix com banco próprio), tudo no namespace `conexao-solidaria` de um cluster Kubernetes local (kind).

```mermaid
flowchart LR
    cliente["Navegador<br/>(site PWA) ou Postman"]

    subgraph k8s["Kubernetes (kind) · namespace conexao-solidaria"]
        kong["Kong 3.9 DB-less<br/>:8000 · plugin jwt · plugin prometheus"]
        web["web<br/>nginx + Blazor WASM"]
        api["campanhas-api<br/>.NET 10 · EF Core · MassTransit outbox<br/>/health · /metrics"]
        rabbit[("RabbitMQ 4.4<br/>fila doacao-recebida<br/>doacao-recebida_error")]
        worker["doacoes-worker<br/>.NET 10 · MassTransit 8.5<br/>retry 3x · idempotente<br/>/health · /metrics"]
        pg[("PostgreSQL 17 · banco X<br/>usuarios · campanhas · doacoes<br/>refresh_tokens · outbox")]
        redis[("Redis 7 · banco Y<br/>campanhas:ativas · TTL 30 s")]

        subgraph obs["Observabilidade"]
            prom["Prometheus<br/>scrape 5 s"]
            graf["Grafana<br/>dashboard provisionado"]
            zbx["Zabbix 7.0<br/>itens HTTP em /health"]
            zdb[("zabbix-db<br/>PostgreSQL próprio")]
        end
    end

    cliente -->|HTTP :8000| kong
    kong -->|/| web
    kong -->|/api · JWT conferido| api
    api -->|EF Core| pg
    api -->|cache-aside| redis
    api -->|DoacaoRecebidaEvent via outbox| rabbit
    rabbit -->|consome| worker
    worker -->|soma o valor · SQL atômico| pg
    worker -.->|DEL campanhas:ativas| redis
    prom -.->|/metrics| api
    prom -.->|/metrics| worker
    prom -.->|/metrics| kong
    prom -.->|/metrics/detailed| rabbit
    graf -->|PromQL| prom
    graf -->|plugin Zabbix| zbx
    zbx -.->|/health| api
    zbx -.->|/health| worker
    zbx --> zdb
```

Versão visual (whiteboard): https://claude.ai/artifact/4vV2GJVZuM5wKxNX8AUmRf

## Componentes

| Componente | Responsabilidade | Detalhes |
|---|---|---|
| Kong | Entrada única; confere assinatura e validade do JWT nas rotas protegidas | DB-less, `kong/kong.yml`; o perfil (GestorONG ou Doador) é conferido pela API (403) |
| web | Site público e área de gestão | Blazor WebAssembly + MudBlazor, nginx com CSP e cabeçalhos de segurança, PWA |
| campanhas-api | Login, cadastro de doadores, campanhas, painel, intenção de doação, consultas da gestão | camadas Domain, Application, Infrastructure e API; outbox do MassTransit no PostgreSQL |
| doacoes-worker | Único serviço que altera o valor arrecadado | consome `DoacaoRecebidaEvent`; transação com `FOR UPDATE`; mensagem repetida não soma duas vezes; doação de campanha encerrada vira `Rejeitada` |
| PostgreSQL (X) | Dados transacionais | unicidade de e-mail e CPF, `CHECK` de meta e valor positivos, índices das listas paginadas |
| Redis (Y) | Cache do painel público | cache-aside de 30 s; a API e o worker apagam a chave quando algo muda; queda do Redis não derruba a API |
| RabbitMQ | Desacopla a doação do processamento | fila e bindings declarados na subida; retry 3x e fila `_error` |
| Prometheus | Métricas | API, worker, Kong e RabbitMQ |
| Grafana | Dashboard | Prometheus e Zabbix como fontes de dados |
| Zabbix + zabbix-db | Disponibilidade | item HTTP por serviço e alerta quando um sai do ar |

## Fluxos

**Doação (assíncrona).**
1. `POST /api/doacoes` com o JWT do doador.
2. O Kong valida o token.
3. A API grava a doação como `Pendente` e o evento no outbox, na mesma transação, e responde `202`.
4. O MassTransit publica na fila `doacao-recebida`.
5. O worker consome, soma o valor e marca `Processada`.
6. O worker apaga o cache; o painel mostra o valor novo na próxima leitura (o site atualiza a cada 5 s).

**Campanha.** Só `GestorONG` cria e edita (`403` para doador). A campanha nasce `Ativa`; término no passado ou meta menor ou igual a zero respondem `400`.

**Sessão.** O login devolve um JWT de 15 minutos e grava o refresh token num cookie HttpOnly. O site guarda o JWT só em memória e o renova em `POST /api/auth/refresh` antes de vencer; cada renovação troca o refresh token, e o reuso de um token já trocado encerra a família de sessões.
