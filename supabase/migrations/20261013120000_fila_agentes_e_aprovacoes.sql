-- =====================================================================
-- v2 · Fase 1 — Infraestrutura dos agentes (PE-PA-002, Seções 5, 6 e 8)
-- - agentes: os 12 agentes (+ o de teste) com liga/desliga
-- - trabalhos: a fila que o n8n consome pelas rotas /api/n8n/* (o portal é a fila; o n8n nunca fala com o banco)
-- - aprovacoes: a Caixa de aprovação ("o agente prepara, o humano decide")
-- - funções n8n_*: chamadas só pelas rotas /api/n8n/*, protegidas pelo segredo compartilhado
--   (hash SHA-256 em privado.config 'n8n_segredo_hash'; o valor fica na Vercel e no n8n)
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------
-- Agentes
-- ---------------------------------------------------------------------
create type public.tipo_agente as enum ('ia', 'regra', 'regra_ia', 'sistema');

create table public.agentes (
  chave text primary key,
  codigo text,                    -- A1…A12 do PE-PA-002
  nome text not null,
  descricao text,
  tipo public.tipo_agente not null,
  prioridade smallint,
  fase_roadmap smallint,          -- fase do roadmap em que o agente entra
  quem_aprova text,
  ativo boolean not null default false,
  ordem integer not null default 0,
  atualizado_por uuid references public.membros (id) on delete set null,
  updated_at timestamptz not null default now()
);
alter table public.agentes enable row level security;
create policy agentes_ler on public.agentes for select to authenticated using ((select privado.membro_ativo()));
create policy agentes_gerir on public.agentes for update to authenticated
  using (privado.eh_diretor_de('comercial')) with check (privado.eh_diretor_de('comercial'));
revoke all on public.agentes from anon;

insert into public.agentes (chave, codigo, nome, descricao, tipo, prioridade, fase_roadmap, quem_aprova, ordem) values
  ('teste',             null,  'Teste da fila',          'Ida e volta pela fila, sem IA. Usado no portão da Fase 1.', 'sistema', null, 1, null, 0),
  ('enriquecedor',      'A1',  'Enriquecedor',           'CNPJ, razão social, endereço, segmento e telefone; decisor e e-mails sugeridos; hipóteses de dor.', 'ia', 1, 2, 'Decisor e e-mail: o responsável', 1),
  ('ligacao',           'A2',  'Agente de ligação',      'Transcrição, resumo, resultado sugerido, dores e próximo passo de cada ligação.', 'ia', 1, 2, 'O responsável confirma resultado e fase', 2),
  ('avaliador',         'A3',  'Avaliador de ligações',  'Nota por critério da rubrica e comentários.', 'ia', 1, 2, null, 3),
  ('analista_gerencial','A4',  'Analista gerencial',     'Relatório da R.I e rascunho de plano de melhoria por membro.', 'regra_ia', 1, 2, 'Diretor revisa o plano', 4),
  ('redator',           'A5',  'Redator de cadência',    'E-mail personalizado de cada toque da cadência e do follow-up pós-proposta.', 'ia', 2, 3, 'Membro aprova os e-mails dos seus leads', 5),
  ('monitor_respostas', 'A6',  'Monitor de respostas',   'Classifica as respostas de e-mail, resume e sugere a fase; pausa a cadência.', 'ia', 2, 3, 'O responsável confirma', 6),
  ('organizador_dia',   'A7',  'Organizador do dia',     'Fila de ligações e tarefas do dia, todo dia às 07h30.', 'regra', 2, 3, null, 7),
  ('agendador',         'A8',  'Agendador',              'Compromisso, sugestão de acompanhantes, confirmação na véspera e briefing.', 'regra_ia', 3, 4, 'O responsável aprova a confirmação', 8),
  ('assistente_proposta','A9', 'Assistente de proposta', 'Resumo do diagnóstico, mapa de maturidade, serviços sugeridos e rascunho de escopo.', 'ia', 3, 4, 'O responsável e Projetos', 9),
  ('passagem',          'A10', 'Passagem para Projetos', 'Dossiê em PDF e tarefa para a Diretoria de Projetos.', 'regra', 3, 4, null, 10),
  ('analista_icp',      'A11', 'Analista de ICP',        'Conversão por segmento, porte, cidade e origem; score de aderência de cada lead.', 'regra_ia', 4, 5, 'Diretor lê', 11),
  ('prospector',        'A12', 'Prospector',             'Lote de leads do Google Maps ou Apollo, sem duplicados.', 'regra', 4, 5, 'Diretor aprova o lote', 12);

-- ---------------------------------------------------------------------
-- Fila de trabalhos
-- ---------------------------------------------------------------------
create type public.status_trabalho as enum ('pendente', 'processando', 'concluido', 'erro', 'cancelado');

create table public.trabalhos (
  id uuid primary key default gen_random_uuid(),
  agente text not null references public.agentes (chave),
  tipo text not null,                                  -- o que fazer (ex.: 'eco', 'enriquecer_empresa')
  negocio_id uuid references public.negocios (id) on delete cascade,
  payload jsonb not null default '{}',
  status public.status_trabalho not null default 'pendente',
  tentativas integer not null default 0,
  max_tentativas integer not null default 3,
  proximo_em timestamptz not null default now(),      -- não reservar antes (espera entre tentativas)
  reservado_em timestamptz,
  concluido_em timestamptz,
  resultado jsonb,
  erro text,
  chave text,                                          -- evita enfileirar o mesmo trabalho duas vezes
  criado_por uuid references public.membros (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index trabalhos_chave_idx on public.trabalhos (chave) where chave is not null;
create index trabalhos_fila_idx on public.trabalhos (status, proximo_em) where status in ('pendente', 'processando');
create index trabalhos_negocio_idx on public.trabalhos (negocio_id) where negocio_id is not null;
create trigger trabalhos_updated_at before update on public.trabalhos for each row execute function public.tocar_updated_at();
alter table public.trabalhos enable row level security;
-- Membros veem a fila (saúde e resultados); só as funções internas escrevem
create policy trabalhos_ler on public.trabalhos for select to authenticated using ((select privado.membro_ativo()));
revoke all on public.trabalhos from anon;
revoke insert, update, delete on public.trabalhos from authenticated;

-- Enfileira um trabalho para um agente ligado (agente desligado não recebe trabalho)
create or replace function privado.enfileirar(_agente text, _tipo text, _payload jsonb default '{}', _negocio uuid default null,
  _chave text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
begin
  if not exists (select 1 from public.agentes where chave = _agente and ativo) then return null; end if;
  insert into public.trabalhos (agente, tipo, payload, negocio_id, chave, criado_por)
  values (_agente, _tipo, coalesce(_payload, '{}'), _negocio, _chave, (select auth.uid()))
  on conflict (chave) where chave is not null do nothing
  returning id into v_id;
  return v_id;
end;
$$;

-- Botão "Enviar trabalho de teste" (diretor comercial)
create or replace function public.enviar_trabalho_teste()
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
begin
  if not privado.eh_diretor_de('comercial') then raise exception 'Só o Diretor Comercial envia trabalhos de teste'; end if;
  if not exists (select 1 from public.agentes where chave = 'teste' and ativo) then
    raise exception 'Ligue o agente "Teste da fila" antes de enviar';
  end if;
  v_id := privado.enfileirar('teste', 'eco', jsonb_build_object('mensagem', 'Olá, n8n!', 'enviado_em', now()));
  return v_id;
end;
$$;
revoke all on function public.enviar_trabalho_teste() from public, anon;
grant execute on function public.enviar_trabalho_teste() to authenticated;

-- ---------------------------------------------------------------------
-- Caixa de aprovação
-- ---------------------------------------------------------------------
create type public.status_aprovacao as enum ('pendente', 'aprovada', 'descartada');

create table public.aprovacoes (
  id uuid primary key default gen_random_uuid(),
  agente text not null references public.agentes (chave),
  tipo text not null,                         -- ex.: 'email', 'dados_empresa', 'resultado_ligacao'
  trabalho_id uuid references public.trabalhos (id) on delete set null,
  negocio_id uuid references public.negocios (id) on delete cascade,
  responsavel_id uuid references public.membros (id) on delete set null,
  titulo text not null,
  resumo text,
  conteudo jsonb not null default '{}',       -- campos editáveis (texto) mostrados por inteiro
  conteudo_original jsonb,                    -- como o agente entregou (para comparar com a versão aprovada)
  status public.status_aprovacao not null default 'pendente',
  decidido_por uuid references public.membros (id) on delete set null,
  decidido_em timestamptz,
  comentario text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index aprovacoes_pendentes_idx on public.aprovacoes (responsavel_id, created_at) where status = 'pendente';
create trigger aprovacoes_updated_at before update on public.aprovacoes for each row execute function public.tocar_updated_at();
alter table public.aprovacoes enable row level security;
-- Cada membro vê as suas; o diretor comercial vê todas
create policy aprovacoes_ler on public.aprovacoes for select to authenticated
  using (responsavel_id = (select auth.uid()) or privado.eh_diretor_de('comercial'));
create policy aprovacoes_decidir on public.aprovacoes for update to authenticated
  using (responsavel_id = (select auth.uid()) or privado.eh_diretor_de('comercial'))
  with check (responsavel_id = (select auth.uid()) or privado.eh_diretor_de('comercial'));
revoke all on public.aprovacoes from anon;
revoke insert, delete on public.aprovacoes from authenticated;

-- Só a decisão e o conteúdo mudam; quem decide e quando é carimbado aqui
create or replace function public.antes_de_decidir_aprovacao()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if (new.agente, new.tipo, new.trabalho_id, new.negocio_id, new.responsavel_id, new.titulo, new.conteudo_original, new.created_at)
     is distinct from (old.agente, old.tipo, old.trabalho_id, old.negocio_id, old.responsavel_id, old.titulo, old.conteudo_original, old.created_at) then
    raise exception 'Só a decisão, o conteúdo e o comentário podem ser alterados';
  end if;
  if old.status <> 'pendente' and (new.status, new.conteudo) is distinct from (old.status, old.conteudo) then
    raise exception 'Este item já foi decidido';
  end if;
  if new.status <> old.status then
    new.decidido_por := (select auth.uid());
    new.decidido_em := now();
  end if;
  return new;
end;
$$;
create trigger antes_de_decidir_aprovacao before update on public.aprovacoes
  for each row execute function public.antes_de_decidir_aprovacao();

-- Item novo na caixa: notifica o responsável (sino + push)
create or replace function public.notificar_aprovacao()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.responsavel_id is not null then
    perform privado.notificar(new.responsavel_id, 'aprovacao', 'Para aprovar', new.titulo, '/aprovacoes', format('aprovacao:%s', new.id));
  end if;
  return null;
end;
$$;
create trigger notificar_aprovacao after insert on public.aprovacoes for each row execute function public.notificar_aprovacao();

-- ---------------------------------------------------------------------
-- Funções das rotas /api/n8n/* (chamadas sem sessão, com o segredo)
-- ---------------------------------------------------------------------
create or replace function privado.n8n_autorizado(_segredo text)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(_segredo, '') <> '' and exists (
    select 1 from privado.config c
    where c.chave = 'n8n_segredo_hash' and c.valor = encode(extensions.digest(_segredo, 'sha256'), 'hex'))
$$;

create or replace function privado.notificar_diretores(_tipo text, _titulo text, _mensagem text, _link text, _chave text)
returns void language sql security definer set search_path = '' as $$
  select privado.notificar(md.membro_id, _tipo, _titulo, _mensagem, _link, _chave)
  from public.membro_diretorias md where md.diretoria = 'comercial' and md.cargo = 'diretor'
$$;

-- Reserva até _limite trabalhos pendentes (de agentes ligados), com trava: nunca o mesmo item duas vezes
create or replace function public.n8n_reservar(_segredo text, _agente text default null, _limite integer default 3)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v jsonb;
begin
  if not privado.n8n_autorizado(_segredo) then raise exception 'não autorizado'; end if;
  -- Devolve à fila o que ficou "processando" por mais de 30 minutos (n8n caiu no meio)
  update public.trabalhos set status = 'pendente', reservado_em = null
   where status = 'processando' and reservado_em < now() - interval '30 minutes';

  with escolhidos as (
    select t.id from public.trabalhos t join public.agentes a on a.chave = t.agente and a.ativo
    where t.status = 'pendente' and t.proximo_em <= now() and (_agente is null or t.agente = _agente)
    order by t.proximo_em, t.created_at
    limit greatest(1, least(coalesce(_limite, 3), 20))
    for update of t skip locked
  ), reservados as (
    update public.trabalhos t set status = 'processando', reservado_em = now(), tentativas = t.tentativas + 1
    from escolhidos e where t.id = e.id
    returning t.id, t.agente, t.tipo, t.negocio_id, t.payload, t.tentativas
  )
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'agente', agente, 'tipo', tipo, 'negocio_id', negocio_id,
    'payload', payload, 'tentativa', tentativas)), '[]') into v from reservados;
  return jsonb_build_object('trabalhos', v);
end;
$$;

-- Resultado: conclui o trabalho; se vier "aprovacao", cria o item na Caixa de aprovação
create or replace function public.n8n_concluir(_segredo text, _id uuid, _resultado jsonb default '{}')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  t public.trabalhos%rowtype;
  a jsonb := _resultado -> 'aprovacao';
  v_resp uuid;
begin
  if not privado.n8n_autorizado(_segredo) then raise exception 'não autorizado'; end if;
  select * into t from public.trabalhos where id = _id for update;
  if not found then raise exception 'trabalho não encontrado'; end if;
  if t.status <> 'processando' then
    return jsonb_build_object('ok', false, 'motivo', format('trabalho está "%s"', t.status));
  end if;
  update public.trabalhos set status = 'concluido', concluido_em = now(), resultado = coalesce(_resultado, '{}'), erro = null
   where id = _id;

  if a is not null and jsonb_typeof(a) = 'object' then
    select responsavel_id into v_resp from public.negocios where id = t.negocio_id;
    insert into public.aprovacoes (agente, tipo, trabalho_id, negocio_id, responsavel_id, titulo, resumo, conteudo, conteudo_original)
    values (t.agente, coalesce(a ->> 'tipo', t.tipo), t.id, t.negocio_id,
            coalesce((a ->> 'responsavel_id')::uuid, v_resp, t.criado_por),
            coalesce(a ->> 'titulo', 'Item para aprovar'), a ->> 'resumo',
            coalesce(a -> 'conteudo', '{}'), coalesce(a -> 'conteudo', '{}'));
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

-- Falha: tenta de novo com espera crescente (5, 10, 15 min); esgotou, marca erro e avisa os diretores
create or replace function public.n8n_falhar(_segredo text, _id uuid, _etapa text default null, _mensagem text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  t public.trabalhos%rowtype;
  v_msg text := left(concat_ws(': ', nullif(_etapa, ''), coalesce(nullif(_mensagem, ''), 'erro sem mensagem')), 2000);
begin
  if not privado.n8n_autorizado(_segredo) then raise exception 'não autorizado'; end if;
  select * into t from public.trabalhos where id = _id for update;
  if not found then raise exception 'trabalho não encontrado'; end if;
  if t.tentativas >= t.max_tentativas then
    update public.trabalhos set status = 'erro', erro = v_msg, reservado_em = null where id = _id;
    perform privado.notificar_diretores('agente_erro', 'Agente com erro',
      format('%s: %s', (select nome from public.agentes where chave = t.agente), v_msg), '/funil/configuracoes#agentes',
      format('agente_erro:%s', t.id));
  else
    update public.trabalhos set status = 'pendente', erro = v_msg, reservado_em = null,
      proximo_em = now() + make_interval(mins => 5 * t.tentativas) where id = _id;
  end if;
  return jsonb_build_object('ok', true, 'tentativas', t.tentativas, 'max_tentativas', t.max_tentativas,
    'status', case when t.tentativas >= t.max_tentativas then 'erro' else 'pendente' end);
end;
$$;

-- Saúde da fila (fluxo "Sistema · Monitor da fila")
create or replace function public.n8n_saude(_segredo text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not privado.n8n_autorizado(_segredo) then raise exception 'não autorizado'; end if;
  return privado.saude_fila();
end;
$$;

create or replace function privado.saude_fila()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'pendentes', (select count(*) from public.trabalhos where status = 'pendente'),
    'processando', (select count(*) from public.trabalhos where status = 'processando'),
    'mais_antiga_minutos', coalesce((select floor(extract(epoch from now() - min(created_at)) / 60)::int
                                     from public.trabalhos where status = 'pendente'), 0),
    'erros_24h', (select count(*) from public.trabalhos where status = 'erro' and updated_at > now() - interval '24 hours'),
    'concluidos_24h', (select count(*) from public.trabalhos where status = 'concluido' and concluido_em > now() - interval '24 hours'),
    'ultimo_concluido_em', (select max(concluido_em) from public.trabalhos where status = 'concluido'),
    'aprovacoes_pendentes', (select count(*) from public.aprovacoes where status = 'pendente')
  )
$$;

-- Para a tela de configurações (diretor): mesma saúde, com a sessão do usuário
create or replace function public.saude_fila()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not privado.membro_ativo() then raise exception 'não autorizado'; end if;
  return privado.saude_fila();
end;
$$;
revoke all on function public.saude_fila() from public, anon;
grant execute on function public.saude_fila() to authenticated;

-- Alerta do n8n (fila acumulada etc.) e erro de fluxo: auditoria + notificação aos diretores
create or replace function public.n8n_alerta(_segredo text, _tipo text, _detalhes jsonb default '{}')
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if not privado.n8n_autorizado(_segredo) then raise exception 'não autorizado'; end if;
  perform privado.registrar_auditoria('n8n_alerta', 'n8n', coalesce(_tipo, 'alerta'), coalesce(_detalhes, '{}'));
  perform privado.notificar_diretores('n8n_alerta', 'Alerta dos agentes',
    case _tipo when 'fila' then format('Fila acumulada: %s pendentes, a mais antiga há %s min, %s erros em 24 h.',
      _detalhes ->> 'pendentes', _detalhes ->> 'mais_antiga_minutos', _detalhes ->> 'erros_24h')
    else coalesce(_tipo, 'alerta') end,
    '/funil/configuracoes#agentes', format('n8n_alerta:%s:%s', coalesce(_tipo, 'alerta'), to_char(now(), 'YYYY-MM-DD"T"HH24')));
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.n8n_erro(_segredo text, _fluxo text, _execucao_id text default null, _execucao_url text default null,
  _no text default null, _mensagem text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if not privado.n8n_autorizado(_segredo) then raise exception 'não autorizado'; end if;
  perform privado.registrar_auditoria('n8n_erro', 'n8n', coalesce(_fluxo, '—'),
    jsonb_build_object('execucao_id', _execucao_id, 'execucao_url', _execucao_url, 'no', _no, 'mensagem', left(_mensagem, 2000)));
  perform privado.notificar_diretores('n8n_erro', 'Fluxo do n8n falhou',
    format('%s%s: %s', coalesce(_fluxo, '—'), coalesce(' (' || _no || ')', ''), coalesce(left(_mensagem, 300), 'sem mensagem')),
    '/auditoria', format('n8n_erro:%s', coalesce(_execucao_id, gen_random_uuid()::text)));
  return jsonb_build_object('ok', true);
end;
$$;

-- As rotas chamam sem sessão (anon); a proteção é o segredo verificado dentro de cada função
revoke all on function public.n8n_reservar(text, text, integer) from public;
revoke all on function public.n8n_concluir(text, uuid, jsonb) from public;
revoke all on function public.n8n_falhar(text, uuid, text, text) from public;
revoke all on function public.n8n_saude(text) from public;
revoke all on function public.n8n_alerta(text, text, jsonb) from public;
revoke all on function public.n8n_erro(text, text, text, text, text, text) from public;
grant execute on function public.n8n_reservar(text, text, integer), public.n8n_concluir(text, uuid, jsonb),
  public.n8n_falhar(text, uuid, text, text), public.n8n_saude(text), public.n8n_alerta(text, text, jsonb),
  public.n8n_erro(text, text, text, text, text, text) to anon, authenticated;
revoke all on function public.antes_de_decidir_aprovacao() from public, anon, authenticated;
revoke all on function public.notificar_aprovacao() from public, anon, authenticated;
