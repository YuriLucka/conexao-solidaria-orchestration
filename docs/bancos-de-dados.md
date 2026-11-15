# Bancos de dados: justificativa

A solução usa dois bancos com papéis diferentes: **PostgreSQL 17** (banco X) para os dados de negócio e **Redis 7** (banco Y) como cache do painel público. O Zabbix tem um terceiro PostgreSQL, só dele, que não guarda dado da ONG.

## Banco X: PostgreSQL 17

**O que guarda.** Usuários (gestores e doadores), campanhas, doações, sessões (refresh tokens, só o hash) e as tabelas do outbox do MassTransit.

**Por que relacional.**
- **Integridade.** E-mail e CPF únicos por índice; meta e valor positivos por `CHECK`; chaves estrangeiras de doação para campanha e para doador. Regras do enunciado ficam garantidas pelo banco, não só pelo código.
- **Transações ACID no ponto crítico.** O worker soma o valor numa transação com `SELECT ... FOR UPDATE` na doação e na campanha. Duas mensagens iguais ao mesmo tempo não somam duas vezes, e duas doações para a mesma campanha não se perdem.
- **Outbox transacional.** A doação e o evento `DoacaoRecebidaEvent` são gravados na mesma transação. Se o RabbitMQ estiver fora, o evento fica guardado e sai depois; não existe doação sem evento nem evento sem doação.
- **Consultas da gestão.** Totais, doadores únicos, ticket médio e arrecadação por dia são agregações (`GROUP BY`, `COUNT DISTINCT`, `SUM`) que o SQL resolve no servidor, com índices `(campanha_id, criada_em)`, `(doador_id, criada_em)` e `(status, processada_em)`.

**Por que PostgreSQL e não outro relacional.** Código aberto, suporte completo no EF Core (Npgsql) e no MassTransit (outbox), busca sem diferenciar maiúsculas (`ILIKE`), imagem `alpine` leve e multiarquitetura (roda também em Mac com ARM).

**Alternativa descartada: MongoDB.** O domínio é relacional (doação pertence a uma campanha e a um doador) e depende de unicidade e de atualização atômica entre duas entidades. Não há dado de documento natural que justifique o modelo.

## Banco Y: Redis 7

**O que guarda.** A chave `campanhas:ativas`: a lista do painel de transparência, já pronta em JSON, com validade de 30 segundos.

**Por que.**
- **É a rota mais lida.** O painel é público e o site o atualiza a cada 5 segundos para cada visitante. Sem cache, cada leitura iria ao PostgreSQL.
- **O dado muda pouco e em momentos conhecidos.** Só muda quando o worker processa uma doação ou a gestão altera uma campanha. Nesses momentos a chave é apagada (pela API ou pelo worker), e a próxima leitura busca o valor novo: o painel não mostra valor velho.
- **Cache-aside tolerante a falha.** Se o Redis cair, a API registra um aviso e lê do banco. O cache acelera, mas não é ponto único de falha.
- **Validade curta.** Os 30 segundos limitam o efeito de uma leitura que aconteça bem no meio de uma invalidação.

**Por que Redis e não cache em memória da API.** Com mais de uma réplica da API, cada uma teria seu cache, e o worker (outro processo) não conseguiria invalidá-lo. O Redis é compartilhado pela API e pelo worker.

## Banco do Zabbix

O Zabbix 7.0 precisa de um banco para configuração e histórico. Ele roda em um PostgreSQL próprio (`zabbix-db`), separado do banco X: a monitoração não concorre com o banco da aplicação e pode ser recriada sem tocar nos dados da ONG.
