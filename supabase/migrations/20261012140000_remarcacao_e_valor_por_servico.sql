-- =====================================================================
-- v2 · Fase 0 · PR 4 — Proposta remarcada e valor por serviço (PE-PA-002, Seção 3.4)
-- =====================================================================

-- ---------------------------------------------------------------------
-- Remarcação: a atividade original fica com status "remarcada" (e a data original);
-- uma nova atividade é criada na data nova, ligada à original.
-- ---------------------------------------------------------------------
alter type public.status_atividade add value if not exists 'remarcada' before 'cancelada';

alter table public.atividades
  add column remarcada_para_id uuid references public.atividades (id) on delete set null,
  add column remarcada_de_id uuid references public.atividades (id) on delete set null;

-- Remarca respeitando o RLS de quem chama (só quem pode gerir a atividade)
create or replace function public.remarcar_atividade(_atividade uuid, _novo_inicio timestamptz, _novo_fim timestamptz default null,
  _motivo text default null)
returns uuid language plpgsql security invoker set search_path = '' as $$
declare
  a public.atividades%rowtype;
  v_nova uuid;
begin
  select * into a from public.atividades where id = _atividade;
  if not found then raise exception 'Atividade não encontrada'; end if;
  if a.status::text in ('realizada', 'cancelada', 'remarcada') then
    raise exception 'Só atividades pendentes ou confirmadas podem ser remarcadas';
  end if;
  if _novo_fim is not null and _novo_fim <= _novo_inicio then
    raise exception 'O fim precisa ser depois do início';
  end if;

  insert into public.atividades (tipo_id, diretoria, titulo, inicio, fim, dia_inteiro, local, link_reuniao, empresa_id, negocio_id,
                                 responsavel_id, stakeholder, remarcada_de_id)
  values (a.tipo_id, a.diretoria, a.titulo, _novo_inicio,
          coalesce(_novo_fim, case when a.fim is not null then _novo_inicio + (a.fim - a.inicio) end),
          a.dia_inteiro, a.local, a.link_reuniao, a.empresa_id, a.negocio_id, a.responsavel_id, a.stakeholder, a.id)
  returning id into v_nova;

  insert into public.atividade_participantes (atividade_id, membro_id)
  select v_nova, membro_id from public.atividade_participantes where atividade_id = a.id;

  update public.atividades
     set status = 'remarcada'::public.status_atividade,
         remarcada_para_id = v_nova,
         proximos_passos = coalesce(nullif(trim(_motivo), ''), proximos_passos)
   where id = a.id;
  if not found then raise exception 'Sem permissão para remarcar esta atividade'; end if;
  return v_nova;
end;
$$;
revoke all on function public.remarcar_atividade(uuid, timestamptz, timestamptz, text) from public, anon;
grant execute on function public.remarcar_atividade(uuid, timestamptz, timestamptz, text) to authenticated;

-- ---------------------------------------------------------------------
-- Valor por serviço: quando algum serviço do negócio tem valor, o valor do negócio é a soma
-- ---------------------------------------------------------------------
alter table public.negocio_servicos add column valor numeric(12, 2) check (valor is null or valor >= 0);

create or replace function public.somar_valor_servicos()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_negocio uuid := coalesce(new.negocio_id, old.negocio_id);
  v_soma numeric;
begin
  select sum(valor) into v_soma from public.negocio_servicos where negocio_id = v_negocio and valor is not null;
  if v_soma is not null then
    update public.negocios set valor = v_soma where id = v_negocio and valor is distinct from v_soma;
  end if;
  return null;
end;
$$;
create trigger somar_valor_servicos after insert or update of valor or delete on public.negocio_servicos
  for each row execute function public.somar_valor_servicos();
revoke all on function public.somar_valor_servicos() from public, anon, authenticated;
