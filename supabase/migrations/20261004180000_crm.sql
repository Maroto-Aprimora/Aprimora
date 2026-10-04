-- =====================================================================
-- Fase 1 — CRM e funil comercial
-- Empresas, contatos, negócios, fases do Pipefy, campos por fase, histórico,
-- motivos, serviços da Carta, rodízio de responsáveis e SLA automático.
-- =====================================================================

create extension if not exists pg_trgm with schema extensions;
create extension if not exists unaccent with schema extensions;
create extension if not exists pg_cron with schema pg_catalog;

create type public.area_servico as enum ('negocios', 'producao', 'qualidade');
create type public.tipo_fase as enum ('aberta', 'ganho', 'perda', 'pausa');
create type public.macroetapa as enum ('prospeccao', 'cadencia', 'oportunidade', 'venda', 'ganho', 'pausa', 'perda');
create type public.acao_sla as enum ('alertar', 'mover');
create type public.tipo_campo as enum ('texto', 'texto_longo', 'data', 'numero', 'moeda', 'membros', 'selecao', 'booleano', 'link');
create type public.tipo_motivo as enum ('perda', 'desqualificacao');

-- Texto normalizado (sem acento, minúsculo) para busca e detecção de duplicidade
create or replace function public.normalizar(_t text)
returns text language sql immutable parallel safe set search_path = '' as $$
  select lower(extensions.unaccent('extensions.unaccent'::regdictionary, coalesce(_t, '')));
$$;

create or replace function public.so_digitos(_t text)
returns text language sql immutable parallel safe set search_path = '' as $$
  select nullif(regexp_replace(coalesce(_t, ''), '\D', '', 'g'), '');
$$;

-- ---------------------------------------------------------------------
-- Cadastros de apoio (configuráveis pelo diretor)
-- ---------------------------------------------------------------------
create table public.segmentos (
  id uuid primary key default gen_random_uuid(),
  diretoria text not null default 'comercial' references public.diretorias (slug),
  nome text not null,
  ativo boolean not null default true,
  unique (diretoria, nome)
);

create table public.origens (
  id uuid primary key default gen_random_uuid(),
  diretoria text not null default 'comercial' references public.diretorias (slug),
  nome text not null,
  ordem smallint not null default 0,
  ativo boolean not null default true,
  unique (diretoria, nome)
);

create table public.servicos (
  id uuid primary key default gen_random_uuid(),
  diretoria text not null default 'comercial' references public.diretorias (slug),
  area public.area_servico not null,
  nome text not null,
  descricao text,
  ordem smallint not null default 0,
  ativo boolean not null default true,
  unique (diretoria, nome)
);

create table public.motivos (
  id uuid primary key default gen_random_uuid(),
  diretoria text not null default 'comercial' references public.diretorias (slug),
  tipo public.tipo_motivo not null,
  nome text not null,
  ordem smallint not null default 0,
  ativo boolean not null default true,
  unique (diretoria, tipo, nome)
);

-- ---------------------------------------------------------------------
-- Funil e fases
-- ---------------------------------------------------------------------
create table public.funis (
  id uuid primary key default gen_random_uuid(),
  diretoria text not null references public.diretorias (slug),
  chave text not null,
  nome text not null,
  unique (diretoria, chave)
);

create table public.fases (
  id uuid primary key default gen_random_uuid(),
  funil_id uuid not null references public.funis (id) on delete cascade,
  chave text not null,
  nome text not null,
  descricao text,
  ordem smallint not null,
  macroetapa public.macroetapa not null,
  tipo public.tipo_fase not null default 'aberta',
  probabilidade numeric(4, 3) not null default 0 check (probabilidade between 0 and 1),
  sla_dias integer check (sla_dias > 0),
  acao_sla public.acao_sla,
  fase_destino_sla uuid references public.fases (id) on delete set null,
  auto_mover_para uuid references public.fases (id) on delete set null,
  distribui_responsavel boolean not null default false,
  exige_motivo public.tipo_motivo,
  ativa boolean not null default true,
  unique (funil_id, chave)
);

create table public.fase_campos (
  id uuid primary key default gen_random_uuid(),
  fase_id uuid not null references public.fases (id) on delete cascade,
  chave text not null,
  rotulo text not null,
  tipo public.tipo_campo not null default 'texto',
  opcoes jsonb,
  obrigatorio boolean not null default false,
  ajuda text,
  ordem smallint not null default 0,
  unique (fase_id, chave)
);
comment on column public.fase_campos.obrigatorio is
  'Precisa estar preenchido para o negócio AVANÇAR para uma fase posterior (não vale para saídas de perda ou pausa).';

-- ---------------------------------------------------------------------
-- Empresas e contatos
-- ---------------------------------------------------------------------
create table public.empresas (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  razao_social text,
  cnpj text,
  segmento_id uuid references public.segmentos (id) on delete set null,
  telefone text,
  email_principal text,
  email_secundario text,
  email_terciario text,
  site text,
  rede_social text,
  endereco text,
  cidade text,
  uf text check (uf is null or length(uf) = 2),
  observacoes text,
  ficticio boolean not null default false,
  criado_por uuid references public.membros (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- colunas derivadas para busca e duplicidade
  nome_normalizado text generated always as (public.normalizar(nome)) stored,
  cnpj_digitos text generated always as (public.so_digitos(cnpj)) stored,
  telefone_digitos text generated always as (public.so_digitos(telefone)) stored
);
create unique index empresas_cnpj_unico on public.empresas (cnpj_digitos) where cnpj_digitos is not null;
create index empresas_nome_trgm on public.empresas using gin (nome_normalizado extensions.gin_trgm_ops);
create index empresas_telefone_idx on public.empresas (telefone_digitos);

create table public.contatos (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  nome text not null,
  cargo text,
  decisor boolean not null default false,
  email text,
  telefone text,
  linkedin text,
  nao_contatar boolean not null default false,
  observacoes text,
  criado_por uuid references public.membros (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index contatos_empresa_idx on public.contatos (empresa_id);

-- ---------------------------------------------------------------------
-- Negócios (cards do funil)
-- ---------------------------------------------------------------------
create table public.negocios (
  id uuid primary key default gen_random_uuid(),
  funil_id uuid not null references public.funis (id),
  empresa_id uuid not null references public.empresas (id) on delete restrict,
  contato_id uuid references public.contatos (id) on delete set null,
  titulo text not null,
  fase_id uuid not null references public.fases (id),
  responsavel_id uuid references public.membros (id) on delete set null,
  valor numeric(14, 2) check (valor is null or valor >= 0),
  origem_id uuid references public.origens (id) on delete set null,
  origem_detalhe text,
  data_coldcall_1 date,
  data_coldcall_2 date,
  dores_identificadas text,
  campos jsonb not null default '{}'::jsonb,
  motivo_id uuid references public.motivos (id) on delete set null,
  motivo_detalhe text,
  retorno_em date,
  entrou_na_fase_em timestamptz not null default now(),
  ganho_em timestamptz,
  encerrado_em timestamptz,
  ficticio boolean not null default false,
  criado_por uuid references public.membros (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index negocios_fase_idx on public.negocios (fase_id);
create index negocios_empresa_idx on public.negocios (empresa_id);
create index negocios_responsavel_idx on public.negocios (responsavel_id);

create table public.negocio_servicos (
  negocio_id uuid not null references public.negocios (id) on delete cascade,
  servico_id uuid not null references public.servicos (id) on delete cascade,
  primary key (negocio_id, servico_id)
);

create table public.negocio_participantes (
  negocio_id uuid not null references public.negocios (id) on delete cascade,
  membro_id uuid not null references public.membros (id) on delete cascade,
  papel text,
  primary key (negocio_id, membro_id)
);
create index negocio_participantes_membro_idx on public.negocio_participantes (membro_id);

create table public.negocio_historico (
  id bigint generated always as identity primary key,
  negocio_id uuid not null references public.negocios (id) on delete cascade,
  fase_origem_id uuid references public.fases (id) on delete set null,
  fase_destino_id uuid not null references public.fases (id) on delete cascade,
  autor_id uuid references public.membros (id) on delete set null,
  automatico boolean not null default false,
  motivo_id uuid references public.motivos (id) on delete set null,
  comentario text,
  created_at timestamptz not null default now()
);
create index negocio_historico_negocio_idx on public.negocio_historico (negocio_id, created_at);
create index negocio_historico_destino_idx on public.negocio_historico (fase_destino_id, created_at);

create table public.rodizio_estado (
  funil_id uuid primary key references public.funis (id) on delete cascade,
  ultimo_membro_id uuid references public.membros (id) on delete set null,
  atualizado_em timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Metas (estrutura de OKRs da Aprimora). Cálculo automático entra na Fase 3.
-- ---------------------------------------------------------------------
create table public.metas (
  id uuid primary key default gen_random_uuid(),
  diretoria text not null references public.diretorias (slug),
  trimestre text not null check (trimestre ~ '^[1-4]T[0-9]{4}$'),
  objetivo text not null,
  codigo text,
  titulo text not null,
  alvo numeric(14, 2) not null,
  unidade text not null default 'un',
  realizado_manual numeric(14, 2),
  indicador text,
  membro_id uuid references public.membros (id) on delete cascade,
  peso numeric(5, 2) not null default 1,
  ordem smallint not null default 0,
  created_at timestamptz not null default now()
);
comment on column public.metas.indicador is
  'Chave do indicador automático (Fase 3). Nulo = meta acompanhada manualmente (realizado_manual).';

-- ---------------------------------------------------------------------
-- Gatilhos
-- ---------------------------------------------------------------------
create trigger empresas_updated_at before update on public.empresas
  for each row execute function public.tocar_updated_at();
create trigger contatos_updated_at before update on public.contatos
  for each row execute function public.tocar_updated_at();
create trigger negocios_updated_at before update on public.negocios
  for each row execute function public.tocar_updated_at();

-- Próximo responsável do rodízio: membros ativos da diretoria do funil, que participam do rodízio
-- e não são diretores, em ordem alfabética, continuando de onde parou.
create or replace function public.proximo_do_rodizio(_funil uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_diretoria text;
  v_ultimo uuid;
  v_ultimo_nome text;
  v_proximo uuid;
begin
  select diretoria into v_diretoria from public.funis where id = _funil;
  select ultimo_membro_id into v_ultimo from public.rodizio_estado where funil_id = _funil for update;
  select nome into v_ultimo_nome from public.membros where id = v_ultimo;

  select m.id into v_proximo
  from public.membro_diretorias md join public.membros m on m.id = md.membro_id
  where md.diretoria = v_diretoria and md.participa_rodizio and md.cargo <> 'diretor' and m.ativo
    and (v_ultimo_nome is null or (m.nome, m.id) > (v_ultimo_nome, v_ultimo))
  order by m.nome, m.id limit 1;

  if v_proximo is null then -- volta ao início da lista
    select m.id into v_proximo
    from public.membro_diretorias md join public.membros m on m.id = md.membro_id
    where md.diretoria = v_diretoria and md.participa_rodizio and md.cargo <> 'diretor' and m.ativo
    order by m.nome, m.id limit 1;
  end if;

  if v_proximo is not null then
    insert into public.rodizio_estado (funil_id, ultimo_membro_id, atualizado_em)
    values (_funil, v_proximo, now())
    on conflict (funil_id) do update set ultimo_membro_id = excluded.ultimo_membro_id, atualizado_em = now();
  end if;
  return v_proximo;
end;
$$;
revoke all on function public.proximo_do_rodizio(uuid) from public, anon, authenticated;

-- Regras ao criar ou mover um negócio (validação + carimbos de data)
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
       and public.cargo_em(v_diretoria) = 'trainee' then
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
      new.responsavel_id := public.proximo_do_rodizio(new.funil_id);
    end if;
  end if;
  return new;
end;
$$;

create trigger antes_de_salvar_negocio before insert or update on public.negocios
  for each row execute function public.antes_de_salvar_negocio();

-- Depois de mover: grava histórico e aplica a movimentação automática da fase (ex.: Entrada → Enriquecimento)
create or replace function public.depois_de_salvar_negocio()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_auto uuid;
  v_flag text := coalesce(current_setting('aprimora.movimento_automatico', true), '');
  v_coment text := coalesce(current_setting('aprimora.comentario_movimento', true), '');
begin
  if tg_op = 'INSERT' or new.fase_id is distinct from old.fase_id then
    insert into public.negocio_historico (negocio_id, fase_origem_id, fase_destino_id, autor_id, automatico, motivo_id, comentario)
    values (
      new.id,
      case when tg_op = 'UPDATE' then old.fase_id end,
      new.fase_id,
      (select auth.uid()),
      coalesce(current_setting('aprimora.movimento_automatico', true), '') <> '',
      new.motivo_id,
      nullif(current_setting('aprimora.comentario_movimento', true), '')
    );

    select auto_mover_para into v_auto from public.fases where id = new.fase_id;
    if v_auto is not null and v_auto <> new.fase_id then
      perform set_config('aprimora.movimento_automatico', 'sim', true);
      perform set_config('aprimora.comentario_movimento', 'Movimentação automática da fase', true);
      update public.negocios set fase_id = v_auto where id = new.id;
      perform set_config('aprimora.movimento_automatico', v_flag, true);
      perform set_config('aprimora.comentario_movimento', v_coment, true);
    end if;
  end if;
  return null;
end;
$$;

create trigger depois_de_salvar_negocio after insert or update of fase_id on public.negocios
  for each row execute function public.depois_de_salvar_negocio();

-- Mover negócio com comentário (usado pelo app). Respeita RLS: roda como o usuário.
create or replace function public.mover_negocio(_negocio uuid, _fase uuid, _motivo uuid default null,
  _motivo_detalhe text default null, _comentario text default null, _retorno_em date default null)
returns void language plpgsql security invoker set search_path = '' as $$
begin
  perform set_config('aprimora.comentario_movimento', coalesce(_comentario, ''), true);
  update public.negocios
     set fase_id = _fase,
         motivo_id = coalesce(_motivo, motivo_id),
         motivo_detalhe = coalesce(_motivo_detalhe, motivo_detalhe),
         retorno_em = coalesce(_retorno_em, retorno_em)
   where id = _negocio;
  if not found then
    raise exception 'Negócio não encontrado ou sem permissão para alterá-lo';
  end if;
  perform set_config('aprimora.comentario_movimento', '', true);
end;
$$;
revoke all on function public.mover_negocio(uuid, uuid, uuid, text, text, date) from public, anon;
grant execute on function public.mover_negocio(uuid, uuid, uuid, text, text, date) to authenticated;

-- Empresas parecidas (para avisar antes de criar duplicada)
create or replace function public.empresas_semelhantes(_nome text, _cnpj text default null,
  _telefone text default null, _dominio text default null)
returns table (id uuid, nome text, cnpj text, cidade text, motivo text, semelhanca real)
language sql stable security invoker set search_path = '' as $$
  select e.id, e.nome, e.cnpj, e.cidade,
    case
      when public.so_digitos(_cnpj) is not null and e.cnpj_digitos = public.so_digitos(_cnpj) then 'Mesmo CNPJ'
      when public.so_digitos(_telefone) is not null and e.telefone_digitos = public.so_digitos(_telefone) then 'Mesmo telefone'
      when _dominio is not null and _dominio <> '' and (e.site ilike '%' || _dominio || '%'
        or e.email_principal ilike '%@' || _dominio) then 'Mesmo domínio'
      else 'Nome parecido'
    end,
    extensions.similarity(e.nome_normalizado, public.normalizar(_nome))
  from public.empresas e
  where (public.so_digitos(_cnpj) is not null and e.cnpj_digitos = public.so_digitos(_cnpj))
     or (public.so_digitos(_telefone) is not null and e.telefone_digitos = public.so_digitos(_telefone))
     or (_dominio is not null and _dominio <> '' and (e.site ilike '%' || _dominio || '%' or e.email_principal ilike '%@' || _dominio))
     or extensions.similarity(e.nome_normalizado, public.normalizar(_nome)) > 0.45
  order by 6 desc
  limit 8;
$$;
grant execute on function public.empresas_semelhantes(text, text, text, text) to authenticated;

-- ---------------------------------------------------------------------
-- SLA automático (pg_cron, todo dia às 08:05 de Brasília = 11:05 UTC)
-- ---------------------------------------------------------------------
create or replace function public.aplicar_slas()
returns integer language plpgsql security definer set search_path = '' as $$
declare
  r record;
  n integer := 0;
begin
  perform set_config('aprimora.movimento_automatico', 'sim', true);

  -- 1) Fases com SLA e ação "mover"
  for r in
    select n.id, f.fase_destino_sla, f.sla_dias, f.nome
    from public.negocios n join public.fases f on f.id = n.fase_id
    where f.acao_sla = 'mover' and f.fase_destino_sla is not null and f.sla_dias is not null
      and n.entrou_na_fase_em < now() - make_interval(days => f.sla_dias)
  loop
    perform set_config('aprimora.movimento_automatico', 'sim', true);
    perform set_config('aprimora.comentario_movimento',
      format('SLA de %s dias em "%s" estourado', r.sla_dias, r.nome), true);
    update public.negocios set fase_id = r.fase_destino_sla where id = r.id;
    n := n + 1;
  end loop;

  -- 2) Reciclagem com data de retorno vencida volta para a fase de destino configurada
  for r in
    select n.id, f.fase_destino_sla
    from public.negocios n join public.fases f on f.id = n.fase_id
    where f.tipo = 'pausa' and f.fase_destino_sla is not null and n.retorno_em is not null
      and n.retorno_em <= (now() at time zone 'America/Sao_Paulo')::date
  loop
    perform set_config('aprimora.movimento_automatico', 'sim', true);
    perform set_config('aprimora.comentario_movimento', 'Data de retorno da reciclagem atingida', true);
    update public.negocios set fase_id = r.fase_destino_sla, retorno_em = null where id = r.id;
    n := n + 1;
  end loop;

  perform set_config('aprimora.movimento_automatico', '', true);
  perform set_config('aprimora.comentario_movimento', '', true);
  return n;
end;
$$;
revoke all on function public.aplicar_slas() from public, anon, authenticated;

select cron.schedule('aplicar-slas-diario', '5 11 * * *', 'select public.aplicar_slas()');

-- ---------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------
alter table public.segmentos enable row level security;
alter table public.origens enable row level security;
alter table public.servicos enable row level security;
alter table public.motivos enable row level security;
alter table public.funis enable row level security;
alter table public.fases enable row level security;
alter table public.fase_campos enable row level security;
alter table public.empresas enable row level security;
alter table public.contatos enable row level security;
alter table public.negocios enable row level security;
alter table public.negocio_servicos enable row level security;
alter table public.negocio_participantes enable row level security;
alter table public.negocio_historico enable row level security;
alter table public.rodizio_estado enable row level security;
alter table public.metas enable row level security;

-- Cadastros de apoio: todos os membros leem; diretor da diretoria altera
create policy segmentos_ler on public.segmentos for select to authenticated using ((select public.membro_ativo()));
create policy segmentos_gerir on public.segmentos for all to authenticated
  using (public.eh_diretor_de(diretoria)) with check (public.eh_diretor_de(diretoria));
create policy origens_ler on public.origens for select to authenticated using ((select public.membro_ativo()));
create policy origens_gerir on public.origens for all to authenticated
  using (public.eh_diretor_de(diretoria)) with check (public.eh_diretor_de(diretoria));
create policy servicos_ler on public.servicos for select to authenticated using ((select public.membro_ativo()));
create policy servicos_gerir on public.servicos for all to authenticated
  using (public.eh_diretor_de(diretoria)) with check (public.eh_diretor_de(diretoria));
create policy motivos_ler on public.motivos for select to authenticated using ((select public.membro_ativo()));
create policy motivos_gerir on public.motivos for all to authenticated
  using (public.eh_diretor_de(diretoria)) with check (public.eh_diretor_de(diretoria));
create policy funis_ler on public.funis for select to authenticated using ((select public.membro_ativo()));
create policy funis_gerir on public.funis for all to authenticated
  using (public.eh_diretor_de(diretoria)) with check (public.eh_diretor_de(diretoria));

create or replace function public.diretoria_do_funil(_funil uuid)
returns text language sql stable security definer set search_path = '' as $$
  select diretoria from public.funis where id = _funil;
$$;
create or replace function public.diretoria_da_fase(_fase uuid)
returns text language sql stable security definer set search_path = '' as $$
  select f2.diretoria from public.fases f join public.funis f2 on f2.id = f.funil_id where f.id = _fase;
$$;

create policy fases_ler on public.fases for select to authenticated using ((select public.membro_ativo()));
create policy fases_gerir on public.fases for all to authenticated
  using (public.eh_diretor_de(public.diretoria_do_funil(funil_id)))
  with check (public.eh_diretor_de(public.diretoria_do_funil(funil_id)));
create policy fase_campos_ler on public.fase_campos for select to authenticated using ((select public.membro_ativo()));
create policy fase_campos_gerir on public.fase_campos for all to authenticated
  using (public.eh_diretor_de(public.diretoria_da_fase(fase_id)))
  with check (public.eh_diretor_de(public.diretoria_da_fase(fase_id)));

-- Quem participa de um negócio (responsável ou participante)
create or replace function public.participa_do_negocio(_negocio uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.negocios n where n.id = _negocio and n.responsavel_id = (select auth.uid()))
      or exists (select 1 from public.negocio_participantes p where p.negocio_id = _negocio and p.membro_id = (select auth.uid()));
$$;

-- Empresas e contatos: todos os membros ativos leem (evita contato duplicado);
-- membros do Comercial criam; edita quem criou, o diretor ou quem trabalha num negócio da empresa.
create or replace function public.pode_editar_empresa(_empresa uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.eh_diretor_de('comercial')
      or exists (select 1 from public.empresas e where e.id = _empresa and e.criado_por = (select auth.uid()))
      or exists (select 1 from public.negocios n where n.empresa_id = _empresa and public.participa_do_negocio(n.id));
$$;

create policy empresas_ler on public.empresas for select to authenticated using ((select public.membro_ativo()));
create policy empresas_criar on public.empresas for insert to authenticated
  with check (public.pertence_a('comercial'));
create policy empresas_editar on public.empresas for update to authenticated
  using (public.pode_editar_empresa(id)) with check (public.pode_editar_empresa(id));
create policy empresas_excluir on public.empresas for delete to authenticated
  using (public.eh_diretor_de('comercial'));

create policy contatos_ler on public.contatos for select to authenticated using ((select public.membro_ativo()));
create policy contatos_criar on public.contatos for insert to authenticated
  with check (public.pertence_a('comercial'));
create policy contatos_editar on public.contatos for update to authenticated
  using (public.pode_editar_empresa(empresa_id) or criado_por = (select auth.uid()))
  with check (public.pode_editar_empresa(empresa_id) or criado_por = (select auth.uid()));
create policy contatos_excluir on public.contatos for delete to authenticated
  using (public.eh_diretor_de('comercial') or (criado_por = (select auth.uid()) and public.cargo_em('comercial') <> 'trainee'));

-- Negócios: todos os membros ativos leem; membros da diretoria criam;
-- edita o diretor, o responsável ou um participante; só o diretor exclui.
create policy negocios_ler on public.negocios for select to authenticated using ((select public.membro_ativo()));
create policy negocios_criar on public.negocios for insert to authenticated
  with check (public.pertence_a(public.diretoria_do_funil(funil_id)));
create policy negocios_editar on public.negocios for update to authenticated
  using (public.eh_diretor_de(public.diretoria_do_funil(funil_id)) or public.participa_do_negocio(id))
  with check (public.eh_diretor_de(public.diretoria_do_funil(funil_id)) or public.participa_do_negocio(id));
create policy negocios_excluir on public.negocios for delete to authenticated
  using (public.eh_diretor_de(public.diretoria_do_funil(funil_id)));

create or replace function public.pode_editar_negocio(_negocio uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.negocios n where n.id = _negocio
    and (public.eh_diretor_de(public.diretoria_do_funil(n.funil_id)) or public.participa_do_negocio(n.id)));
$$;

create policy negocio_servicos_ler on public.negocio_servicos for select to authenticated using ((select public.membro_ativo()));
create policy negocio_servicos_gerir on public.negocio_servicos for all to authenticated
  using (public.pode_editar_negocio(negocio_id)) with check (public.pode_editar_negocio(negocio_id));
create policy negocio_participantes_ler on public.negocio_participantes for select to authenticated using ((select public.membro_ativo()));
create policy negocio_participantes_gerir on public.negocio_participantes for all to authenticated
  using (public.pode_editar_negocio(negocio_id)) with check (public.pode_editar_negocio(negocio_id));

-- Histórico: só leitura (escrito pelos gatilhos)
create policy negocio_historico_ler on public.negocio_historico for select to authenticated using ((select public.membro_ativo()));

-- Rodízio: leitura para o diretor
create policy rodizio_ler on public.rodizio_estado for select to authenticated
  using (public.eh_diretor_de(public.diretoria_do_funil(funil_id)));

-- Metas: todos leem; diretor da diretoria gerencia
create policy metas_ler on public.metas for select to authenticated using ((select public.membro_ativo()));
create policy metas_gerir on public.metas for all to authenticated
  using (public.eh_diretor_de(diretoria)) with check (public.eh_diretor_de(diretoria));

revoke all on function public.diretoria_do_funil(uuid), public.diretoria_da_fase(uuid),
  public.participa_do_negocio(uuid), public.pode_editar_empresa(uuid), public.pode_editar_negocio(uuid) from public, anon;
grant execute on function public.diretoria_do_funil(uuid), public.diretoria_da_fase(uuid),
  public.participa_do_negocio(uuid), public.pode_editar_empresa(uuid), public.pode_editar_negocio(uuid) to authenticated;

grant select, insert, update, delete on public.segmentos, public.origens, public.servicos, public.motivos,
  public.funis, public.fases, public.fase_campos, public.empresas, public.contatos, public.negocios,
  public.negocio_servicos, public.negocio_participantes, public.metas to authenticated;
grant select on public.negocio_historico, public.rodizio_estado to authenticated;
revoke all on public.segmentos, public.origens, public.servicos, public.motivos, public.funis, public.fases,
  public.fase_campos, public.empresas, public.contatos, public.negocios, public.negocio_servicos,
  public.negocio_participantes, public.negocio_historico, public.rodizio_estado, public.metas from anon;
