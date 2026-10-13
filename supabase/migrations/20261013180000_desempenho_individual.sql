-- =====================================================================
-- v2 · Fase 2 · 2.4 — Desempenho individual (PE-PA-002, Seção 6)
-- - Nota média da rubrica no indicador de coldcall (antes ficava nula). A função roda com as permissões de quem
--   consulta: o membro vê a média das suas avaliações; o diretor, a de todos.
-- - Plano de melhoria do membro: o rascunho do Analista gerencial só aparece para o membro depois que o diretor
--   revisa o relatório (revisado_em preenchido).
-- - Agendador (A8) desligado por decisão do Diretor Comercial (13/10/2026).
-- =====================================================================

do $$
declare
  v_def text := pg_get_functiondef('public.indicadores_comerciais(date,date,uuid)'::regprocedure);
begin
  if position('''notaMedia'', null' in v_def) = 0 then raise exception 'trecho notaMedia não encontrado'; end if;
  execute replace(v_def, '''notaMedia'', null',
    '''notaMedia'', (select round(avg(a.media), 2) from public.avaliacoes_ligacao a join ligacoes lg on lg.id = a.ligacao_id)');
end $$;

-- Plano de melhoria liberado: do relatório da R.I revisado mais recente que tenha plano para o membro
create or replace function public.plano_melhoria(_membro uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_nome text;
  v_rel record;
  v_plano jsonb;
begin
  if _membro is distinct from (select auth.uid()) and not privado.eh_diretor_de('comercial') then
    raise exception 'Sem permissão';
  end if;
  select nome into v_nome from public.membros where id = _membro;
  for v_rel in
    select r.id, r.de, r.ate, r.revisado_em, r.analise from public.relatorios r
     where r.status = 'pronto' and r.revisado_em is not null and r.analise is not null
     order by r.ate desc, r.revisado_em desc limit 10
  loop
    select p into v_plano from jsonb_array_elements(coalesce(v_rel.analise -> 'planos', '[]')) p
     where public.normalizar(p ->> 'membro') = public.normalizar(v_nome) limit 1;
    if v_plano is not null then
      return jsonb_build_object('de', v_rel.de, 'ate', v_rel.ate, 'revisado_em', v_rel.revisado_em, 'plano', v_plano);
    end if;
  end loop;
  return null;
end;
$$;
revoke all on function public.plano_melhoria(uuid) from public, anon;
grant execute on function public.plano_melhoria(uuid) to authenticated;

update public.agentes set ativo = false where chave = 'agendador';
