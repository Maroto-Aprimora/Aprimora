-- =====================================================================
-- Fase 0 — Fundação: diretorias, membros, cargos, pré-cadastros e auditoria
-- Regra de ouro: cargo e diretoria NUNCA vêm do navegador do usuário.
-- Eles só existem em tabelas que apenas diretores podem alterar (RLS).
-- =====================================================================

create type public.cargo as enum ('diretor', 'assessor', 'trainee');

-- ---------------------------------------------------------------------
-- Diretorias
-- ---------------------------------------------------------------------
create table public.diretorias (
  slug text primary key,
  nome text not null,
  ordem smallint not null default 0,
  ativa boolean not null default true
);
comment on table public.diretorias is 'As diretorias da Aprimora. Presidência = Jurídico-Financeiro.';

insert into public.diretorias (slug, nome, ordem) values
  ('comercial', 'Comercial', 1),
  ('projetos', 'Projetos', 2),
  ('presidencia', 'Presidência', 3),
  ('rh', 'Recursos Humanos', 4),
  ('marketing', 'Marketing', 5);

-- ---------------------------------------------------------------------
-- Membros (1 linha por usuário autenticado)
-- ---------------------------------------------------------------------
create table public.membros (
  id uuid primary key references auth.users (id) on delete cascade,
  nome text not null,
  email text not null unique,
  telefone text,
  avatar_url text,
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Um membro pode ter cargo em mais de uma diretoria (ex.: Presidência + RH).
create table public.membro_diretorias (
  membro_id uuid not null references public.membros (id) on delete cascade,
  diretoria text not null references public.diretorias (slug),
  cargo public.cargo not null,
  participa_rodizio boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (membro_id, diretoria)
);
create index membro_diretorias_diretoria_idx on public.membro_diretorias (diretoria);

-- ---------------------------------------------------------------------
-- Pré-cadastros (convites): só quem está aqui consegue criar conta
-- ---------------------------------------------------------------------
create table public.pre_cadastros (
  id uuid primary key default gen_random_uuid(),
  email text not null unique check (email = lower(email)),
  nome text not null,
  criado_por uuid references public.membros (id) on delete set null,
  convite_enviado_em timestamptz,
  aceito_em timestamptz,
  created_at timestamptz not null default now()
);

create table public.pre_cadastro_diretorias (
  pre_cadastro_id uuid not null references public.pre_cadastros (id) on delete cascade,
  diretoria text not null references public.diretorias (slug),
  cargo public.cargo not null,
  primary key (pre_cadastro_id, diretoria)
);

-- ---------------------------------------------------------------------
-- Auditoria de ações sensíveis
-- ---------------------------------------------------------------------
create table public.auditoria (
  id bigint generated always as identity primary key,
  autor_id uuid,
  acao text not null,
  entidade text not null,
  entidade_id text,
  dados jsonb,
  created_at timestamptz not null default now()
);
create index auditoria_created_at_idx on public.auditoria (created_at desc);

-- ---------------------------------------------------------------------
-- Funções auxiliares de permissão (usadas pelas políticas RLS)
-- SECURITY DEFINER para evitar recursão de RLS; search_path vazio por segurança.
-- ---------------------------------------------------------------------
create or replace function public.membro_ativo()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.membros m where m.id = (select auth.uid()) and m.ativo);
$$;

create or replace function public.cargo_em(_diretoria text)
returns public.cargo language sql stable security definer set search_path = '' as $$
  select md.cargo
  from public.membro_diretorias md
  join public.membros m on m.id = md.membro_id
  where md.membro_id = (select auth.uid()) and md.diretoria = _diretoria and m.ativo;
$$;

create or replace function public.eh_diretor_de(_diretoria text)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(public.cargo_em(_diretoria) = 'diretor', false);
$$;

create or replace function public.eh_diretor()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.membro_diretorias md
    join public.membros m on m.id = md.membro_id
    where md.membro_id = (select auth.uid()) and md.cargo = 'diretor' and m.ativo
  );
$$;

create or replace function public.pertence_a(_diretoria text)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.cargo_em(_diretoria) is not null;
$$;

revoke all on function public.membro_ativo(), public.cargo_em(text), public.eh_diretor_de(text),
  public.eh_diretor(), public.pertence_a(text) from public, anon;
grant execute on function public.membro_ativo(), public.cargo_em(text), public.eh_diretor_de(text),
  public.eh_diretor(), public.pertence_a(text) to authenticated;

-- ---------------------------------------------------------------------
-- Registro de auditoria (chamado pelos gatilhos)
-- ---------------------------------------------------------------------
create or replace function public.registrar_auditoria(_acao text, _entidade text, _entidade_id text, _dados jsonb)
returns void language sql security definer set search_path = '' as $$
  insert into public.auditoria (autor_id, acao, entidade, entidade_id, dados)
  values ((select auth.uid()), _acao, _entidade, _entidade_id, _dados);
$$;
revoke all on function public.registrar_auditoria(text, text, text, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- Criação de conta: só e-mails pré-cadastrados. Cargo vem do pré-cadastro.
-- Se o e-mail não estiver pré-cadastrado, a criação do usuário é abortada.
-- ---------------------------------------------------------------------
create or replace function public.ao_criar_usuario()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_pre public.pre_cadastros%rowtype;
begin
  select * into v_pre from public.pre_cadastros where email = lower(new.email);
  if not found then
    raise exception 'E-mail % não está pré-cadastrado no Portal Aprimora', new.email
      using errcode = 'P0001';
  end if;

  insert into public.membros (id, nome, email)
  values (new.id, v_pre.nome, lower(new.email))
  on conflict (id) do nothing;

  insert into public.membro_diretorias (membro_id, diretoria, cargo)
  select new.id, pd.diretoria, pd.cargo
  from public.pre_cadastro_diretorias pd
  where pd.pre_cadastro_id = v_pre.id
  on conflict do nothing;

  update public.pre_cadastros set aceito_em = now() where id = v_pre.id;
  return new;
end;
$$;
revoke all on function public.ao_criar_usuario() from public, anon, authenticated;

create trigger ao_criar_usuario
  after insert on auth.users
  for each row execute function public.ao_criar_usuario();

-- ---------------------------------------------------------------------
-- Proteções em membros e cargos
-- ---------------------------------------------------------------------
create or replace function public.tocar_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger membros_updated_at before update on public.membros
  for each row execute function public.tocar_updated_at();

-- Só um diretor de alguma diretoria do membro pode mudar "ativo" ou e-mail.
create or replace function public.proteger_membro()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if (new.ativo is distinct from old.ativo or new.email is distinct from old.email) then
    if (select auth.uid()) is not null and not exists (
      select 1 from public.membro_diretorias md
      where md.membro_id = old.id and public.eh_diretor_de(md.diretoria)
    ) then
      raise exception 'Apenas um diretor pode ativar, desativar ou alterar o e-mail de um membro';
    end if;
    if new.ativo is distinct from old.ativo then
      perform public.registrar_auditoria(
        case when new.ativo then 'membro_reativado' else 'membro_desativado' end,
        'membros', old.id::text, jsonb_build_object('nome', old.nome));
    end if;
  end if;
  return new;
end;
$$;

create trigger proteger_membro before update on public.membros
  for each row execute function public.proteger_membro();

-- Uma diretoria nunca pode ficar sem diretor ativo.
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
  perform public.registrar_auditoria(
    'cargo_' || lower(tg_op), 'membro_diretorias',
    coalesce(new.membro_id, old.membro_id)::text,
    jsonb_build_object('diretoria', v_diretoria, 'de', old.cargo, 'para', new.cargo));
  return coalesce(new, old);
end;
$$;

create trigger garantir_diretor after insert or update or delete on public.membro_diretorias
  for each row execute function public.garantir_diretor();

-- ---------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------
alter table public.diretorias enable row level security;
alter table public.membros enable row level security;
alter table public.membro_diretorias enable row level security;
alter table public.pre_cadastros enable row level security;
alter table public.pre_cadastro_diretorias enable row level security;
alter table public.auditoria enable row level security;

create policy diretorias_ler on public.diretorias for select to authenticated
  using ((select public.membro_ativo()));

create policy membros_ler on public.membros for select to authenticated
  using ((select public.membro_ativo()));
create policy membros_editar on public.membros for update to authenticated
  using (id = (select auth.uid()) or exists (
    select 1 from public.membro_diretorias md
    where md.membro_id = membros.id and public.eh_diretor_de(md.diretoria)))
  with check (id = (select auth.uid()) or exists (
    select 1 from public.membro_diretorias md
    where md.membro_id = membros.id and public.eh_diretor_de(md.diretoria)));

create policy cargos_ler on public.membro_diretorias for select to authenticated
  using ((select public.membro_ativo()));
create policy cargos_inserir on public.membro_diretorias for insert to authenticated
  with check (public.eh_diretor_de(diretoria));
create policy cargos_editar on public.membro_diretorias for update to authenticated
  using (public.eh_diretor_de(diretoria)) with check (public.eh_diretor_de(diretoria));
create policy cargos_remover on public.membro_diretorias for delete to authenticated
  using (public.eh_diretor_de(diretoria));

create policy pre_cadastros_ler on public.pre_cadastros for select to authenticated
  using ((select public.eh_diretor()));
create policy pre_cadastros_inserir on public.pre_cadastros for insert to authenticated
  with check ((select public.eh_diretor()));
create policy pre_cadastros_editar on public.pre_cadastros for update to authenticated
  using ((select public.eh_diretor())) with check ((select public.eh_diretor()));
create policy pre_cadastros_remover on public.pre_cadastros for delete to authenticated
  using ((select public.eh_diretor()) and aceito_em is null);

create policy pre_vinculos_ler on public.pre_cadastro_diretorias for select to authenticated
  using ((select public.eh_diretor()));
create policy pre_vinculos_inserir on public.pre_cadastro_diretorias for insert to authenticated
  with check (public.eh_diretor_de(diretoria));
create policy pre_vinculos_editar on public.pre_cadastro_diretorias for update to authenticated
  using (public.eh_diretor_de(diretoria)) with check (public.eh_diretor_de(diretoria));
create policy pre_vinculos_remover on public.pre_cadastro_diretorias for delete to authenticated
  using (public.eh_diretor_de(diretoria));

create policy auditoria_ler on public.auditoria for select to authenticated
  using ((select public.eh_diretor()));

-- Permissões de tabela (RLS continua valendo por cima)
grant select on public.diretorias to authenticated;
grant select, update on public.membros to authenticated;
grant select, insert, update, delete on public.membro_diretorias to authenticated;
grant select, insert, update, delete on public.pre_cadastros to authenticated;
grant select, insert, update, delete on public.pre_cadastro_diretorias to authenticated;
grant select on public.auditoria to authenticated;
revoke all on public.diretorias, public.membros, public.membro_diretorias, public.pre_cadastros,
  public.pre_cadastro_diretorias, public.auditoria from anon;
