-- Depois de fase0_pr6_dados.sql: transfere um negócio ganho e confere que o contrato continua com quem fechou.
\set ON_ERROR_STOP 1
do $$
declare
  v_neg uuid; v_antes uuid; v_novo uuid := '00000000-0000-0000-0000-0000000000b2';
  c_antes numeric; c_depois numeric;
begin
  select n.id, n.responsavel_id into v_neg, v_antes from public.negocios n
   where n.ganho_em is not null and n.responsavel_id is not null and n.responsavel_id <> v_novo limit 1;
  if v_neg is null then raise notice 'sem negócio ganho para testar'; return; end if;
  c_antes := public.valor_indicador_meta('contratos', '2025-01-01', '2026-12-31', v_antes);
  update public.negocios set responsavel_id = v_novo where id = v_neg;   -- transferência de carteira
  c_depois := public.valor_indicador_meta('contratos', '2025-01-01', '2026-12-31', v_antes);
  if c_antes <> c_depois then raise exception 'contrato mudou de dono: % → %', c_antes, c_depois; end if;
  raise notice 'OK: contrato continua com quem fechou (% antes e depois da transferência)', c_depois;
  -- E um negócio novo que entra em E-mail registra o responsável do rodízio no histórico
  if exists (select 1 from public.negocio_historico h join public.negocios n on n.id = h.negocio_id
             where h.created_at > now() - interval '1 minute' and h.responsavel_id is distinct from n.responsavel_id and n.id <> v_neg) then
    raise exception 'histórico sem o responsável da época';
  end if;
end $$;
