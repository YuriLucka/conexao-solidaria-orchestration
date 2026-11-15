-- Dados realistas para demonstração (rodar depois do seed da API): 60 doadores e ~450 doações confirmadas nos
-- últimos 45 dias, distribuídas entre as campanhas ativas do seed, com progresso variado nas metas.
-- Ids começando com 'dddddddd' (apagados por limpar.sql junto com a carga 'cccccccc').
-- Senha de todos os doadores de demonstração: Doar@2026 (a mesma da Mariana).
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.cpf(base bigint) RETURNS text AS $$
DECLARE d text := lpad(base::text, 9, '0'); s int; v1 int; v2 int; i int;
BEGIN
  s := 0; FOR i IN 1..9 LOOP s := s + substr(d, i, 1)::int * (11 - i); END LOOP;
  v1 := (s * 10) % 11; IF v1 = 10 THEN v1 := 0; END IF; d := d || v1;
  s := 0; FOR i IN 1..10 LOOP s := s + substr(d, i, 1)::int * (12 - i); END LOOP;
  v2 := (s * 10) % 11; IF v2 = 10 THEN v2 := 0; END IF;
  RETURN d || v2;
END $$ LANGUAGE plpgsql IMMUTABLE;

INSERT INTO usuarios (id, nome, email, cpf, senha_hash, perfil, criado_em)
SELECT ('dddddddd-1111-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  (ARRAY['Ana','Bruno','Camila','Daniel','Eduarda','Felipe','Giovana','Henrique','Isadora','Júlio','Letícia','Mateus','Nicole','Pedro','Rafaela','Thiago','Vitória','Lucas','Beatriz','Gustavo'])[1 + (n - 1) % 20]
   || ' ' || (ARRAY['Silva','Santos','Oliveira','Souza','Costa','Pereira','Almeida','Nascimento','Lima','Araújo','Ribeiro','Carvalho'])[1 + (n * 7) % 12],
  'doador' || n || '@email.demo',
  pg_temp.cpf(700000000 + n),
  (SELECT senha_hash FROM usuarios WHERE email = 'mariana@email.demo'),
  'Doador',
  now() - ((n * 3) % 90 + 1) * interval '1 day'
FROM generate_series(1, 60) AS n;

-- Doações com valores típicos (R$ 20 a R$ 500, algumas maiores), concentradas em algumas campanhas.
WITH ativas AS (
  SELECT id, row_number() OVER (ORDER BY data_fim) AS ordem FROM campanhas WHERE status = 'Ativa' AND id::text NOT LIKE 'cccccccc%'
)
INSERT INTO doacoes (id, campanha_id, doador_id, valor, status, motivo_rejeicao, criada_em, processada_em)
SELECT gen_random_uuid(), a.id,
  ('dddddddd-1111-4000-8000-' || lpad((1 + (n * 13) % 60)::text, 12, '0'))::uuid,
  (ARRAY[20, 25, 30, 50, 50, 75, 100, 100, 150, 200, 250, 500, 1000])[1 + (n * 7) % 13],
  'Processada', NULL,
  now() - (n % 45) * interval '1 day' - (n * 37 % 1440) * interval '1 minute',
  now() - (n % 45) * interval '1 day' - (n * 37 % 1440) * interval '1 minute' + interval '3 seconds'
FROM generate_series(1, 450) AS n
JOIN ativas a ON a.ordem = 1 + (n * n) % (SELECT count(*) FROM ativas);

-- A Mariana também doou: aparece em "Minhas doações".
INSERT INTO doacoes (id, campanha_id, doador_id, valor, status, motivo_rejeicao, criada_em, processada_em)
SELECT gen_random_uuid(), c.id, (SELECT id FROM usuarios WHERE email = 'mariana@email.demo'), v.valor, 'Processada', NULL,
  now() - v.dias * interval '1 day', now() - v.dias * interval '1 day' + interval '3 seconds'
FROM (VALUES ('Natal da Esperança', 150, 12), ('Volta às Aulas', 80, 5), ('Biblioteca Viva', 45.5, 2)) AS v(titulo, valor, dias)
JOIN campanhas c ON c.titulo = v.titulo;

UPDATE campanhas c SET valor_arrecadado = coalesce(
  (SELECT sum(valor) FROM doacoes d WHERE d.campanha_id = c.id AND d.status = 'Processada'), 0);

COMMIT;
ANALYZE;
