-- Carga de teste: popula o banco para estressar o site (listas longas, textos no limite, paginação).
-- Uso: docker compose exec -T postgres psql -U <usuario> -d conexao_solidaria -f - < tools/carga/popular.sql
-- Tudo o que este script cria tem id começando com 'cccccccc' (campanhas e doadores) e é apagado por limpar.sql.
-- Os doadores de carga usam a mesma senha da Mariana (Doar@2026).
BEGIN;

-- CPF válido a partir de 9 dígitos (dígitos verificadores calculados), para passar na validação da API.
CREATE OR REPLACE FUNCTION pg_temp.cpf(base bigint) RETURNS text AS $$
DECLARE d text := lpad(base::text, 9, '0'); s int; v1 int; v2 int; i int;
BEGIN
  s := 0; FOR i IN 1..9 LOOP s := s + substr(d, i, 1)::int * (11 - i); END LOOP;
  v1 := (s * 10) % 11; IF v1 = 10 THEN v1 := 0; END IF; d := d || v1;
  s := 0; FOR i IN 1..10 LOOP s := s + substr(d, i, 1)::int * (12 - i); END LOOP;
  v2 := (s * 10) % 11; IF v2 = 10 THEN v2 := 0; END IF;
  RETURN d || v2;
END $$ LANGUAGE plpgsql IMMUTABLE;

-- 120 campanhas: 90 ativas (com prazos variados, metas batidas, títulos e descrições no limite) e 30 encerradas.
INSERT INTO campanhas (id, titulo, descricao, data_inicio, data_fim, meta_financeira, status, valor_arrecadado,
                       criada_em, atualizada_em, capa, categoria, criancas_atendidas)
SELECT
  ('cccccccc-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  CASE
    WHEN n % 10 = 0 THEN left('Campanha de teste com um título extremamente longo para verificar quebras de linha, reticências e alinhamento dos cartões número ' || n, 150)
    WHEN n % 7 = 0 THEN 'Ação ' || n
    ELSE 'Campanha de carga ' || n || ' · ' || (ARRAY['Natal','Material escolar','Reforma','Biblioteca','Saúde bucal','Horta','Agasalhos'])[1 + n % 7]
  END,
  CASE
    WHEN n % 10 = 0 THEN left(repeat('Descrição muito longa para testar o limite de quatro mil caracteres e a quebra de texto em todas as telas do site. ', 40), 4000)
    WHEN n % 9 = 0 THEN 'Curta.'
    ELSE 'Campanha criada pela carga de teste para verificar listas grandes, paginação e desempenho do painel e da gestão.'
  END,
  now() - ((n % 60) + 5) * interval '1 day',
  CASE
    WHEN n % 15 = 0 THEN now() - interval '2 days'          -- prazo encerrado, ainda Ativa
    WHEN n % 11 = 0 THEN date_trunc('day', now()) + interval '23 hours 59 minutes' -- termina hoje
    ELSE now() + ((n % 120) + 1) * interval '1 day'
  END,
  CASE WHEN n % 13 = 0 THEN 999999999.99 ELSE 500 + (n * 1371) % 150000 END,
  CASE WHEN n <= 90 THEN 'Ativa' WHEN n % 2 = 0 THEN 'Concluida' ELSE 'Cancelada' END,
  0,
  now() - ((n % 60) + 6) * interval '1 day',
  now() - interval '1 day',
  (ARRAY['sol-colinas','amanhecer','livros','presentes','casa','saude','horta','bola','inverno','estrelas','abraco','festa'])[1 + n % 12],
  CASE WHEN n % 8 = 0 THEN NULL ELSE (ARRAY['Datas especiais','Educação','Infraestrutura','Saúde','Alimentação','Esporte e lazer','Inverno'])[1 + n % 7] END,
  CASE WHEN n % 6 = 0 THEN NULL WHEN n % 17 = 0 THEN 100000 ELSE 1 + (n * 37) % 400 END
FROM generate_series(1, 120) AS n;

-- 3.000 doadores (nomes e e-mails longos em alguns), senha igual à da Mariana.
INSERT INTO usuarios (id, nome, email, cpf, senha_hash, perfil, criado_em)
SELECT
  ('cccccccc-1111-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  CASE WHEN n % 50 = 0
       THEN left('Maria Aparecida dos Santos Albuquerque de Oliveira Figueiredo Nascimento Cavalcanti Rodrigues Pereira da Silva Costa ' || n, 150)
       ELSE (ARRAY['Ana','Bruno','Carla','Diego','Elisa','Fábio','Gabriela','Heitor','Isabela','João','Larissa','Marcos','Natália','Otávio','Paula','Rafael'])[1 + n % 16]
            || ' ' || (ARRAY['Souza','Lima','Ferreira','Gomes','Ribeiro','Carvalho','Almeida','Barbosa','Rocha','Dias'])[1 + (n / 16) % 10] || ' ' || n
  END,
  CASE WHEN n % 50 = 0 THEN 'endereco.de.email.bem.comprido.para.teste.' || n || '@provedor-de-email-muito-longo.carga.demo'
       ELSE 'doador' || n || '@carga.demo' END,
  pg_temp.cpf(800000000 + n),
  (SELECT senha_hash FROM usuarios WHERE email = 'mariana@email.demo'),
  'Doador',
  now() - ((n % 200) + 1) * interval '1 day'
FROM generate_series(1, 3000) AS n;

-- 40.000 doações nos últimos 120 dias (90% confirmadas, 5% em confirmação, 5% não concluídas).
INSERT INTO doacoes (id, campanha_id, doador_id, valor, status, motivo_rejeicao, criada_em, processada_em)
SELECT
  gen_random_uuid(),
  ('cccccccc-0000-4000-8000-' || lpad((1 + n % 90)::text, 12, '0'))::uuid,
  ('cccccccc-1111-4000-8000-' || lpad((1 + (n * 7) % 3000)::text, 12, '0'))::uuid,
  CASE WHEN n % 97 = 0 THEN 25000 ELSE 5 + (n * 13) % 495 END,
  CASE WHEN n % 20 = 0 THEN 'Pendente' WHEN n % 20 = 1 THEN 'Rejeitada' ELSE 'Processada' END,
  CASE WHEN n % 20 = 1 THEN 'Doação não contabilizada: a campanha foi concluída antes do processamento. Você pode apoiar outra campanha ativa.' END,
  t, CASE WHEN n % 20 = 0 THEN NULL ELSE t + interval '3 seconds' END
FROM (SELECT n, now() - (n % 120) * interval '1 day' - (n % 1440) * interval '1 minute' AS t
      FROM generate_series(1, 40000) AS n) AS g;

-- 300 doações da Mariana (para estressar "Minhas doações").
INSERT INTO doacoes (id, campanha_id, doador_id, valor, status, motivo_rejeicao, criada_em, processada_em)
SELECT gen_random_uuid(),
  ('cccccccc-0000-4000-8000-' || lpad((1 + n % 90)::text, 12, '0'))::uuid,
  (SELECT id FROM usuarios WHERE email = 'mariana@email.demo'),
  10 + n, 'Processada', NULL, now() - n * interval '6 hours', now() - n * interval '6 hours' + interval '3 seconds'
FROM generate_series(1, 300) AS n;

-- Valor arrecadado = soma das doações confirmadas (o que o worker faria).
UPDATE campanhas c SET valor_arrecadado = coalesce(s.total, 0)
FROM (SELECT campanha_id, sum(valor) AS total FROM doacoes WHERE status = 'Processada' GROUP BY campanha_id) s
WHERE s.campanha_id = c.id AND c.id::text LIKE 'cccccccc%';

COMMIT;
ANALYZE;
