# Plano de execução: API e front (etapas A a I)

15/11/2026. Complementa o `PLANO.md` (v2). Prioridade do usuário: API do enunciado impecável primeiro, depois o front (Blazor WASM + MudBlazor) fiel ao material do grupo, responsivo em desktop e iPhone. Kubernetes e observabilidade ficam para a etapa I.

**Regra de cada etapa:** só avança com a validação da etapa passando. Cada etapa fecha com commit e push (CI verde).

**Referências do front:** protótipo `Conexão Solidária.html`, `Documentação Técnica`, `Marca` e mascote (pasta `Desktop/Hackathon`). Capturas de referência feitas com Playwright (desktop Chromium 1440x900, iPhone 15 WebKit).

**Fora do front (decidido):** Pix simulado (no protótipo a doação passa por um QR Code; aqui "Doar" chama `POST /api/doacoes` direto, que é o que o enunciado pede), recuperação de senha, prestação de contas, "impacto da doação", histórico público de campanhas encerradas (o enunciado diz que a listagem pública mostra só `Ativa`).

## A. API: o obrigatório impecável

| Etapa | O que | Validação |
|---|---|---|
| A1 | Matriz endpoint x enunciado (RF1 a RF5, campos, regras, códigos) e correção de qualquer desvio | matriz revisada, sem item aberto |
| A2 | Erros sempre em `ProblemDetails` em português: campo obrigatório, JSON inválido, status inválido, id inválido; erros por campo em `errors` | testes de integração dos casos de erro |
| A3 | Testes de integração HTTP (WebApplicationFactory + Testcontainers: PostgreSQL, Redis, RabbitMQ) cobrindo RF1 a RF5 e o roteiro do vídeo (d.i a d.iii) | `dotnet test` verde local e no CI |
| A4 | Documentação: exemplos no Scalar, coleção Postman e arquivo `.http` (plano B do vídeo) | coleção roda do zero contra o Compose |
| A5 | Revisão independente do código da API (agente revisor) e correções | nenhum achado relevante aberto |

## B. API: apoio ao front (extras permitidos pelo enunciado)

| Etapa | O que | Validação |
|---|---|---|
| B1 | Campanha com `categoria`, `capa` e `criancasAtendidas` (opcionais) | testes + migração |
| B2 | Detalhe público: quantidade de doações e doadores; `GET /api/campanhas/{id}/doacoes-recentes` (só processadas, nome abreviado "Mariana A.") | testes |
| B3 | `GET /api/doacoes/{id}` (dono) para o acompanhamento; título da campanha nas doações | testes |
| B4 | Gestão: `GET /api/doacoes` (filtros), `GET /api/gestao/doadores` (CPF mascarado, totais), `GET /api/gestao/resumo` (visão geral) | testes |
| B5 | Revisão e CI | CI verde |

## C. Front: fundação

| Etapa | O que | Validação |
|---|---|---|
| C1 | Projeto Blazor WebAssembly standalone (.NET 10) + MudBlazor 9; Dockerfile com nginx; CI publicando no GHCR | build, imagem e CI verdes |
| C2 | Identidade: `MudTheme` com a paleta da marca, fontes locais (Bricolage Grotesque, Figtree, JetBrains Mono, licença OFL), logo, 12 capas e o mascote extraídos do material do grupo | página de amostra comparada com o protótipo |
| C3 | Layouts: público (barra superior, menu no celular, rodapé) e gestão (menu lateral, gaveta no celular); tema claro/escuro | capturas desktop e iPhone sem rolagem horizontal |
| C4 | `HttpClient` tipado, JWT no `localStorage`, `AuthenticationStateProvider`, rotas protegidas por perfil, tradução de `ProblemDetails` em mensagens | testes de componente (bUnit) do estado de login |
| C5 | Bateria Playwright: desktop (Chromium 1440 e 1024), iPhone SE e iPhone 15 (WebKit), iPad; checa rolagem horizontal, erros no console e tira capturas | roda localmente com um comando |

## D. Front: telas públicas

| Etapa | Tela | Validação |
|---|---|---|
| D1 | Painel de transparência (hero, resumo, cards com capa, barra de progresso, prazo encerrado) | Playwright + comparação com o protótipo |
| D2 | Página da campanha (capa, dados, doações recentes, cartão de doação) | idem |
| D3 | Entrar | idem + login das duas contas |
| D4 | Criar conta (máscara e validação de CPF, força da senha, confirmação) | idem + 409/400 da API exibidos no campo certo |
| D5 | Como funciona, termos, 404, sem conexão | idem |

## E. Front: doação

| Etapa | O que | Validação |
|---|---|---|
| E1 | Cartão de doação: valores rápidos, outro valor, bloqueio para campanha encerrada (422) | Playwright |
| E2 | Acompanhamento da doação: Pendente → Processada com atualização automática | Playwright com o worker real (valor sobe no painel) |
| E3 | Minhas doações (resumo e histórico) | Playwright |

## F. Front: gestão (GestorONG)

| Etapa | O que | Validação |
|---|---|---|
| F1 | Lista de campanhas: busca, filtro por status, progresso | Playwright |
| F2 | Criar e editar: capa, categoria, prévia do card, checklist das regras, status na edição | Playwright: 400 (data passada, meta 0) e 201 |
| F3 | Doações e doadores | Playwright |
| F4 | Visão geral (indicadores e gráfico) | Playwright |

## G. Qualidade do front

| Etapa | O que | Validação |
|---|---|---|
| G1 | Revisão responsiva completa em todas as telas e tamanhos | relatório de capturas sem problema aberto |
| G2 | Acessibilidade básica (axe), tema escuro, estados vazios, carregando e erro | sem violação séria do axe |
| G3 | E2E do roteiro do vídeo pelo site (login, criar campanha, doar, ver o valor subir) | verde contra o Compose |
| G4 | Revisão independente do front (agente revisor) | achados resolvidos |

## H. Integração

| Etapa | O que | Validação |
|---|---|---|
| H1 | Front no Compose atrás do Kong (`/` → web, `/api` → API) | tudo em `http://localhost:8000` |
| H2 | READMEs atualizados | passo a passo testado do zero |

## I. Restante do plano v2

Kubernetes (kind), observabilidade (Prometheus, Grafana, Zabbix), documentos de entrega e vídeo: Fases 5, 6 e 7 do `PLANO.md`.

## Decisões tomadas durante a execução

- Datas sem fuso enviadas à API são horário de Brasília (UTC-3); término informado só com a data vale até 23:59:59 daquele dia. Visão geral da gestão conta dias de Brasília.
- Cache do painel com 30 s de vida; `prazoEncerrado` recalculado a cada leitura.
- Login com e-mail mal formatado responde 401 (mesma mensagem de credencial inválida) e o BCrypt roda mesmo sem usuário, para o tempo de resposta não revelar quais e-mails têm conta.
- Mantidos como estão (decisão do grupo, enunciado não proíbe): doação aceita antes da `DataInicio`; detalhe público responde também para campanha encerrada (transparência); doações recentes mostram primeiro nome e inicial do sobrenome.

## Andamento

| Etapa | Situação |
|---|---|
| A1 | feito: nenhum desvio do enunciado; nomes `idCampanha`, `valorDoacao`, `DoacaoRecebidaEvent` idênticos |
| A2 | feito: validação automática, 401/403/404 e erros de domínio em `ProblemDetails` português |
| A3 | feito: 54 testes de integração (PostgreSQL, Redis, RabbitMQ reais), incluindo a mensagem chegando no RabbitMQ e o valor sem mudar sem o worker |
| A4 | feito: exemplos no Scalar, `Campanhas.API.http`, coleção Postman (`docs/postman`) rodada do zero pelo Kong: 11/11 |
| A5 | feito: revisão independente sem item crítico; 3 importantes e 3 menores corrigidos (seção acima) |
| B1 a B5 | feito: categoria/capa/crianças, doações recentes, acompanhamento, gestão; 120 testes no total |
| C1 a C5 | feito: Blazor WASM + MudBlazor, identidade do protótipo (cores, fontes locais, logo, 12 capas, 13 expressões do Solzinho, ícones), layouts público e gestão, sessão JWT, bateria Playwright (5 aparelhos) |
| D1 a D5 | feito: painel, campanha, entrar, cadastro, como funciona, termos, 404 |
| E1 a E3 | feito: doar, acompanhamento (Pendente → Confirmada ao vivo), minhas doações |
| F1 a F4 | feito: visão geral (gráfico, alertas, ao vivo), campanhas, criar/editar (capa, prévia, regras), concluir/cancelar, doadores, doações |
| G | feito: 48 testes de unidade do front (xUnit + bUnit); E2E de doação e de gestão em iPhone (WebKit) e desktop (Chromium); axe WCAG 2.1 AA sem violação (14 telas x 2 aparelhos x tema claro/escuro, `npm run acessibilidade`); revisão independente com 8 achados corrigidos; fotos no login e no topo do painel (extra); cabeçalhos de segurança no nginx |
| H1 | feito: site no Compose atrás do Kong (`/` site, `/api` API) |
| I1 | feito: Kubernetes (kind) com `scripts/up.sh`: PostgreSQL, Redis, RabbitMQ (fila declarada por Job), Kong, API, worker e site com imagens do GHCR; fluxos de doação, gestão e sessão passando pelo site no cluster; mensagem parada na fila com o worker em 0 réplicas |
| I2 | feito: Prometheus (API, worker, Kong, RabbitMQ), Grafana com dashboard provisionado e fonte Zabbix, Zabbix 7.0 com banco próprio configurado por Job (itens HTTP no `/health` e alerta; testado derrubando o worker: alerta em ~100 s, resolvido ao voltar) |
| I3 | feito: README principal, `docs/arquitetura.md` (Mermaid) e `docs/bancos-de-dados.md`; pendentes: PDF dos bancos, roteiro final e gravação do vídeo |

Decisões do front: "Doar" envia a intenção direto (sem a tela de Pix do protótipo); datas da gestão com máscara dd/mm/aaaa (o campo datetime-local quebra o Blazor em navegadores sem suporte, como o WebKit de teste no Windows); início às 00:00 e término às 23:59 de Brasília; gráfico em SVG próprio no visual do protótipo.
