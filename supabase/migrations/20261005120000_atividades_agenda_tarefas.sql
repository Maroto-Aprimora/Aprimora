-- =====================================================================
-- Fase 2 — Atividades, agenda, tarefas, notificações e rotina
-- =====================================================================

create extension if not exists pg_net with schema extensions;

-- ---------------------------------------------------------------------
-- Membros: data de entrada (para "membros novos" nas metas) e processos seletivos
-- ---------------------------------------------------------------------
alter table public.membros add column data_entrada date;
alter table public.pre_cadastros add column data_entrada date;

create table public.processos_seletivos (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  data date not null unique,
  created_at timestamptz not null default now()
);
comment on table public.processos_seletivos is
  'Membros com data_entrada >= data do processo seletivo mais recente contam como "membros novos".';

insert into public.processos_seletivos (nome, data) values ('Processo seletivo 2026/2', '2026-08-01');
update public.pre_cadastros set data_entrada = '2026-08-01'
  where email in ('tiagotavares@aprimoraej.com', 'fredericomartins@aprimoraej.com', 'consani@aprimoraej.com', 'theoscamati@aprimoraej.com');

-- A data de entrada vem do pré-cadastro na criação da conta
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

  insert into public.membros (id, nome, email, data_entrada)
  values (new.id, v_pre.nome, lower(new.email), v_pre.data_entrada)
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

-- Só diretor altera ativo, e-mail ou data de entrada
create or replace function public.proteger_membro()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if (new.ativo is distinct from old.ativo or new.email is distinct from old.email
      or new.data_entrada is distinct from old.data_entrada) then
    if (select auth.uid()) is not null and not exists (
      select 1 from public.membro_diretorias md
      where md.membro_id = old.id and privado.eh_diretor_de(md.diretoria)
    ) then
      raise exception 'Apenas um diretor pode ativar, desativar ou alterar e-mail e data de entrada de um membro';
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
revoke all on function public.proteger_membro() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- Tipos de atividade (configuráveis). diretoria nula = atividade geral (todas as diretorias)
-- ---------------------------------------------------------------------
create type public.status_atividade as enum ('pendente', 'confirmada', 'realizada', 'cancelada');

create table public.tipos_atividade (
  id uuid primary key default gen_random_uuid(),
  diretoria text references public.diretorias (slug),
  chave text not null unique,
  nome text not null,
  cor text not null default 'marca',
  ligada_a_lead boolean not null default false,
  exige_confirmacao boolean not null default false,
  ordem smallint not null default 0,
  ativo boolean not null default true
);

insert into public.tipos_atividade (diretoria, chave, nome, cor, ligada_a_lead, exige_confirmacao, ordem) values
  ('comercial', 'diagnostico', 'Diagnóstico', 'destaque', true, true, 1),
  ('comercial', 'pre_escopo', 'Pré-escopo', 'marca', true, true, 2),
  ('comercial', 'apresentacao_proposta', 'Apresentação de proposta', 'sucesso', true, true, 3),
  ('comercial', 'coldcall', 'Coldcall', 'azul', true, false, 4),
  ('comercial', 'prospeccao_campo', 'Prospecção de campo', 'azul', true, true, 5),
  ('comercial', 'prospectday', 'ProspectDay', 'roxo', false, false, 6),
  ('comercial', 'evento_mej', 'Evento MEJ', 'roxo', false, false, 7),
  ('comercial', 'ri', 'R.I', 'cinza', false, false, 8),
  (null, 'rg', 'R.G', 'cinza', false, false, 9);

-- ---------------------------------------------------------------------
-- Atividades (visitas, diagnósticos, ligações, eventos...)
-- ---------------------------------------------------------------------
create table public.atividades (
  id uuid primary key default gen_random_uuid(),
  tipo_id uuid not null references public.tipos_atividade (id),
  diretoria text references public.diretorias (slug),
  titulo text not null,
  inicio timestamptz not null,
  fim timestamptz,
  dia_inteiro boolean not null default false,
  local text,
  link_reuniao text,
  empresa_id uuid references public.empresas (id) on delete set null,
  negocio_id uuid references public.negocios (id) on delete set null,
  responsavel_id uuid references public.membros (id) on delete set null default auth.uid(),
  status public.status_atividade not null default 'pendente',
  stakeholder text,
  resumo text,
  proximos_passos text,
  confirmada_em timestamptz,
  realizada_em timestamptz,
  criado_por uuid references public.membros (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (fim is null or fim >= inicio)
);
create index atividades_inicio_idx on public.atividades (inicio);
create index atividades_negocio_idx on public.atividades (negocio_id);
create index atividades_empresa_idx on public.atividades (empresa_id);
create index atividades_responsavel_idx on public.atividades (responsavel_id);

create table public.atividade_participantes (
  atividade_id uuid not null references public.atividades (id) on delete cascade,
  membro_id uuid not null references public.membros (id) on delete cascade,
  primary key (atividade_id, membro_id)
);
create index atividade_participantes_membro_idx on public.atividade_participantes (membro_id);

create trigger atividades_updated_at before update on public.atividades
  for each row execute function public.tocar_updated_at();

-- Herda a diretoria do tipo e carimba datas de confirmação/realização
create or replace function public.antes_de_salvar_atividade()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  select t.diretoria into new.diretoria from public.tipos_atividade t where t.id = new.tipo_id;
  if new.negocio_id is not null and new.empresa_id is null then
    select n.empresa_id into new.empresa_id from public.negocios n where n.id = new.negocio_id;
  end if;
  if tg_op = 'INSERT' or new.status is distinct from old.status then
    new.confirmada_em := case when new.status in ('confirmada', 'realizada') then coalesce(new.confirmada_em, now()) end;
    new.realizada_em := case when new.status = 'realizada' then coalesce(new.realizada_em, now()) end;
  end if;
  return new;
end;
$$;
revoke all on function public.antes_de_salvar_atividade() from public, anon, authenticated;
create trigger antes_de_salvar_atividade before insert or update on public.atividades
  for each row execute function public.antes_de_salvar_atividade();

-- ---------------------------------------------------------------------
-- Reuniões recorrentes (R.I semanal do Comercial, R.G de todas as diretorias)
-- Ocorrências são calculadas (não gravadas), então mudar o horário vale para as próximas.
-- ---------------------------------------------------------------------
create table public.reunioes_recorrentes (
  id uuid primary key default gen_random_uuid(),
  tipo_id uuid not null references public.tipos_atividade (id),
  diretoria text references public.diretorias (slug),
  titulo text not null,
  dia_semana smallint not null check (dia_semana between 0 and 6),
  hora_inicio time not null,
  hora_fim time not null,
  local text,
  valida_de date not null default current_date,
  valida_ate date,
  ativa boolean not null default true,
  created_at timestamptz not null default now(),
  check (hora_fim > hora_inicio)
);
comment on column public.reunioes_recorrentes.dia_semana is '0 = domingo, 1 = segunda … 6 = sábado';

insert into public.reunioes_recorrentes (tipo_id, diretoria, titulo, dia_semana, hora_inicio, hora_fim, valida_de)
select id, 'comercial', 'R.I — Reunião interna do Comercial', 1, time '15:30', time '16:40', date '2026-08-01' from public.tipos_atividade where chave = 'ri'
union all
select id, null, 'R.G — Reunião geral', 5, time '15:30', time '16:40', date '2026-08-01' from public.tipos_atividade where chave = 'rg';

-- ---------------------------------------------------------------------
-- Tarefas (só diretores distribuem; responsáveis atualizam o andamento)
-- ---------------------------------------------------------------------
create type public.prioridade as enum ('baixa', 'media', 'alta');
create type public.status_tarefa as enum ('pendente', 'em_andamento', 'concluida');

create table public.tarefas (
  id uuid primary key default gen_random_uuid(),
  diretoria text not null references public.diretorias (slug),
  titulo text not null,
  descricao text,
  prazo date,
  prioridade public.prioridade not null default 'media',
  status public.status_tarefa not null default 'pendente',
  negocio_id uuid references public.negocios (id) on delete set null,
  concluida_em timestamptz,
  criado_por uuid references public.membros (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index tarefas_prazo_idx on public.tarefas (prazo);

create table public.tarefa_responsaveis (
  tarefa_id uuid not null references public.tarefas (id) on delete cascade,
  membro_id uuid not null references public.membros (id) on delete cascade,
  primary key (tarefa_id, membro_id)
);
create index tarefa_responsaveis_membro_idx on public.tarefa_responsaveis (membro_id);

create trigger tarefas_updated_at before update on public.tarefas
  for each row execute function public.tocar_updated_at();

-- Responsável (não diretor) só pode mudar o status
create or replace function public.proteger_tarefa()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status is distinct from old.status then
    new.concluida_em := case when new.status = 'concluida' then now() end;
  end if;
  if (select auth.uid()) is not null and not privado.eh_diretor_de(old.diretoria) then
    if (new.titulo, new.descricao, new.prazo, new.prioridade, new.negocio_id, new.diretoria)
       is distinct from (old.titulo, old.descricao, old.prazo, old.prioridade, old.negocio_id, old.diretoria) then
      raise exception 'Só o diretor altera os dados da tarefa. Você pode atualizar o andamento.';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.proteger_tarefa() from public, anon, authenticated;
create trigger proteger_tarefa before update on public.tarefas
  for each row execute function public.proteger_tarefa();

-- ---------------------------------------------------------------------
-- Notificações (sino + push)
-- ---------------------------------------------------------------------
create table public.notificacoes (
  id uuid primary key default gen_random_uuid(),
  membro_id uuid not null references public.membros (id) on delete cascade,
  tipo text not null,
  titulo text not null,
  mensagem text,
  link text,
  chave text,
  lida_em timestamptz,
  created_at timestamptz not null default now(),
  unique (membro_id, chave)
);
create index notificacoes_membro_idx on public.notificacoes (membro_id, created_at desc);

create table public.push_assinaturas (
  id uuid primary key default gen_random_uuid(),
  membro_id uuid not null references public.membros (id) on delete cascade default auth.uid(),
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  user_agent text,
  created_at timestamptz not null default now()
);

-- Configurações internas (não expostas pela API): URL do envio de push e segredo compartilhado
create table privado.config (
  chave text primary key,
  valor text not null
);
revoke all on privado.config from public, anon, authenticated;

create or replace function privado.notificar(_membro uuid, _tipo text, _titulo text, _mensagem text, _link text, _chave text)
returns void language sql security definer set search_path = '' as $$
  insert into public.notificacoes (membro_id, tipo, titulo, mensagem, link, chave)
  select _membro, _tipo, _titulo, _mensagem, _link, _chave
  where exists (select 1 from public.membros m where m.id = _membro and m.ativo)
  on conflict (membro_id, chave) do nothing;
$$;
revoke all on function privado.notificar(uuid, text, text, text, text, text) from public, anon, authenticated;

-- Envia push para os dispositivos do membro (via rota /api/push do portal, assinada com segredo)
create or replace function public.enviar_push()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_url text := (select valor from privado.config where chave = 'push_url');
  v_segredo text := (select valor from privado.config where chave = 'push_segredo');
  v_assinaturas jsonb;
begin
  if v_url is null or v_segredo is null then return null; end if;
  select jsonb_agg(jsonb_build_object('endpoint', endpoint, 'keys', jsonb_build_object('p256dh', p256dh, 'auth', auth)))
    into v_assinaturas from public.push_assinaturas where membro_id = new.membro_id;
  if v_assinaturas is null then return null; end if;
  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-segredo', v_segredo),
    body := jsonb_build_object('assinaturas', v_assinaturas,
      'notificacao', jsonb_build_object('titulo', new.titulo, 'mensagem', new.mensagem, 'link', new.link, 'tag', new.tipo))
  );
  return null;
end;
$$;
revoke all on function public.enviar_push() from public, anon, authenticated;
create trigger enviar_push after insert on public.notificacoes
  for each row execute function public.enviar_push();

-- Lead atribuído a você (rodízio ou troca manual de responsável)
create or replace function public.notificar_responsavel_negocio()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.responsavel_id is not null
     and (tg_op = 'INSERT' or new.responsavel_id is distinct from old.responsavel_id)
     and new.responsavel_id is distinct from (select auth.uid()) then
    perform privado.notificar(new.responsavel_id, 'lead_atribuido', 'Novo lead para você',
      new.titulo || ' agora está sob sua responsabilidade.', '/negocios/' || new.id,
      'lead_atribuido:' || new.id || ':' || extract(epoch from now())::bigint);
  end if;
  return null;
end;
$$;
revoke all on function public.notificar_responsavel_negocio() from public, anon, authenticated;
-- Sem "update of responsavel_id": o rodízio muda o responsável dentro de outro gatilho, e
-- "update of" só considera as colunas do comando UPDATE original.
create trigger notificar_responsavel_negocio after insert or update on public.negocios
  for each row execute function public.notificar_responsavel_negocio();

-- Quem recebe avisos de um negócio: o responsável; sem responsável, os diretores da diretoria
create or replace function privado.destinatarios_negocio(_responsavel uuid, _diretoria text)
returns setof uuid language sql stable security definer set search_path = '' as $$
  select _responsavel where _responsavel is not null
  union
  select md.membro_id from public.membro_diretorias md
  where _responsavel is null and md.diretoria = _diretoria and md.cargo = 'diretor';
$$;
revoke all on function privado.destinatarios_negocio(uuid, text) from public, anon, authenticated;

-- Notificações diárias (8h10 de Brasília, depois da aplicação dos SLAs)
create or replace function privado.gerar_notificacoes_diarias()
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_hoje date := (now() at time zone 'America/Sao_Paulo')::date;
  v_dow int := extract(dow from v_hoje);
  r record;
  n integer := 0;
begin
  -- SLA próximo de estourar (80%) e estourado: para o responsável (ou o diretor, se não houver)
  for r in
    select ng.id, ng.titulo, ng.entrou_na_fase_em, f.nome as fase, f.sla_dias, fu.diretoria,
           floor(extract(epoch from (now() - ng.entrou_na_fase_em)) / 86400)::int as dias,
           ng.responsavel_id
    from public.negocios ng join public.fases f on f.id = ng.fase_id join public.funis fu on fu.id = ng.funil_id
    where f.sla_dias is not null and ng.encerrado_em is null
  loop
    if r.dias >= r.sla_dias then
      perform privado.notificar(dest, 'sla_estourado', 'SLA estourado',
        format('%s está há %s dias em "%s" (SLA de %s dias).', r.titulo, r.dias, r.fase, r.sla_dias),
        '/negocios/' || r.id, format('sla_estourado:%s:%s', r.id, r.entrou_na_fase_em))
      from privado.destinatarios_negocio(r.responsavel_id, r.diretoria) dest;
      n := n + 1;
    elsif r.dias >= ceil(r.sla_dias * 0.8) then
      perform privado.notificar(dest, 'sla_proximo', 'SLA perto de estourar',
        format('%s: faltam %s dias para estourar o SLA de "%s".', r.titulo, r.sla_dias - r.dias, r.fase),
        '/negocios/' || r.id, format('sla_proximo:%s:%s', r.id, r.entrou_na_fase_em))
      from privado.destinatarios_negocio(r.responsavel_id, r.diretoria) dest;
      n := n + 1;
    end if;
  end loop;

  -- Tarefas vencendo hoje
  for r in
    select t.id, t.titulo, tr.membro_id from public.tarefas t join public.tarefa_responsaveis tr on tr.tarefa_id = t.id
    where t.prazo = v_hoje and t.status <> 'concluida'
  loop
    perform privado.notificar(r.membro_id, 'tarefa_hoje', 'Tarefa vence hoje', r.titulo, '/tarefas',
      format('tarefa_hoje:%s:%s', r.id, v_hoje));
    n := n + 1;
  end loop;

  -- R.I e R.G no dia
  for r in
    select rr.id, rr.titulo, rr.hora_inicio, rr.local, rr.diretoria from public.reunioes_recorrentes rr
    where rr.ativa and rr.dia_semana = v_dow and rr.valida_de <= v_hoje and (rr.valida_ate is null or rr.valida_ate >= v_hoje)
  loop
    perform privado.notificar(m.id, 'reuniao_hoje', r.titulo || ' hoje',
      format('Hoje às %s%s.', to_char(r.hora_inicio, 'HH24:MI'), coalesce(' · ' || r.local, '')), '/agenda',
      format('reuniao:%s:%s', r.id, v_hoje))
    from public.membros m
    where m.ativo and (r.diretoria is null or exists (
      select 1 from public.membro_diretorias md where md.membro_id = m.id and md.diretoria = r.diretoria));
    n := n + 1;
  end loop;

  -- Atividades de amanhã ainda sem confirmação: avisa os diretores da diretoria
  for r in
    select a.id, a.titulo, a.inicio, a.diretoria from public.atividades a join public.tipos_atividade t on t.id = a.tipo_id
    where t.exige_confirmacao and a.status = 'pendente'
      and (a.inicio at time zone 'America/Sao_Paulo')::date = v_hoje + 1
  loop
    perform privado.notificar(md.membro_id, 'atividade_sem_confirmacao', 'Atividade de amanhã sem confirmação',
      format('%s (%s) ainda não foi confirmada.', r.titulo, to_char(r.inicio at time zone 'America/Sao_Paulo', 'DD/MM HH24:MI')),
      '/agenda', format('sem_confirmacao:%s', r.id))
    from public.membro_diretorias md where md.diretoria = coalesce(r.diretoria, 'comercial') and md.cargo = 'diretor';
    n := n + 1;
  end loop;

  return n;
end;
$$;
revoke all on function privado.gerar_notificacoes_diarias() from public, anon, authenticated;

select cron.schedule('notificacoes-diarias', '10 11 * * *', 'select privado.gerar_notificacoes_diarias()');

-- ---------------------------------------------------------------------
-- Transferência de carteira (diretor passa os registros de um membro para outro)
-- ---------------------------------------------------------------------
create or replace function public.transferir_carteira(_de uuid, _para uuid, _diretoria text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_neg int; v_tar int; v_ati int;
begin
  if not privado.eh_diretor_de(_diretoria) then
    raise exception 'Só o diretor da diretoria pode transferir carteiras';
  end if;
  if not exists (select 1 from public.membro_diretorias md join public.membros m on m.id = md.membro_id
                 where md.membro_id = _para and md.diretoria = _diretoria and m.ativo) then
    raise exception 'O destino precisa ser um membro ativo da diretoria';
  end if;

  update public.negocios n set responsavel_id = _para
    from public.funis f where f.id = n.funil_id and f.diretoria = _diretoria
      and n.responsavel_id = _de and n.encerrado_em is null;
  get diagnostics v_neg = row_count;

  -- Passa as tarefas abertas para o destino (se ele já for responsável, a linha antiga fica com o membro de origem)
  update public.tarefa_responsaveis tr set membro_id = _para
    from public.tarefas t
    where t.id = tr.tarefa_id and tr.membro_id = _de and t.diretoria = _diretoria and t.status <> 'concluida'
      and not exists (select 1 from public.tarefa_responsaveis x where x.tarefa_id = tr.tarefa_id and x.membro_id = _para);
  get diagnostics v_tar = row_count;

  update public.atividades set responsavel_id = _para
    where responsavel_id = _de and diretoria = _diretoria and inicio >= now() and status in ('pendente', 'confirmada');
  get diagnostics v_ati = row_count;

  perform privado.registrar_auditoria('carteira_transferida', 'membros', _de::text,
    jsonb_build_object('para', _para, 'diretoria', _diretoria, 'negocios', v_neg, 'tarefas', v_tar, 'atividades', v_ati));
  return jsonb_build_object('negocios', v_neg, 'tarefas', v_tar, 'atividades', v_ati);
end;
$$;
revoke all on function public.transferir_carteira(uuid, uuid, text) from public, anon;
grant execute on function public.transferir_carteira(uuid, uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------
create or replace function privado.participa_da_atividade(_atividade uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.atividades a where a.id = _atividade and a.responsavel_id = (select auth.uid()))
      or exists (select 1 from public.atividade_participantes p where p.atividade_id = _atividade and p.membro_id = (select auth.uid()));
$$;
create or replace function privado.pode_gerir_atividade(_atividade uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.atividades a where a.id = _atividade
    and (privado.participa_da_atividade(a.id)
         or (a.diretoria is null and privado.eh_diretor())
         or (a.diretoria is not null and privado.eh_diretor_de(a.diretoria))));
$$;
create or replace function privado.responsavel_da_tarefa(_tarefa uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.tarefa_responsaveis tr where tr.tarefa_id = _tarefa and tr.membro_id = (select auth.uid()));
$$;
revoke all on function privado.participa_da_atividade(uuid), privado.pode_gerir_atividade(uuid),
  privado.responsavel_da_tarefa(uuid) from public, anon;
grant execute on function privado.participa_da_atividade(uuid), privado.pode_gerir_atividade(uuid),
  privado.responsavel_da_tarefa(uuid) to authenticated;

alter table public.processos_seletivos enable row level security;
alter table public.tipos_atividade enable row level security;
alter table public.atividades enable row level security;
alter table public.atividade_participantes enable row level security;
alter table public.reunioes_recorrentes enable row level security;
alter table public.tarefas enable row level security;
alter table public.tarefa_responsaveis enable row level security;
alter table public.notificacoes enable row level security;
alter table public.push_assinaturas enable row level security;

create policy processos_ler on public.processos_seletivos for select to authenticated using ((select privado.membro_ativo()));
create policy processos_gerir on public.processos_seletivos for all to authenticated
  using ((select privado.eh_diretor())) with check ((select privado.eh_diretor()));

create policy tipos_atividade_ler on public.tipos_atividade for select to authenticated using ((select privado.membro_ativo()));
create policy tipos_atividade_gerir on public.tipos_atividade for all to authenticated
  using (case when diretoria is null then privado.eh_diretor() else privado.eh_diretor_de(diretoria) end)
  with check (case when diretoria is null then privado.eh_diretor() else privado.eh_diretor_de(diretoria) end);

-- Agenda é da equipe: todos os membros ativos veem (para saber quem está onde)
create policy atividades_ler on public.atividades for select to authenticated using ((select privado.membro_ativo()));
create policy atividades_criar on public.atividades for insert to authenticated
  with check (
    (select privado.membro_ativo()) and exists (select 1 from public.tipos_atividade t where t.id = tipo_id
      and (case when t.diretoria is null then privado.eh_diretor() else privado.pertence_a(t.diretoria) end)));
create policy atividades_editar on public.atividades for update to authenticated
  using (privado.pode_gerir_atividade(id)) with check (privado.pode_gerir_atividade(id));
create policy atividades_excluir on public.atividades for delete to authenticated
  using (privado.pode_gerir_atividade(id) and coalesce(privado.cargo_em(coalesce(diretoria, 'comercial')), 'diretor') <> 'trainee');

create policy atividade_participantes_ler on public.atividade_participantes for select to authenticated using ((select privado.membro_ativo()));
create policy atividade_participantes_gerir on public.atividade_participantes for all to authenticated
  using (privado.pode_gerir_atividade(atividade_id)) with check (privado.pode_gerir_atividade(atividade_id));

create policy reunioes_ler on public.reunioes_recorrentes for select to authenticated using ((select privado.membro_ativo()));
create policy reunioes_gerir on public.reunioes_recorrentes for all to authenticated
  using (case when diretoria is null then privado.eh_diretor() else privado.eh_diretor_de(diretoria) end)
  with check (case when diretoria is null then privado.eh_diretor() else privado.eh_diretor_de(diretoria) end);

-- Tarefas: membros da diretoria veem; só diretor cria/exclui; responsável atualiza o andamento
create policy tarefas_ler on public.tarefas for select to authenticated
  using (privado.pertence_a(diretoria) or privado.eh_diretor());
create policy tarefas_criar on public.tarefas for insert to authenticated with check (privado.eh_diretor_de(diretoria));
create policy tarefas_editar on public.tarefas for update to authenticated
  using (privado.eh_diretor_de(diretoria) or privado.responsavel_da_tarefa(id))
  with check (privado.eh_diretor_de(diretoria) or privado.responsavel_da_tarefa(id));
create policy tarefas_excluir on public.tarefas for delete to authenticated using (privado.eh_diretor_de(diretoria));

create policy tarefa_responsaveis_ler on public.tarefa_responsaveis for select to authenticated using ((select privado.membro_ativo()));
create policy tarefa_responsaveis_gerir on public.tarefa_responsaveis for all to authenticated
  using (exists (select 1 from public.tarefas t where t.id = tarefa_id and privado.eh_diretor_de(t.diretoria)))
  with check (exists (select 1 from public.tarefas t where t.id = tarefa_id and privado.eh_diretor_de(t.diretoria)));

-- Notificações: cada um vê e marca como lidas só as suas
create policy notificacoes_ler on public.notificacoes for select to authenticated using (membro_id = (select auth.uid()));
create policy notificacoes_marcar on public.notificacoes for update to authenticated
  using (membro_id = (select auth.uid())) with check (membro_id = (select auth.uid()));
create policy notificacoes_apagar on public.notificacoes for delete to authenticated using (membro_id = (select auth.uid()));

create policy push_ler on public.push_assinaturas for select to authenticated using (membro_id = (select auth.uid()));
create policy push_criar on public.push_assinaturas for insert to authenticated with check (membro_id = (select auth.uid()));
create policy push_apagar on public.push_assinaturas for delete to authenticated using (membro_id = (select auth.uid()));

grant select on public.processos_seletivos, public.tipos_atividade, public.reunioes_recorrentes to authenticated;
grant insert, update, delete on public.processos_seletivos, public.tipos_atividade, public.reunioes_recorrentes to authenticated;
grant select, insert, update, delete on public.atividades, public.atividade_participantes, public.tarefas,
  public.tarefa_responsaveis to authenticated;
grant select, delete on public.notificacoes to authenticated;
grant update (lida_em) on public.notificacoes to authenticated;
grant select, insert, delete on public.push_assinaturas to authenticated;
revoke all on public.processos_seletivos, public.tipos_atividade, public.atividades, public.atividade_participantes,
  public.reunioes_recorrentes, public.tarefas, public.tarefa_responsaveis, public.notificacoes,
  public.push_assinaturas from anon;
