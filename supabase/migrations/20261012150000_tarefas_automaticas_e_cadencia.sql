-- =====================================================================
-- v2 · Fase 0 · PR 5 — Tarefas automáticas e cadência (PE-PA-002, Seções 3.2, 4 e 6)
-- - O assessor cria tarefas para si mesmo (o diretor continua criando para qualquer um)
-- - Cadência padrão configurável (cadencia_passos) e job diário às 07h30 que cria as tarefas do dia
-- - D21 sem contato efetivo: o card vai sozinho para a Reciclagem, com retorno em 90 dias
-- - Tarefas ao entrar em Oportunidade, ao voltar da Reciclagem e nos compromissos do dia
-- =====================================================================

-- ---------------------------------------------------------------------
-- Tarefas pessoais: o assessor cria, edita e exclui as tarefas manuais que criou para si
-- ---------------------------------------------------------------------
create or replace function privado.tarefa_pessoal(_tarefa uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.tarefas t
    where t.id = _tarefa and t.origem = 'manual' and t.criado_por = (select auth.uid())
  )
$$;

alter policy tarefas_criar on public.tarefas
  with check (privado.eh_diretor_de(diretoria)
              or (origem = 'manual' and criado_por = (select auth.uid()) and privado.pertence_a(diretoria)));
alter policy tarefas_excluir on public.tarefas
  using (privado.eh_diretor_de(diretoria) or privado.tarefa_pessoal(id));

-- Na tarefa pessoal, o único responsável possível é quem a criou
alter policy tarefa_responsaveis_gerir on public.tarefa_responsaveis
  using (exists (select 1 from public.tarefas t where t.id = tarefa_responsaveis.tarefa_id and privado.eh_diretor_de(t.diretoria))
         or (membro_id = (select auth.uid()) and privado.tarefa_pessoal(tarefa_id)))
  with check (exists (select 1 from public.tarefas t where t.id = tarefa_responsaveis.tarefa_id and privado.eh_diretor_de(t.diretoria))
              or (membro_id = (select auth.uid()) and privado.tarefa_pessoal(tarefa_id)));

-- Quem não é diretor só muda o andamento, exceto nas tarefas pessoais
create or replace function public.proteger_tarefa()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status is distinct from old.status then
    new.concluida_em := case when new.status = 'concluida' then now() end;
  end if;
  if (select auth.uid()) is not null and not privado.eh_diretor_de(old.diretoria) then
    if (new.origem, new.chave, new.criado_por, new.atividade_id) is distinct from (old.origem, old.chave, old.criado_por, old.atividade_id) then
      raise exception 'A origem da tarefa não pode ser alterada.';
    end if;
    if not (old.origem = 'manual' and old.criado_por = (select auth.uid()))
       and (new.titulo, new.descricao, new.prazo, new.prioridade, new.negocio_id, new.diretoria)
           is distinct from (old.titulo, old.descricao, old.prazo, old.prioridade, old.negocio_id, old.diretoria) then
      raise exception 'Só o diretor altera os dados da tarefa. Você pode atualizar o andamento.';
    end if;
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------
-- Cadência padrão (Seção 3.2), editável pelo diretor
-- ---------------------------------------------------------------------
create type public.canal_cadencia as enum ('email', 'ligacao');

create table public.cadencia_passos (
  id uuid primary key default gen_random_uuid(),
  diretoria text not null default 'comercial' references public.diretorias (slug),
  dia integer not null check (dia >= 0),             -- dias corridos desde a entrada em E-mail (D0); fim de semana/feriado vai para o próximo dia útil
  canal public.canal_cadencia not null,
  titulo text not null,
  descricao text,
  so_sem_contato boolean not null default false,     -- só se ainda não houve contato efetivo
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger cadencia_passos_updated_at before update on public.cadencia_passos
  for each row execute function public.tocar_updated_at();
alter table public.cadencia_passos enable row level security;
create policy cadencia_passos_ler on public.cadencia_passos for select to authenticated using ((select privado.membro_ativo()));
create policy cadencia_passos_gerir on public.cadencia_passos for all to authenticated
  using (privado.eh_diretor_de(diretoria)) with check (privado.eh_diretor_de(diretoria));
revoke all on public.cadencia_passos from anon;

insert into public.cadencia_passos (dia, canal, titulo, descricao, so_sem_contato) values
  (0,  'email',   'E-mail 1: apresentação personalizada', 'Até a Fase 3 o e-mail é enviado manualmente.', false),
  (3,  'email',   'E-mail 2: follow-up curto, com um caso ou dado do segmento', null, false),
  (7,  'ligacao', 'Ligação 1 da cadência', 'Mova o card para Coldcall (semana 1) e registre o resultado.', false),
  (8,  'email',   'E-mail 3: "tentei falar com você"', 'Só se não houve contato na ligação 1.', true),
  (14, 'ligacao', 'Ligação 2 da cadência', 'Mova o card para Coldcall (semana 2) e registre o resultado.', false),
  (15, 'email',   'E-mail 4: encerramento cordial, deixando a porta aberta', null, true);

-- Parâmetros da cadência (D21 → Reciclagem com retorno em 90 dias)
create table public.parametros_comercial (
  diretoria text primary key references public.diretorias (slug),
  cadencia_dias_reciclagem integer not null default 21 check (cadencia_dias_reciclagem > 0),
  reciclagem_retorno_dias integer not null default 90 check (reciclagem_retorno_dias > 0),
  updated_at timestamptz not null default now()
);
alter table public.parametros_comercial enable row level security;
create policy parametros_comercial_ler on public.parametros_comercial for select to authenticated using ((select privado.membro_ativo()));
create policy parametros_comercial_gerir on public.parametros_comercial for update to authenticated
  using (privado.eh_diretor_de(diretoria)) with check (privado.eh_diretor_de(diretoria));
revoke all on public.parametros_comercial from anon;
insert into public.parametros_comercial (diretoria) values ('comercial');

-- O follow-up de Oportunidade agora nasce ao entrar na fase (vale também para movimentos manuais)
update public.resultados_ligacao set tarefa_titulo = null, tarefa_prazo = null where chave = 'interessado_sem_data';

-- ---------------------------------------------------------------------
-- Início da cadência (D0) e contato efetivo
-- ---------------------------------------------------------------------
-- D0 = última entrada na fase E-mail
create or replace function privado.inicio_cadencia(_negocio uuid)
returns date language sql stable security definer set search_path = '' as $$
  select max((h.created_at at time zone 'America/Sao_Paulo')::date)
  from public.negocio_historico h join public.fases f on f.id = h.fase_destino_id
  where h.negocio_id = _negocio and f.chave = 'email'
$$;

-- Houve contato efetivo (ligação cujo resultado não é só tentativa) desde a data
create or replace function privado.teve_contato(_negocio uuid, _desde date)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.ligacoes l join public.resultados_ligacao r on r.id = l.resultado_id
    where l.negocio_id = _negocio and not r.conta_tentativa
      and (l.inicio at time zone 'America/Sao_Paulo')::date >= _desde
  )
$$;

-- ---------------------------------------------------------------------
-- Tarefas ao mudar de fase: follow-up de Oportunidade e retorno da Reciclagem
-- ---------------------------------------------------------------------
create or replace function public.tarefas_ao_mudar_fase()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  n public.negocios%rowtype;
  f_destino public.fases%rowtype;
  f_origem public.fases%rowtype;
  v_empresa text;
  v_hoje date := privado.hoje();
begin
  select * into n from public.negocios where id = new.negocio_id;
  select * into f_destino from public.fases where id = new.fase_destino_id;
  select * into f_origem from public.fases where id = new.fase_origem_id;
  select nome into v_empresa from public.empresas where id = n.empresa_id;
  if n.responsavel_id is null then return null; end if;

  -- Saiu da fase: tarefas de cadência abertas deixam de valer
  if f_origem.macroetapa = 'cadencia' and f_destino.macroetapa is distinct from 'cadencia' then
    update public.tarefas set status = 'concluida'
     where negocio_id = n.id and status <> 'concluida' and chave like 'cadencia:%';
  end if;

  if f_destino.chave = 'oportunidade' then
    perform privado.criar_tarefa(n.responsavel_id, 'Follow-up para marcar o diagnóstico · ' || coalesce(v_empresa, n.titulo),
      privado.dia_util(v_hoje + 1), n.id, format('oportunidade:%s:%s', n.id, new.id),
      'O lead tem interesse. O SLA para marcar o diagnóstico é de 15 dias.');
  end if;

  if f_origem.tipo = 'pausa' and new.automatico then
    perform privado.criar_tarefa(n.responsavel_id, 'Retomar contato (voltou da Reciclagem) · ' || coalesce(v_empresa, n.titulo),
      privado.dia_util(v_hoje), n.id, format('reciclagem:%s:%s', n.id, new.id));
  end if;
  return null;
end;
$$;
create trigger tarefas_ao_mudar_fase after insert on public.negocio_historico
  for each row execute function public.tarefas_ao_mudar_fase();

-- Compromisso realizado, cancelado ou remarcado: a tarefa ligada a ele está resolvida
create or replace function public.concluir_tarefas_da_atividade()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status is distinct from old.status and new.status::text in ('realizada', 'cancelada', 'remarcada') then
    update public.tarefas set status = 'concluida'
     where atividade_id = new.id and status <> 'concluida' and chave like 'compromisso:%';
  end if;
  return null;
end;
$$;
create trigger concluir_tarefas_da_atividade after update of status on public.atividades
  for each row execute function public.concluir_tarefas_da_atividade();

-- ---------------------------------------------------------------------
-- Job diário (07h30 de Brasília): cadência, D21 → Reciclagem e compromissos do dia
-- ---------------------------------------------------------------------
create or replace function privado.gerar_tarefas_diarias()
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_hoje date := privado.hoje();
  p public.parametros_comercial%rowtype;
  r record;
  passo record;
  v_d0 date;
  v_prazo date;
  v_reciclagem uuid;
  n integer := 0;
begin
  -- Só em dia útil; o que venceu no fim de semana ou feriado é criado no dia útil seguinte
  if privado.dia_util(v_hoje) <> v_hoje then return 0; end if;
  select * into p from public.parametros_comercial where diretoria = 'comercial';
  select f.id into v_reciclagem from public.fases f join public.funis fu on fu.id = f.funil_id
   where fu.diretoria = 'comercial' and f.chave = 'reciclagem' and f.ativa and f.excluida_em is null;

  for r in
    select ng.id, ng.titulo, ng.responsavel_id, e.nome as empresa
    from public.negocios ng join public.fases f on f.id = ng.fase_id join public.empresas e on e.id = ng.empresa_id
    where f.macroetapa = 'cadencia' and f.chave in ('email', 'coldcall_1', 'coldcall_2')
      and ng.encerrado_em is null and ng.responsavel_id is not null
  loop
    v_d0 := privado.inicio_cadencia(r.id);
    continue when v_d0 is null;

    -- D21 sem contato efetivo: Reciclagem com data de retorno
    if v_reciclagem is not null and v_d0 + p.cadencia_dias_reciclagem <= v_hoje and not privado.teve_contato(r.id, v_d0) then
      perform set_config('aprimora.movimento_automatico', 'sim', true);
      perform set_config('aprimora.comentario_movimento',
        format('Cadência encerrada sem resposta (D%s)', p.cadencia_dias_reciclagem), true);
      update public.negocios set fase_id = v_reciclagem, retorno_em = v_hoje + p.reciclagem_retorno_dias where id = r.id;
      perform set_config('aprimora.movimento_automatico', '', true);
      perform set_config('aprimora.comentario_movimento', '', true);
      n := n + 1;
      continue;
    end if;

    -- Toques da cadência que vencem hoje (ou venceram nos últimos dias não úteis)
    for passo in select * from public.cadencia_passos where diretoria = 'comercial' and ativo order by dia loop
      v_prazo := privado.dia_util(v_d0 + passo.dia);
      continue when v_prazo > v_hoje or v_prazo < v_hoje - 3;
      continue when passo.so_sem_contato and privado.teve_contato(r.id, v_d0);
      -- Já existe ligação marcada por um resultado anterior (ex.: "Não atendeu" cria a próxima)
      continue when passo.canal = 'ligacao' and exists (
        select 1 from public.tarefas t where t.negocio_id = r.id and t.status <> 'concluida' and t.chave like 'ligacao:%');
      if privado.criar_tarefa(r.responsavel_id, passo.titulo || ' · ' || r.empresa, v_prazo, r.id,
           format('cadencia:%s:%s:%s', r.id, v_d0, passo.id), passo.descricao) is not null then
        n := n + 1;
      end if;
    end loop;
  end loop;

  -- Compromissos de hoje ligados a leads
  for r in
    select a.id, a.titulo, a.inicio, a.negocio_id, a.responsavel_id
    from public.atividades a join public.tipos_atividade t on t.id = a.tipo_id
    where t.ligada_a_lead and a.status in ('pendente', 'confirmada') and a.responsavel_id is not null
      and (a.inicio at time zone 'America/Sao_Paulo')::date = v_hoje
  loop
    if privado.criar_tarefa(r.responsavel_id,
         format('Hoje às %s: %s', to_char(r.inicio at time zone 'America/Sao_Paulo', 'HH24:MI'), r.titulo),
         v_hoje, r.negocio_id, format('compromisso:%s:%s', r.id, v_hoje), null, 'sistema', r.id, 'alta') is not null then
      n := n + 1;
    end if;
  end loop;

  return n;
end;
$$;

-- 07h30 de Brasília = 10h30 UTC (antes do SLA às 08h05 e das notificações às 08h10)
select cron.schedule('tarefas-diarias', '30 10 * * *', 'select privado.gerar_tarefas_diarias()');

revoke all on function public.tarefas_ao_mudar_fase() from public, anon, authenticated;
revoke all on function public.concluir_tarefas_da_atividade() from public, anon, authenticated;
