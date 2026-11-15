-- Remove o que popular.sql e demonstracao.sql criaram (ids 'cccccccc' e 'dddddddd') e recalcula o valor arrecadado das demais campanhas.
BEGIN;
DELETE FROM doacoes WHERE campanha_id::text LIKE 'cccccccc%' OR doador_id::text LIKE 'cccccccc%' OR doador_id::text LIKE 'dddddddd%';
DELETE FROM campanhas WHERE id::text LIKE 'cccccccc%';
DELETE FROM usuarios WHERE id::text LIKE 'cccccccc%' OR id::text LIKE 'dddddddd%';
UPDATE campanhas c SET valor_arrecadado = coalesce(
  (SELECT sum(valor) FROM doacoes d WHERE d.campanha_id = c.id AND d.status = 'Processada'), 0);
COMMIT;
