-- =====================================================================
-- Segurança: funções auxiliares saem do schema "public" (exposto pela API REST)
-- e vão para o schema "privado", que a API não publica. As políticas RLS continuam
-- funcionando (referenciam as funções pelo identificador interno), mas ninguém
-- consegue chamá-las diretamente por /rest/v1/rpc.
-- Correção apontada pelo Security Advisor do Supabase.
-- =====================================================================

create schema if not exists privado;
revoke all on schema privado from public, anon;
grant usage on schema privado to authenticated;

alter function public.membro_ativo() set schema privado;
alter function public.cargo_em(text) set schema privado;
alter function public.eh_diretor_de(text) set schema privado;
alter function public.eh_diretor() set schema privado;
alter function public.pertence_a(text) set schema privado;
alter function public.diretoria_do_funil(uuid) set schema privado;
alter function public.diretoria_da_fase(uuid) set schema privado;
alter function public.participa_do_negocio(uuid) set schema privado;
alter function public.pode_editar_empresa(uuid) set schema privado;
alter function public.pode_editar_negocio(uuid) set schema privado;
alter function public.registrar_auditoria(text, text, text, jsonb) set schema privado;
alter function public.proximo_do_rodizio(uuid) set schema privado;
alter function public.aplicar_slas() set schema privado;

-- Corpos que chamam outras funções auxiliares precisam apontar para o novo schema
create or replace function privado.eh_diretor_de(_diretoria text)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(privado.cargo_em(_diretoria) = 'diretor', false);
$$;

create or replace function privado.pertence_a(_diretoria text)
returns boolean language sql stable security definer set search_path = '' as $$
  select privado.cargo_em(_diretoria) is not null;
$$;

create or replace function privado.pode_editar_empresa(_empresa uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select privado.eh_diretor_de('comercial')
      or exists (select 1 from public.empresas e where e.id = _empresa and e.criado_por = (select auth.uid()))
      or exists (select 1 from public.negocios n where n.empresa_id = _empresa and privado.participa_do_negocio(n.id));
$$;

create or replace function privado.pode_editar_negocio(_negocio uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.negocios n where n.id = _negocio
    and (privado.eh_diretor_de(privado.diretoria_do_funil(n.funil_id)) or privado.participa_do_negocio(n.id)));
$$;

create or replace function public.proteger_membro()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if (new.ativo is distinct from old.ativo or new.email is distinct from old.email) then
    if (select auth.uid()) is not null and not exists (
      select 1 from public.membro_diretorias md
      where md.membro_id = old.id and privado.eh_diretor_de(md.diretoria)
    ) then
      raise exception 'Apenas um diretor pode ativar, desativar ou alterar o e-mail de um membro';
    end if;
    if new.ativo is distinct from old.ativo then
      perform privado.registrar_auditoria(
        case when new.ativo then 'membro_reativado' else 'membro_desativado' end,
        'membros', old.id::text, jsonb_build_object('nome', old.nome));
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.garantir_diretor()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_diretoria text := coalesce(old.diretoria, new.diretoria);
begin
  if tg_op in ('UPDATE', 'DELETE') and old.cargo = 'diretor'
     and (tg_op = 'DELETE' or new.cargo <> 'diretor') then
    if not exists (
      select 1 from public.membro_diretorias md
      join public.membros m on m.id = md.membro_id
      where md.diretoria = v_diretoria and md.cargo = 'diretor' and m.ativo
        and md.membro_id <> old.membro_id
    ) then
      raise exception 'A diretoria % ficaria sem diretor ativo. Promova o sucessor antes.', v_diretoria;
    end if;
  end if;
  perform privado.registrar_auditoria(
    'cargo_' || lower(tg_op), 'membro_diretorias',
    coalesce(new.membro_id, old.membro_id)::text,
    jsonb_build_object('diretoria', v_diretoria, 'de', old.cargo, 'para', new.cargo));
  return coalesce(new, old);
end;
$$;

create or replace function public.antes_de_salvar_negocio()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_destino public.fases%rowtype;
  v_origem public.fases%rowtype;
  v_faltando text;
  v_diretoria text;
begin
  select * into v_destino from public.fases where id = new.fase_id;
  if v_destino.funil_id <> new.funil_id then
    raise exception 'A fase escolhida não pertence a este funil';
  end if;

  if tg_op = 'INSERT' or new.fase_id is distinct from old.fase_id then
    select diretoria into v_diretoria from public.funis where id = new.funil_id;

    -- Trainee não marca ganho (regra da diretoria)
    if v_destino.tipo = 'ganho' and (select auth.uid()) is not null
       and privado.cargo_em(v_diretoria) = 'trainee' then
      raise exception 'Trainees não podem marcar um negócio como ganho';
    end if;

    -- Saídas de perda exigem motivo
    if v_destino.exige_motivo is not null and new.motivo_id is null then
      raise exception 'Informe o motivo para mover para "%"', v_destino.nome;
    end if;

    -- Campos obrigatórios da fase de origem precisam estar preenchidos para avançar
    if tg_op = 'UPDATE' then
      select * into v_origem from public.fases where id = old.fase_id;
      if v_destino.tipo in ('aberta', 'ganho') and v_destino.ordem > v_origem.ordem then
        select string_agg(fc.rotulo, ', ' order by fc.ordem) into v_faltando
        from public.fase_campos fc
        where fc.fase_id = old.fase_id and fc.obrigatorio
          and nullif(nullif(trim(coalesce(new.campos ->> fc.chave, '')), ''), '[]') is null;
        if v_faltando is not null then
          raise exception 'Preencha antes de avançar: %', v_faltando;
        end if;
      end if;
    end if;

    new.entrou_na_fase_em := now();
    new.ganho_em := case when v_destino.tipo = 'ganho' then coalesce(new.ganho_em, now()) else null end;
    new.encerrado_em := case when v_destino.tipo in ('ganho', 'perda') then now() else null end;
    if v_destino.exige_motivo is null then
      new.motivo_id := null;
      new.motivo_detalhe := null;
    end if;

    -- Rodízio automático de responsável
    if v_destino.distribui_responsavel and new.responsavel_id is null then
      new.responsavel_id := privado.proximo_do_rodizio(new.funil_id);
    end if;
  end if;
  return new;
end;
$$;

-- O agendamento passa a chamar a função no novo schema
select cron.unschedule('aplicar-slas-diario');
select cron.schedule('aplicar-slas-diario', '5 11 * * *', 'select privado.aplicar_slas()');

-- Funções de gatilho não devem ser chamáveis pela API
revoke all on function public.antes_de_salvar_negocio(), public.depois_de_salvar_negocio(),
  public.garantir_diretor(), public.proteger_membro(), public.ao_criar_usuario(),
  public.tocar_updated_at() from public, anon, authenticated;

-- Auxiliares de permissão: só usuários logados (dentro das políticas RLS)
revoke all on all functions in schema privado from public, anon;
grant execute on function privado.membro_ativo(), privado.cargo_em(text), privado.eh_diretor_de(text),
  privado.eh_diretor(), privado.pertence_a(text), privado.diretoria_do_funil(uuid), privado.diretoria_da_fase(uuid),
  privado.participa_do_negocio(uuid), privado.pode_editar_empresa(uuid), privado.pode_editar_negocio(uuid)
  to authenticated;
revoke all on function privado.registrar_auditoria(text, text, text, jsonb), privado.proximo_do_rodizio(uuid),
  privado.aplicar_slas() from authenticated;
