-- =====================================================================
-- v2 · Fase 0 · PR 2 — Resultado de ligação (PE-PA-002, Seção 3.1)
-- Também cria a base das tarefas automáticas (origem, chave, dias úteis), usada pelos
-- resultados de ligação e completada no PR 5 (cadência e job diário).
-- =====================================================================

-- ---------------------------------------------------------------------
-- Tipos
-- ---------------------------------------------------------------------
create type public.origem_registro as enum ('manual', 'sistema', 'agente');

-- Como calcular o prazo da tarefa criada por um resultado de ligação
create type public.prazo_tarefa_auto as enum (
  'mesmo_dia',            -- hoje (ou o próximo dia útil)
  'proximo_dia_util',     -- amanhã (ou o próximo dia útil)
  'proximo_toque',        -- próxima ligação da cadência: 7 dias (uma ligação por semana)
  'data_retorno',         -- a data de retorno informada na ligação
  'vespera_compromisso'   -- dia útil anterior ao compromisso marcado
);

-- ---------------------------------------------------------------------
-- Feriados e dias úteis (tarefas que caem em fim de semana ou feriado vão para o próximo dia útil)
-- ---------------------------------------------------------------------
create table public.feriados (
  data date primary key,
  nome text not null,
  created_at timestamptz not null default now()
);
alter table public.feriados enable row level security;
create policy feriados_ler on public.feriados for select to authenticated using ((select privado.membro_ativo()));
create policy feriados_gerir on public.feriados for all to authenticated
  using (privado.eh_diretor_de('comercial')) with check (privado.eh_diretor_de('comercial'));

insert into public.feriados (data, nome) values
  ('2026-01-01', 'Confraternização Universal'), ('2026-02-16', 'Carnaval'), ('2026-02-17', 'Carnaval'),
  ('2026-04-03', 'Sexta-feira Santa'), ('2026-04-21', 'Tiradentes'), ('2026-05-01', 'Dia do Trabalho'),
  ('2026-06-04', 'Corpus Christi'), ('2026-09-07', 'Independência'), ('2026-10-12', 'Nossa Senhora Aparecida'),
  ('2026-11-02', 'Finados'), ('2026-11-15', 'Proclamação da República'), ('2026-11-20', 'Consciência Negra'),
  ('2026-12-10', 'Aniversário de Londrina'), ('2026-12-25', 'Natal'),
  ('2027-01-01', 'Confraternização Universal'), ('2027-02-08', 'Carnaval'), ('2027-02-09', 'Carnaval'),
  ('2027-03-26', 'Sexta-feira Santa'), ('2027-04-21', 'Tiradentes'), ('2027-05-01', 'Dia do Trabalho'),
  ('2027-05-27', 'Corpus Christi'), ('2027-09-07', 'Independência'), ('2027-10-12', 'Nossa Senhora Aparecida'),
  ('2027-11-02', 'Finados'), ('2027-11-15', 'Proclamação da República'), ('2027-11-20', 'Consciência Negra'),
  ('2027-12-10', 'Aniversário de Londrina'), ('2027-12-25', 'Natal');

-- O próprio dia, se for útil; senão, o próximo dia útil
create or replace function privado.dia_util(_data date)
returns date language plpgsql stable security definer set search_path = '' as $$
declare
  d date := _data;
begin
  while extract(isodow from d) in (6, 7) or exists (select 1 from public.feriados f where f.data = d) loop
    d := d + 1;
  end loop;
  return d;
end;
$$;

-- Dia útil anterior (para véspera de compromissos)
create or replace function privado.dia_util_anterior(_data date)
returns date language plpgsql stable security definer set search_path = '' as $$
declare
  d date := _data - 1;
begin
  while extract(isodow from d) in (6, 7) or exists (select 1 from public.feriados f where f.data = d) loop
    d := d - 1;
  end loop;
  return d;
end;
$$;

create or replace function privado.hoje()
returns date language sql stable set search_path = '' as $$
  select (now() at time zone 'America/Sao_Paulo')::date
$$;

-- ---------------------------------------------------------------------
-- Tarefas criadas pelo sistema e pelos agentes
-- ---------------------------------------------------------------------
alter table public.tarefas
  add column origem public.origem_registro not null default 'manual',
  add column chave text,
  add column atividade_id uuid references public.atividades (id) on delete set null;
-- A chave impede que a mesma regra crie a mesma tarefa duas vezes
create unique index tarefas_chave_idx on public.tarefas (chave) where chave is not null;
create index tarefas_negocio_idx on public.tarefas (negocio_id) where negocio_id is not null;

-- Cria uma tarefa para um responsável (sem passar pelo RLS de criação manual, que é só do diretor)
create or replace function privado.criar_tarefa(
  _membro uuid, _titulo text, _prazo date, _negocio uuid default null, _chave text default null,
  _descricao text default null, _origem public.origem_registro default 'sistema',
  _atividade uuid default null, _prioridade public.prioridade default 'media'
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
begin
  if _membro is null or not exists (select 1 from public.membros m where m.id = _membro and m.ativo) then
    return null;
  end if;
  insert into public.tarefas (diretoria, titulo, descricao, prazo, prioridade, negocio_id, atividade_id, origem, chave, criado_por)
  values ('comercial', _titulo, _descricao, _prazo, _prioridade, _negocio, _atividade, _origem, _chave, null)
  on conflict (chave) where chave is not null do nothing
  returning id into v_id;
  if v_id is not null then
    insert into public.tarefa_responsaveis (tarefa_id, membro_id) values (v_id, _membro);
  end if;
  return v_id;
end;
$$;

-- Toda tarefa atribuída gera notificação (sino + push); só a tarefa manual que a pessoa cria para si não avisa
create or replace function public.notificar_tarefa_atribuida()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  t public.tarefas%rowtype;
begin
  select * into t from public.tarefas where id = new.tarefa_id;
  if t.status <> 'concluida' and (t.origem <> 'manual' or new.membro_id is distinct from (select auth.uid())) then
    perform privado.notificar(new.membro_id, 'tarefa_nova', 'Nova tarefa',
      t.titulo || coalesce(' · prazo ' || to_char(t.prazo, 'DD/MM'), ''),
      coalesce('/negocios/' || t.negocio_id, '/painel'),
      format('tarefa_nova:%s', t.id));
  end if;
  return null;
end;
$$;
create trigger notificar_tarefa_atribuida after insert on public.tarefa_responsaveis
  for each row execute function public.notificar_tarefa_atribuida();

-- ---------------------------------------------------------------------
-- Telefone inválido (resultado "Número errado")
-- ---------------------------------------------------------------------
alter table public.contatos add column telefone_invalido boolean not null default false;
alter table public.empresas add column telefone_invalido boolean not null default false;

-- ---------------------------------------------------------------------
-- Resultados de ligação (lista fechada, editável pelo diretor)
-- ---------------------------------------------------------------------
create table public.resultados_ligacao (
  id uuid primary key default gen_random_uuid(),
  diretoria text not null default 'comercial' references public.diretorias (slug),
  chave text not null,
  nome text not null,
  descricao text,
  ordem integer not null default 0,
  ativo boolean not null default true,
  fase_destino_id uuid references public.fases (id) on delete set null,   -- move o card (null = fica na fase)
  motivo_id uuid references public.motivos (id) on delete set null,       -- motivo usado quando o destino exige motivo
  conta_tentativa boolean not null default false,
  exige_retorno boolean not null default false,          -- pede a data de retorno (o card fica na fase com ela)
  registra_decisor boolean not null default false,       -- pede nome e melhor horário do decisor
  marca_telefone_invalido boolean not null default false,
  tipo_atividade_id uuid references public.tipos_atividade (id) on delete set null,  -- cria compromisso na agenda
  tarefa_titulo text,                                     -- tarefa criada para o responsável (null = nenhuma)
  tarefa_prazo public.prazo_tarefa_auto,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (diretoria, chave),
  constraint resultados_tarefa_prazo check (tarefa_titulo is null or tarefa_prazo is not null)
);
create trigger resultados_ligacao_updated_at before update on public.resultados_ligacao
  for each row execute function public.tocar_updated_at();
alter table public.resultados_ligacao enable row level security;
create policy resultados_ligacao_ler on public.resultados_ligacao for select to authenticated using ((select privado.membro_ativo()));
create policy resultados_ligacao_gerir on public.resultados_ligacao for all to authenticated
  using (privado.eh_diretor_de(diretoria)) with check (privado.eh_diretor_de(diretoria));

insert into public.resultados_ligacao
  (chave, nome, ordem, fase_destino_id, conta_tentativa, exige_retorno, registra_decisor, marca_telefone_invalido,
   tipo_atividade_id, tarefa_titulo, tarefa_prazo)
select v.chave, v.nome, v.ordem, (select id from public.fases where chave = v.fase), v.tentativa, v.retorno, v.decisor, v.tel_invalido,
       (select id from public.tipos_atividade where chave = v.tipo_ativ), v.tarefa, v.prazo::public.prazo_tarefa_auto
from (values
  ('nao_atendeu',         'Não atendeu',                    1, null,              true,  false, false, false, null,          'Próxima ligação da cadência',            'proximo_toque'),
  ('caixa_postal',        'Caixa postal',                   2, null,              true,  false, false, false, null,          'Próxima ligação da cadência',            'proximo_toque'),
  ('barrado_secretaria',  'Barrado na secretária',          3, null,              true,  false, true,  false, null,          'Ligar para o decisor no horário indicado', 'proximo_dia_util'),
  ('decisor_indisponivel','Decisor indisponível, retornar', 4, null,              false, true,  false, false, null,          'Ligar na data combinada',                'data_retorno'),
  ('pediu_email',         'Pediu e-mail',                   5, null,              false, false, false, false, null,          'Enviar e-mail com material',             'mesmo_dia'),
  ('sem_interesse',       'Sem interesse',                  6, 'nao_qualificado', false, false, false, false, null,          null,                                     null),
  ('interessado_sem_data','Interessado, sem data',          7, 'oportunidade',    false, false, false, false, null,          'Follow-up para marcar o diagnóstico',    'proximo_dia_util'),
  ('diagnostico_agendado','Diagnóstico agendado',           8, 'diagnostico',     false, false, false, false, 'diagnostico', 'Preparar o briefing do diagnóstico',     'vespera_compromisso'),
  ('numero_errado',       'Número errado',                  9, null,              false, false, false, true,  null,          'Corrigir o telefone',                    'proximo_dia_util')
) as v(chave, nome, ordem, fase, tentativa, retorno, decisor, tel_invalido, tipo_ativ, tarefa, prazo);

-- ---------------------------------------------------------------------
-- Ligações
-- ---------------------------------------------------------------------
create table public.ligacoes (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios (id) on delete cascade,
  contato_id uuid references public.contatos (id) on delete set null,
  membro_id uuid not null references public.membros (id) on delete restrict default auth.uid(),
  inicio timestamptz not null default now(),
  duracao_seg integer check (duracao_seg is null or duracao_seg >= 0),
  telefone text,
  resultado_id uuid references public.resultados_ligacao (id) on delete restrict,
  proximo_passo text,
  retorno_em date,
  compromisso_em timestamptz,          -- data do diagnóstico marcado
  decisor_nome text,
  decisor_melhor_horario text,
  comentario text,
  origem public.origem_registro not null default 'manual' check (origem in ('manual', 'agente')),
  resultado_aplicado_em timestamptz,   -- quando a ação do resultado foi executada (uma vez só)
  -- Reservadas para a Fase 2 (API4COM + Agente de ligação)
  api4com_id text unique,
  gravacao_url text,
  transcricao text,
  resumo text,
  criado_por uuid references public.membros (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index ligacoes_negocio_idx on public.ligacoes (negocio_id, inicio desc);
create index ligacoes_membro_idx on public.ligacoes (membro_id, inicio desc);
create trigger ligacoes_updated_at before update on public.ligacoes
  for each row execute function public.tocar_updated_at();

alter table public.ligacoes enable row level security;
create policy ligacoes_ler on public.ligacoes for select to authenticated using ((select privado.membro_ativo()));
-- Registra quem pode editar o negócio (responsável, participante ou diretor), sempre em nome próprio
create policy ligacoes_criar on public.ligacoes for insert to authenticated
  with check (privado.pode_editar_negocio(negocio_id)
              and (membro_id = (select auth.uid()) or privado.eh_diretor_de('comercial')));
create policy ligacoes_editar on public.ligacoes for update to authenticated
  using (membro_id = (select auth.uid()) or privado.eh_diretor_de('comercial'))
  with check (membro_id = (select auth.uid()) or privado.eh_diretor_de('comercial'));
create policy ligacoes_excluir on public.ligacoes for delete to authenticated using (privado.eh_diretor_de('comercial'));

-- Validação: campos que o resultado exige; o resultado já aplicado não muda mais
create or replace function public.antes_de_salvar_ligacao()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  r public.resultados_ligacao%rowtype;
begin
  if tg_op = 'UPDATE' and old.resultado_aplicado_em is not null then
    if new.resultado_id is distinct from old.resultado_id then
      raise exception 'O resultado desta ligação já foi aplicado e não pode ser trocado. Registre uma nova ligação.';
    end if;
    new.resultado_aplicado_em := old.resultado_aplicado_em;
  end if;
  if new.origem = 'manual' and new.resultado_id is null then
    raise exception 'Informe o resultado da ligação';
  end if;
  if new.resultado_id is not null then
    select * into r from public.resultados_ligacao where id = new.resultado_id;
    if r.exige_retorno and new.retorno_em is null then
      raise exception 'Informe a data de retorno para "%"', r.nome;
    end if;
    if r.tipo_atividade_id is not null and new.compromisso_em is null then
      raise exception 'Informe a data e o horário do compromisso para "%"', r.nome;
    end if;
  end if;
  return new;
end;
$$;
create trigger antes_de_salvar_ligacao before insert or update on public.ligacoes
  for each row execute function public.antes_de_salvar_ligacao();

-- Ação do resultado: mover a fase (mesmas regras de mover_negocio), data de retorno,
-- telefone inválido, compromisso na agenda e tarefa para o responsável
create or replace function public.aplicar_resultado_ligacao()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  r public.resultados_ligacao%rowtype;
  n public.negocios%rowtype;
  f_atual public.fases%rowtype;
  f_destino public.fases%rowtype;
  v_responsavel uuid;
  v_hoje date := privado.hoje();
  v_prazo date;
  v_empresa text;
  v_atividade uuid;
  v_titulo text;
begin
  if new.resultado_id is null or new.resultado_aplicado_em is not null then
    return null;
  end if;
  select * into r from public.resultados_ligacao where id = new.resultado_id;
  select * into n from public.negocios where id = new.negocio_id;
  select * into f_atual from public.fases where id = n.fase_id;
  select nome into v_empresa from public.empresas where id = n.empresa_id;
  v_responsavel := coalesce(n.responsavel_id, new.membro_id);

  -- Tarefas de ligação abertas deste negócio ficam resolvidas pela nova ligação
  update public.tarefas set status = 'concluida'
   where negocio_id = n.id and status <> 'concluida' and chave like 'ligacao:%';

  -- 1) Mover o card: só para a frente nas fases em andamento; perdas e pausas sempre; nunca reabre encerrados
  if r.fase_destino_id is not null and r.fase_destino_id <> n.fase_id and n.encerrado_em is null then
    select * into f_destino from public.fases where id = r.fase_destino_id and ativa and excluida_em is null;
    if found and (f_destino.tipo in ('perda', 'pausa') or f_destino.ordem > f_atual.ordem) then
      perform set_config('aprimora.comentario_movimento', 'Resultado da ligação: ' || r.nome, true);
      update public.negocios
         set fase_id = f_destino.id,
             motivo_id = case when f_destino.exige_motivo is not null then coalesce(r.motivo_id, motivo_id) else motivo_id end,
             -- O diagnóstico marcado preenche o campo obrigatório da fase
             campos = case when new.compromisso_em is not null and f_destino.chave = 'diagnostico'
                           then coalesce(campos, '{}'::jsonb) || jsonb_build_object('data_marcada',
                                to_char(new.compromisso_em at time zone 'America/Sao_Paulo', 'YYYY-MM-DD'))
                           else campos end
       where id = n.id;
      perform set_config('aprimora.comentario_movimento', '', true);
    end if;
  end if;

  -- 2) Data de retorno: o card fica na fase com a data
  if r.exige_retorno and new.retorno_em is not null then
    update public.negocios set retorno_em = new.retorno_em where id = n.id;
  end if;

  -- 3) Telefone inválido: no contato da ligação; sem contato, no telefone da empresa
  if r.marca_telefone_invalido then
    if new.contato_id is not null then
      update public.contatos set telefone_invalido = true where id = new.contato_id;
    else
      update public.empresas set telefone_invalido = true where id = n.empresa_id;
    end if;
  end if;

  -- 4) Compromisso na agenda
  if r.tipo_atividade_id is not null and new.compromisso_em is not null then
    select nome into v_titulo from public.tipos_atividade where id = r.tipo_atividade_id;
    insert into public.atividades (tipo_id, titulo, inicio, fim, negocio_id, empresa_id, responsavel_id, criado_por)
    values (r.tipo_atividade_id, v_titulo || ' · ' || coalesce(v_empresa, n.titulo), new.compromisso_em,
            new.compromisso_em + interval '90 minutes', n.id, n.empresa_id, v_responsavel, new.membro_id)
    returning id into v_atividade;
  end if;

  -- 5) Tarefa para o responsável
  if r.tarefa_titulo is not null then
    v_prazo := case r.tarefa_prazo
      when 'mesmo_dia' then privado.dia_util(v_hoje)
      when 'proximo_dia_util' then privado.dia_util(v_hoje + 1)
      when 'proximo_toque' then privado.dia_util(v_hoje + 7)
      when 'data_retorno' then privado.dia_util(coalesce(new.retorno_em, v_hoje + 1))
      when 'vespera_compromisso' then greatest(v_hoje, privado.dia_util_anterior(
        coalesce((new.compromisso_em at time zone 'America/Sao_Paulo')::date, v_hoje + 1)))
    end;
    perform privado.criar_tarefa(
      v_responsavel,
      r.tarefa_titulo || ' · ' || coalesce(v_empresa, n.titulo),
      v_prazo,
      n.id,
      'ligacao:' || new.id,
      concat_ws(E'\n',
        'Resultado da ligação: ' || r.nome,
        case when new.decisor_nome is not null or new.decisor_melhor_horario is not null then
          'Decisor: ' || coalesce(new.decisor_nome, '—') || coalesce(' · melhor horário: ' || new.decisor_melhor_horario, '') end,
        'Próximo passo: ' || new.proximo_passo,
        new.comentario),
      'sistema',
      v_atividade
    );
  end if;

  update public.ligacoes set resultado_aplicado_em = now() where id = new.id;
  return null;
end;
$$;
create trigger aplicar_resultado_ligacao after insert or update of resultado_id on public.ligacoes
  for each row execute function public.aplicar_resultado_ligacao();

-- As funções de gatilho não são chamáveis pela API
revoke all on function public.antes_de_salvar_ligacao() from public, anon, authenticated;
revoke all on function public.aplicar_resultado_ligacao() from public, anon, authenticated;
revoke all on function public.notificar_tarefa_atribuida() from public, anon, authenticated;
revoke all on function privado.criar_tarefa(uuid, text, date, uuid, text, text, public.origem_registro, uuid, public.prioridade) from public, anon, authenticated;

revoke all on public.feriados, public.resultados_ligacao, public.ligacoes from anon;
