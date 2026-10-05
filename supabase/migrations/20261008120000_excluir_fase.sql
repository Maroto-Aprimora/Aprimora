-- =====================================================================
-- Excluir fase do funil (Configurações do funil)
-- A fase sai do funil e das configurações, mas fica guardada (excluida_em) para o histórico
-- dos negócios continuar mostrando por onde eles passaram. Negócios que estão nela são movidos antes.
-- =====================================================================
alter table public.fases add column excluida_em timestamptz;
comment on column public.fases.excluida_em is 'Fase excluída pelo diretor: some do funil e das configurações, mas continua no histórico.';

create or replace function public.excluir_fase(_fase uuid, _destino uuid default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_fase public.fases%rowtype;
  v_destino public.fases%rowtype;
  v_movidos int := 0;
begin
  select * into v_fase from public.fases where id = _fase and excluida_em is null;
  if not found then raise exception 'Fase não encontrada'; end if;
  if not privado.eh_diretor_de(privado.diretoria_do_funil(v_fase.funil_id)) then
    raise exception 'Só o diretor da diretoria pode excluir fases';
  end if;
  if v_fase.ordem = (select min(ordem) from public.fases where funil_id = v_fase.funil_id and excluida_em is null) then
    raise exception 'A primeira fase (entrada de leads) não pode ser excluída';
  end if;
  if v_fase.tipo = 'ganho' and not exists (
    select 1 from public.fases where funil_id = v_fase.funil_id and tipo = 'ganho' and id <> _fase and excluida_em is null) then
    raise exception 'O funil precisa de pelo menos uma fase de ganho';
  end if;

  if exists (select 1 from public.negocios where fase_id = _fase) then
    if _destino is null then raise exception 'Escolha para qual fase mover os negócios desta fase'; end if;
    select * into v_destino from public.fases
      where id = _destino and funil_id = v_fase.funil_id and id <> _fase and excluida_em is null;
    if not found then raise exception 'Fase de destino inválida'; end if;
    if v_destino.tipo in ('ganho', 'perda') then
      raise exception 'Mova os negócios para uma fase em andamento ou de pausa';
    end if;
    -- Passa pelos gatilhos normais (histórico, campos obrigatórios ao avançar)
    update public.negocios set fase_id = _destino where fase_id = _fase;
    get diagnostics v_movidos = row_count;
  end if;

  -- Outras fases que apontavam para esta deixam de apontar
  update public.fases set fase_destino_sla = null, acao_sla = case when acao_sla = 'mover' then 'alertar'::public.acao_sla else acao_sla end
    where fase_destino_sla = _fase;
  update public.fases set auto_mover_para = null where auto_mover_para = _fase;

  update public.fases set ativa = false, excluida_em = now() where id = _fase;

  perform privado.registrar_auditoria('fase_excluida', 'fases', _fase::text,
    jsonb_build_object('nome', v_fase.nome, 'negocios_movidos', v_movidos, 'destino', v_destino.nome));
  return jsonb_build_object('movidos', v_movidos);
end;
$$;
revoke all on function public.excluir_fase(uuid, uuid) from public, anon;
grant execute on function public.excluir_fase(uuid, uuid) to authenticated;
