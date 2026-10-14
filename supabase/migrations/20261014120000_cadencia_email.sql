-- =====================================================================
-- v2 · Fase 3 — Cadência de e-mail (PE-PA-002, Seções 3.2 e 5: A5 Redator, A6 Monitor de respostas, A7 Organizador)
-- - Copies do playbook: cada copy tem um e-mail por toque de e-mail da cadência (D0, D3, D8, D15) e uma regra de uso
--   (qualquer empresa, segmento, origem, sem site, com dores). Mais de uma copy na mesma regra se alternam (teste A/B);
--   o lead fica com a mesma copy a cadência inteira. Também há copies de "Pediu e-mail" e do follow-up pós-proposta.
-- - O toque de e-mail vira trabalho do Redator (n8n + Gemini preenche as variáveis {{ }}) → "Aprovar e-mail" em
--   Tarefas → aprovado, entra na fila de envio pela comercial@ (dias úteis, horário comercial, em sequência no mesmo
--   fio). Sem e-mail do lead ou sem copy, continua a tarefa manual de antes.
-- - Resposta real do lead (Monitor de respostas): pausa a cadência; interessado → Oportunidade e "retornar depois" →
--   Retornar futuro, sozinhos (decisão do Diretor Comercial); recusa ou pedido de descadastro → aprovação do
--   responsável para encerrar como Lead não qualificado. Ausência (resposta automática) não pausa.
-- - A7 Organizador do dia: às 7h30 cada membro recebe o resumo do dia (sino + push).
-- =====================================================================

alter table public.parametros_comercial
  add column follow_up_proposta_dias integer not null default 3 check (follow_up_proposta_dias between 1 and 30),
  add column envio_hora_inicio integer not null default 8 check (envio_hora_inicio between 0 and 23),
  add column envio_hora_fim integer not null default 18 check (envio_hora_fim between 1 and 24),
  add column remetente_nome text not null default 'Aprimora Consultoria';

-- ---------------------------------------------------------------------
-- Copies do playbook
-- ---------------------------------------------------------------------
create table public.copies_email (
  id uuid primary key default gen_random_uuid(),
  diretoria text not null default 'comercial' references public.diretorias (slug),
  versao integer not null,
  nome text not null,
  uso text not null default 'cadencia' check (uso in ('cadencia', 'pediu_email', 'pos_proposta')),
  regra text not null default 'qualquer' check (regra in ('qualquer', 'segmento', 'origem', 'sem_site', 'com_dores')),
  regra_valor text,                                  -- id do segmento ou da origem
  ativo boolean not null default true,
  criado_por uuid references public.membros (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (diretoria, versao)
);
create trigger copies_email_updated_at before update on public.copies_email for each row execute function public.tocar_updated_at();

create table public.copies_email_mensagens (
  id uuid primary key default gen_random_uuid(),
  copy_id uuid not null references public.copies_email (id) on delete cascade,
  passo_id uuid references public.cadencia_passos (id) on delete cascade,   -- nulo nas copies fora da cadência
  assunto text not null default '',
  corpo text not null default '',
  updated_at timestamptz not null default now()
);
create unique index copies_email_mensagens_unica on public.copies_email_mensagens (copy_id, coalesce(passo_id, '00000000-0000-0000-0000-000000000000'));
create trigger copies_email_mensagens_updated_at before update on public.copies_email_mensagens for each row execute function public.tocar_updated_at();

-- Versão sequencial (V1, V2…) por diretoria
create or replace function public.antes_de_criar_copy()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.versao is null then
    select coalesce(max(versao), 0) + 1 into new.versao from public.copies_email where diretoria = new.diretoria;
  end if;
  return new;
end;
$$;
alter table public.copies_email alter column versao drop not null;
create trigger antes_de_criar_copy before insert on public.copies_email for each row execute function public.antes_de_criar_copy();
alter table public.copies_email add constraint copies_email_versao_obrigatoria check (versao is not null);
revoke all on function public.antes_de_criar_copy() from public, anon, authenticated;

alter table public.copies_email enable row level security;
alter table public.copies_email_mensagens enable row level security;
create policy copies_ler on public.copies_email for select to authenticated using ((select privado.membro_ativo()));
create policy copies_gerir on public.copies_email for all to authenticated
  using (privado.eh_diretor_de('comercial')) with check (privado.eh_diretor_de('comercial'));
create policy copies_mensagens_ler on public.copies_email_mensagens for select to authenticated using ((select privado.membro_ativo()));
create policy copies_mensagens_gerir on public.copies_email_mensagens for all to authenticated
  using (privado.eh_diretor_de('comercial')) with check (privado.eh_diretor_de('comercial'));
revoke all on public.copies_email, public.copies_email_mensagens from anon;

-- ---------------------------------------------------------------------
-- E-mails e respostas (só funções internas escrevem)
-- ---------------------------------------------------------------------
create table public.emails (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios (id) on delete cascade,
  contato_id uuid references public.contatos (id) on delete set null,
  membro_id uuid references public.membros (id) on delete set null,          -- responsável que aprova
  copy_id uuid references public.copies_email (id) on delete set null,
  passo_id uuid references public.cadencia_passos (id) on delete set null,
  uso text not null default 'cadencia',
  d0 date,                                                                    -- início da cadência a que pertence
  para text not null,
  assunto text not null,
  corpo text not null,
  status text not null default 'rascunho' check (status in ('rascunho', 'aprovado', 'enviado', 'erro', 'cancelado')),
  trabalho_id uuid references public.trabalhos (id) on delete set null,
  envio_trabalho_id uuid references public.trabalhos (id) on delete set null,
  responder_a text,                                                           -- id Gmail da mensagem anterior (mesmo fio)
  gmail_id text,
  thread_id text,
  enviado_em timestamptz,
  aprovado_por uuid references public.membros (id) on delete set null,
  erro text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index emails_negocio_idx on public.emails (negocio_id, created_at desc);
create index emails_thread_idx on public.emails (thread_id) where thread_id is not null;
create index emails_copy_idx on public.emails (copy_id) where status = 'enviado';
create trigger emails_updated_at before update on public.emails for each row execute function public.tocar_updated_at();
alter table public.emails enable row level security;
create policy emails_ler on public.emails for select to authenticated using ((select privado.membro_ativo()));
revoke all on public.emails from anon;
revoke insert, update, delete on public.emails from authenticated;

create table public.respostas_email (
  id uuid primary key default gen_random_uuid(),
  email_id uuid references public.emails (id) on delete set null,
  negocio_id uuid not null references public.negocios (id) on delete cascade,
  gmail_id text not null unique,
  thread_id text,
  de text,
  assunto text,
  trecho text,
  recebido_em timestamptz not null default now(),
  classificacao text check (classificacao in ('interessado', 'retornar_depois', 'recusa', 'descadastro', 'ausencia', 'outro')),
  resumo text,
  retorno_em date,
  aplicada_em timestamptz,
  created_at timestamptz not null default now()
);
create index respostas_email_negocio_idx on public.respostas_email (negocio_id, recebido_em desc);
alter table public.respostas_email enable row level security;
create policy respostas_ler on public.respostas_email for select to authenticated using ((select privado.membro_ativo()));
revoke all on public.respostas_email from anon;
revoke insert, update, delete on public.respostas_email from authenticated;

alter table public.aprovacoes
  add column email_id uuid references public.emails (id) on delete cascade,
  add column resposta_id uuid references public.respostas_email (id) on delete cascade;

-- Resposta real (não automática) conta como contato efetivo: pula os toques "só sem contato" e evita a Reciclagem
create or replace function privado.teve_contato(_negocio uuid, _desde date)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.ligacoes l join public.resultados_ligacao r on r.id = l.resultado_id
    where l.negocio_id = _negocio and not r.conta_tentativa
      and (l.inicio at time zone 'America/Sao_Paulo')::date >= _desde
  ) or exists (
    select 1 from public.respostas_email re
    where re.negocio_id = _negocio and re.classificacao is distinct from 'ausencia'
      and (re.recebido_em at time zone 'America/Sao_Paulo')::date >= _desde
  )
$$;

-- ---------------------------------------------------------------------
-- Auxiliares
-- ---------------------------------------------------------------------
create or replace function privado.notificar(_membro uuid, _tipo text, _titulo text, _mensagem text, _link text, _chave text)
returns void language sql security definer set search_path = '' as $$
  insert into public.notificacoes (membro_id, tipo, titulo, mensagem, link, chave)
  select _membro, _tipo, _titulo, _mensagem, _link, _chave
  where _membro is not null and not exists (select 1 from public.notificacoes n where n.chave = _chave and _chave is not null)
$$;

-- Para quem vai o e-mail: contato do negócio, senão o decisor com e-mail, senão o e-mail da empresa. "Não contatar" bloqueia.
create or replace function privado.email_destino(_negocio uuid, out contato_id uuid, out email text)
language plpgsql stable security definer set search_path = '' as $$
declare
  n public.negocios%rowtype;
begin
  select * into n from public.negocios where id = _negocio;
  if not found then return; end if;
  if exists (select 1 from public.contatos c where c.id = n.contato_id and c.nao_contatar) then return; end if;
  select c.id, c.email into contato_id, email from public.contatos c
   where c.id = n.contato_id and nullif(trim(c.email), '') is not null;
  if email is null then
    select c.id, c.email into contato_id, email from public.contatos c
     where c.empresa_id = n.empresa_id and c.decisor and not c.nao_contatar and nullif(trim(c.email), '') is not null
     order by c.updated_at desc limit 1;
  end if;
  if email is null then
    select null, e.email_principal into contato_id, email from public.empresas e
     where e.id = n.empresa_id and nullif(trim(e.email_principal), '') is not null;
  end if;
  email := nullif(lower(trim(email)), '');
end;
$$;

-- Escolhe a copy: a da cadência em andamento; senão a regra mais específica que casa com o lead e, entre as
-- empatadas, a menos usada (alternância A/B)
create or replace function privado.escolher_copy(_negocio uuid, _uso text, _d0 date default null)
returns uuid language plpgsql stable security definer set search_path = '' as $$
declare
  v uuid;
  n public.negocios%rowtype;
  e public.empresas%rowtype;
begin
  if _uso = 'cadencia' and _d0 is not null then
    select c.id into v from public.trabalhos t join public.copies_email c on c.id::text = t.payload -> 'copy' ->> 'id' and c.ativo
     where t.agente = 'redator' and t.tipo = 'redigir_email' and t.negocio_id = _negocio
       and t.payload ->> 'uso' = 'cadencia' and t.payload ->> 'd0' = _d0::text
     order by t.created_at limit 1;
    if v is not null then return v; end if;
  end if;
  select * into n from public.negocios where id = _negocio;
  select * into e from public.empresas where id = n.empresa_id;
  select c.id into v from public.copies_email c
   where c.ativo and c.diretoria = 'comercial' and c.uso = _uso
     and (c.regra = 'qualquer'
       or (c.regra = 'segmento' and c.regra_valor = e.segmento_id::text)
       or (c.regra = 'origem' and c.regra_valor = n.origem_id::text)
       or (c.regra = 'sem_site' and nullif(trim(e.site), '') is null)
       or (c.regra = 'com_dores' and nullif(trim(n.dores_identificadas), '') is not null))
   order by (c.regra <> 'qualquer') desc,
            (select count(*) from public.trabalhos t where t.agente = 'redator' and t.tipo = 'redigir_email'
              and t.payload -> 'copy' ->> 'id' = c.id::text),
            c.versao
   limit 1;
  return v;
end;
$$;

-- Próximo horário de envio: agora, se for dia útil em horário comercial; senão a abertura do próximo dia útil
create or replace function privado.proxima_janela_envio()
returns timestamptz language plpgsql stable security definer set search_path = '' as $$
declare
  p public.parametros_comercial%rowtype;
  v_local timestamp := now() at time zone 'America/Sao_Paulo';
  v_dia date := v_local::date;
begin
  select * into p from public.parametros_comercial where diretoria = 'comercial';
  if privado.dia_util(v_dia) = v_dia and extract(hour from v_local) >= p.envio_hora_inicio and extract(hour from v_local) < p.envio_hora_fim then
    return now();
  end if;
  if extract(hour from v_local) >= p.envio_hora_fim or privado.dia_util(v_dia) <> v_dia then
    v_dia := privado.dia_util(v_dia + 1);
  end if;
  return (v_dia + make_interval(hours => p.envio_hora_inicio)) at time zone 'America/Sao_Paulo';
end;
$$;

-- ---------------------------------------------------------------------
-- A5 · Redator: enfileira a redação de um e-mail (devolve nulo quando não dá: sem e-mail, sem copy, agente desligado)
-- ---------------------------------------------------------------------
create or replace function privado.enfileirar_redacao(_negocio uuid, _uso text, _passo uuid, _d0 date, _chave text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  n public.negocios%rowtype;
  e public.empresas%rowtype;
  dest record;
  v_copy public.copies_email%rowtype;
  m public.copies_email_mensagens%rowtype;
  ps public.cadencia_passos%rowtype;
begin
  if not exists (select 1 from public.agentes where chave = 'redator' and ativo) then return null; end if;
  select * into n from public.negocios where id = _negocio;
  select * into e from public.empresas where id = n.empresa_id;
  select * into dest from privado.email_destino(_negocio);
  if dest.email is null then return null; end if;
  select * into v_copy from public.copies_email where id = privado.escolher_copy(_negocio, _uso, _d0);
  if not found then return null; end if;
  select * into m from public.copies_email_mensagens
   where copy_id = v_copy.id and passo_id is not distinct from _passo and nullif(trim(corpo), '') is not null;
  if not found then return null; end if;
  select * into ps from public.cadencia_passos where id = _passo;
  return privado.enfileirar('redator', 'redigir_email', jsonb_build_object(
    'negocio_id', n.id, 'uso', _uso, 'd0', _d0,
    'passo', case when _passo is not null then jsonb_build_object('id', ps.id, 'dia', ps.dia, 'titulo', ps.titulo) end,
    'copy', jsonb_build_object('id', v_copy.id, 'versao', v_copy.versao, 'nome', v_copy.nome),
    'mensagem', jsonb_build_object('assunto', m.assunto, 'corpo', m.corpo),
    'para', dest.email, 'contato_id', dest.contato_id,
    'contato', (select jsonb_build_object('nome', c.nome, 'cargo', c.cargo) from public.contatos c where c.id = dest.contato_id),
    'empresa', jsonb_build_object('nome', e.nome, 'cidade', e.cidade, 'site', e.site,
      'segmento', (select s.nome from public.segmentos s where s.id = e.segmento_id),
      'resumo', e.enriquecimento ->> 'resumo'),
    'servicos', (select jsonb_agg(s.nome order by s.ordem) from public.negocio_servicos ns join public.servicos s on s.id = ns.servico_id where ns.negocio_id = n.id),
    'servicos_aprimora', (select jsonb_agg(s.nome order by s.ordem) from public.servicos s where s.ativo and s.diretoria = 'comercial'),
    'dores', coalesce(n.dores_identificadas, ''),
    'ligacoes', coalesce((select jsonb_agg(x) from (
        select jsonb_build_object('data', to_char(l.inicio at time zone 'America/Sao_Paulo', 'DD/MM'), 'resultado', r.nome, 'resumo', coalesce(l.resumo, l.comentario)) x
        from public.ligacoes l left join public.resultados_ligacao r on r.id = l.resultado_id
        where l.negocio_id = n.id order by l.inicio desc limit 3) s), '[]'),
    'membro', (select nome from public.membros where id = n.responsavel_id),
    'remetente', (select remetente_nome from public.parametros_comercial where diretoria = 'comercial'),
    'hoje', privado.hoje()
  ), n.id, _chave);
end;
$$;

create or replace function privado.aplicar_redacao(t public.trabalhos, r jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare
  p jsonb := t.payload;
  n public.negocios%rowtype;
  v_email uuid;
  v_empresa text;
  v_dest uuid;
begin
  select * into n from public.negocios where id = (p ->> 'negocio_id')::uuid;
  if not found or n.encerrado_em is not null then return; end if;
  if nullif(trim(r ->> 'corpo'), '') is null then raise exception 'Redator devolveu e-mail vazio'; end if;
  select nome into v_empresa from public.empresas where id = n.empresa_id;
  v_dest := privado.destinatario_negocio(n.id, null);
  insert into public.emails (negocio_id, contato_id, membro_id, copy_id, passo_id, uso, d0, para, assunto, corpo, trabalho_id)
  values (n.id, (p ->> 'contato_id')::uuid, v_dest, (p -> 'copy' ->> 'id')::uuid, (p -> 'passo' ->> 'id')::uuid, p ->> 'uso',
          (p ->> 'd0')::date, p ->> 'para', coalesce(nullif(trim(r ->> 'assunto'), ''), p -> 'mensagem' ->> 'assunto'), trim(r ->> 'corpo'), t.id)
  returning id into v_email;
  insert into public.aprovacoes (agente, tipo, trabalho_id, negocio_id, email_id, responsavel_id, titulo, resumo, conteudo, conteudo_original)
  select 'redator', 'email', t.id, n.id, v_email, v_dest,
         'Aprovar e-mail · ' || coalesce(p -> 'passo' ->> 'titulo', case p ->> 'uso' when 'pediu_email' then 'Material pedido na ligação' else 'Follow-up da proposta' end)
           || ' · ' || coalesce(v_empresa, 'lead'),
         format('Copy V%s · %s. Revise antes de aprovar: aprovado, sai pela comercial@ no horário comercial.', p -> 'copy' ->> 'versao', p -> 'copy' ->> 'nome'),
         c, c
  from (select jsonb_build_object('para', p ->> 'para', 'assunto', coalesce(nullif(trim(r ->> 'assunto'), ''), p -> 'mensagem' ->> 'assunto'), 'corpo', trim(r ->> 'corpo')) c) x;
end;
$$;

create or replace function privado.aplicar_envio(t public.trabalhos, r jsonb)
returns void language sql security definer set search_path = '' as $$
  update public.emails set status = 'enviado', enviado_em = now(), gmail_id = nullif(r ->> 'gmail_id', ''),
         thread_id = nullif(r ->> 'thread_id', ''), erro = null
  where id = (t.payload ->> 'email_id')::uuid
$$;

-- Pediu e-mail na ligação: o Redator prepara o e-mail com material
create or replace function public.agentes_apos_resultado_ligacao()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.resultado_aplicado_em is not null and (tg_op = 'INSERT' or old.resultado_aplicado_em is null)
     and exists (select 1 from public.resultados_ligacao r where r.id = new.resultado_id and r.chave = 'pediu_email') then
    perform privado.enfileirar_redacao(new.negocio_id, 'pediu_email', null, null, 'pediu_email:' || new.id);
  end if;
  return null;
end;
$$;
create trigger agentes_apos_resultado_ligacao after insert or update of resultado_aplicado_em on public.ligacoes
  for each row execute function public.agentes_apos_resultado_ligacao();
revoke all on function public.agentes_apos_resultado_ligacao() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- A6 · Monitor de respostas: o n8n entrega as mensagens novas da caixa da comercial@
-- ---------------------------------------------------------------------
create or replace function public.n8n_registrar_respostas(_segredo text, _mensagens jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  m jsonb;
  em public.emails%rowtype;
  v_resp uuid;
  v_novas int := 0;
  v_empresa text;
begin
  if not privado.n8n_autorizado(_segredo) then raise exception 'não autorizado'; end if;
  if jsonb_typeof(_mensagens) is distinct from 'array' then raise exception 'mensagens deve ser uma lista'; end if;
  for m in select * from jsonb_array_elements(_mensagens) loop
    continue when nullif(m ->> 'thread_id', '') is null or nullif(m ->> 'gmail_id', '') is null;
    select * into em from public.emails where thread_id = m ->> 'thread_id' and status = 'enviado' order by enviado_em desc limit 1;
    continue when not found;
    continue when m ->> 'gmail_id' = em.gmail_id;
    insert into public.respostas_email (email_id, negocio_id, gmail_id, thread_id, de, assunto, trecho, recebido_em)
    values (em.id, em.negocio_id, m ->> 'gmail_id', m ->> 'thread_id', left(m ->> 'de', 300), left(m ->> 'assunto', 500),
            left(m ->> 'trecho', 4000), coalesce((m ->> 'recebido_em')::timestamptz, now()))
    on conflict (gmail_id) do nothing
    returning id into v_resp;
    continue when v_resp is null;
    v_novas := v_novas + 1;
    select e.nome into v_empresa from public.negocios n join public.empresas e on e.id = n.empresa_id where n.id = em.negocio_id;
    perform privado.notificar(em.membro_id, 'resposta_email', 'Resposta de ' || coalesce(v_empresa, 'lead'),
      left(coalesce(m ->> 'trecho', ''), 180), '/negocios/' || em.negocio_id, 'resposta:' || v_resp);
    perform privado.enfileirar('monitor_respostas', 'classificar_resposta', jsonb_build_object(
      'resposta_id', v_resp, 'de', m ->> 'de', 'assunto', m ->> 'assunto', 'trecho', left(m ->> 'trecho', 4000),
      'email_enviado', jsonb_build_object('assunto', em.assunto, 'corpo', left(em.corpo, 3000)),
      'empresa', v_empresa, 'hoje', privado.hoje()), em.negocio_id, 'classificar:' || v_resp);
  end loop;
  return jsonb_build_object('ok', true, 'recebidas', jsonb_array_length(_mensagens), 'respostas', v_novas);
end;
$$;
revoke all on function public.n8n_registrar_respostas(text, jsonb) from public;
grant execute on function public.n8n_registrar_respostas(text, jsonb) to anon, authenticated;

-- Move o negócio para uma fase pela chave (só para a frente; sem quebrar se faltar campo obrigatório)
create or replace function privado.mover_por_chave(_negocio uuid, _chave text, _comentario text, _retorno date default null)
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  n public.negocios%rowtype;
  f_atual public.fases%rowtype;
  f_destino public.fases%rowtype;
begin
  select * into n from public.negocios where id = _negocio;
  if not found or n.encerrado_em is not null then return false; end if;
  select * into f_atual from public.fases where id = n.fase_id;
  select * into f_destino from public.fases where funil_id = n.funil_id and chave = _chave and ativa and excluida_em is null;
  if not found or f_destino.id = f_atual.id or (f_destino.tipo = 'aberta' and f_destino.ordem <= f_atual.ordem) then return false; end if;
  begin
    perform set_config('aprimora.movimento_automatico', 'sim', true);
    perform set_config('aprimora.comentario_movimento', _comentario, true);
    update public.negocios set fase_id = f_destino.id, retorno_em = coalesce(_retorno, retorno_em) where id = n.id;
    perform set_config('aprimora.movimento_automatico', '', true);
    perform set_config('aprimora.comentario_movimento', '', true);
    return true;
  exception when others then
    perform set_config('aprimora.movimento_automatico', '', true);
    perform set_config('aprimora.comentario_movimento', '', true);
    return false;
  end;
end;
$$;

create or replace function privado.aplicar_classificacao(t public.trabalhos, r jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare
  re public.respostas_email%rowtype;
  em public.emails%rowtype;
  v_classe text := coalesce(r ->> 'classificacao', 'outro');
  v_retorno date;
  v_empresa text;
  v_movido boolean := false;
  v_resp uuid;
begin
  select * into re from public.respostas_email where id = (t.payload ->> 'resposta_id')::uuid;
  if not found then return; end if;
  if v_classe not in ('interessado', 'retornar_depois', 'recusa', 'descadastro', 'ausencia', 'outro') then v_classe := 'outro'; end if;
  v_retorno := case when (r ->> 'retorno_em') ~ '^\d{4}-\d{2}-\d{2}$' then (r ->> 'retorno_em')::date end;
  if v_classe = 'retornar_depois' then v_retorno := coalesce(v_retorno, privado.hoje() + 30); end if;
  update public.respostas_email set classificacao = v_classe, resumo = nullif(r ->> 'resumo', ''), retorno_em = v_retorno where id = re.id;
  select * into em from public.emails where id = re.email_id;
  select e.nome into v_empresa from public.negocios n join public.empresas e on e.id = n.empresa_id where n.id = re.negocio_id;
  v_resp := coalesce(em.membro_id, privado.destinatario_negocio(re.negocio_id, null));

  if v_classe = 'interessado' then
    v_movido := privado.mover_por_chave(re.negocio_id, 'oportunidade', 'Resposta de e-mail: interessado');
  elsif v_classe = 'retornar_depois' then
    v_movido := privado.mover_por_chave(re.negocio_id, 'retornar', 'Resposta de e-mail: pediu retorno depois', v_retorno);
  elsif v_classe in ('recusa', 'descadastro') then
    if v_classe = 'descadastro' then
      update public.contatos set nao_contatar = true where id = em.contato_id or (lower(email) = lower(substring(re.de from '[^<\s]+@[^>\s]+')));
    end if;
    insert into public.aprovacoes (agente, tipo, negocio_id, resposta_id, responsavel_id, titulo, resumo, conteudo, conteudo_original)
    select 'monitor_respostas', 'resposta_recusa', re.negocio_id, re.id, v_resp,
           'Encerrar lead? ' || coalesce(v_empresa, '') || case when v_classe = 'descadastro' then ' pediu para não receber e-mails' else ' recusou por e-mail' end,
           coalesce(nullif(r ->> 'resumo', ''), re.trecho), c, c
    from (select jsonb_build_object('motivo', coalesce((select m.nome from public.motivos m where m.diretoria = 'comercial' and m.tipo = 'desqualificacao'
                                      and m.chave = case when v_classe = 'descadastro' then 'nao_contatar' else 'sem_interesse' end), 'Sem interesse'),
                                    'comentario', left(coalesce(nullif(r ->> 'resumo', ''), re.trecho, ''), 500)) c) x;
  end if;
  if v_movido then update public.respostas_email set aplicada_em = now() where id = re.id; end if;
  perform privado.notificar(v_resp, 'resposta_email',
    coalesce(v_empresa, 'Lead') || ': ' || case v_classe when 'interessado' then 'interessado' when 'retornar_depois' then 'pediu retorno depois'
      when 'recusa' then 'recusou' when 'descadastro' then 'pediu para sair da lista' when 'ausencia' then 'resposta automática' else 'respondeu' end
      || case when v_movido then ' (card movido)' else '' end,
    coalesce(nullif(r ->> 'resumo', ''), left(re.trecho, 180)), '/negocios/' || re.negocio_id, 'classificada:' || re.id);
end;
$$;

-- ---------------------------------------------------------------------
-- Despacho e falhas
-- ---------------------------------------------------------------------
create or replace function privado.aplicar_resultado_agente(t public.trabalhos, r jsonb)
returns void language plpgsql security definer set search_path = '' as $$
begin
  case t.agente
    when 'enriquecedor' then perform privado.aplicar_enriquecimento(t, r);
    when 'analista_gerencial' then perform privado.aplicar_relatorio(t, r);
    when 'ligacao' then perform privado.aplicar_ligacao(t, r);
    when 'redator' then
      if t.tipo = 'enviar_email' then perform privado.aplicar_envio(t, r); else perform privado.aplicar_redacao(t, r); end if;
    when 'monitor_respostas' then perform privado.aplicar_classificacao(t, r);
    else null;
  end case;
end;
$$;

create or replace function public.n8n_falhar(_segredo text, _id uuid, _etapa text default null, _mensagem text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  t public.trabalhos%rowtype;
  v_msg text := left(concat_ws(': ', nullif(_etapa, ''), coalesce(nullif(_mensagem, ''), 'erro sem mensagem')), 2000);
  v_resp uuid;
begin
  if not privado.n8n_autorizado(_segredo) then raise exception 'não autorizado'; end if;
  select * into t from public.trabalhos where id = _id for update;
  if not found then raise exception 'trabalho não encontrado'; end if;
  if t.tentativas >= t.max_tentativas then
    update public.trabalhos set status = 'erro', erro = v_msg, reservado_em = null where id = _id;
    if t.agente = 'analista_gerencial' then
      update public.relatorios set status = 'erro', erro = v_msg where id = (t.payload ->> 'relatorio_id')::uuid;
    elsif t.agente = 'ligacao' then
      perform privado.aprovacao_resultado_ligacao((t.payload ->> 'ligacao_id')::uuid, t.id,
        jsonb_build_object('resumo', 'O Agente de ligação não conseguiu ouvir a gravação: confira o resultado.'));
    elsif t.agente = 'redator' and t.tipo = 'enviar_email' then
      update public.emails set status = 'erro', erro = v_msg where id = (t.payload ->> 'email_id')::uuid returning membro_id into v_resp;
      perform privado.notificar(v_resp, 'agente_erro', 'E-mail não enviado', v_msg, '/negocios/' || t.negocio_id, 'envio_erro:' || t.id);
    elsif t.agente = 'redator' and t.negocio_id is not null then
      perform privado.criar_tarefa(privado.destinatario_negocio(t.negocio_id, null),
        'Escrever e-mail · ' || coalesce(t.payload -> 'passo' ->> 'titulo', 'e-mail do lead'), privado.hoje(), t.negocio_id,
        'redacao_manual:' || t.id, 'O Redator não conseguiu preparar este e-mail. Escreva e envie manualmente.', 'agente');
    end if;
    perform privado.notificar_diretores('agente_erro', 'Agente com erro',
      format('%s: %s', (select nome from public.agentes where chave = t.agente), v_msg), '/funil/configuracoes?ver=agentes',
      format('agente_erro:%s', t.id));
  else
    update public.trabalhos set status = 'pendente', erro = v_msg, reservado_em = null,
      proximo_em = now() + make_interval(mins => 5 * t.tentativas) where id = _id;
  end if;
  return jsonb_build_object('ok', true, 'tentativas', t.tentativas, 'max_tentativas', t.max_tentativas,
    'status', case when t.tentativas >= t.max_tentativas then 'erro' else 'pendente' end);
end;
$$;

-- ---------------------------------------------------------------------
-- Tarefas diárias: toques de e-mail viram trabalho do Redator; follow-up pós-proposta; A7 resumo do dia
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
  v_pausada boolean;
  n integer := 0;
begin
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

    -- O lead respondeu o e-mail (resposta real): a contagem pausa
    v_pausada := exists (select 1 from public.respostas_email re where re.negocio_id = r.id
                          and re.classificacao is distinct from 'ausencia' and (re.recebido_em at time zone 'America/Sao_Paulo')::date >= v_d0);
    continue when v_pausada;

    for passo in select * from public.cadencia_passos where diretoria = 'comercial' and ativo order by dia loop
      v_prazo := privado.dia_util(v_d0 + passo.dia);
      continue when v_prazo > v_hoje or v_prazo < v_hoje - 3;
      continue when passo.so_sem_contato and privado.teve_contato(r.id, v_d0);
      continue when passo.canal = 'ligacao' and exists (
        select 1 from public.tarefas t where t.negocio_id = r.id and t.status <> 'concluida' and t.chave like 'ligacao:%');
      if passo.canal = 'email' then
        continue when exists (select 1 from public.emails em where em.negocio_id = r.id and em.passo_id = passo.id and em.d0 = v_d0);
        continue when exists (select 1 from public.trabalhos tb where tb.chave = format('redigir:%s:%s:%s', r.id, v_d0, passo.id));
        if privado.enfileirar_redacao(r.id, 'cadencia', passo.id, v_d0, format('redigir:%s:%s:%s', r.id, v_d0, passo.id)) is not null then
          n := n + 1;
          continue;
        end if;
      end if;
      if privado.criar_tarefa(r.responsavel_id, passo.titulo || ' · ' || r.empresa, v_prazo, r.id,
           format('cadencia:%s:%s:%s', r.id, v_d0, passo.id), passo.descricao) is not null then
        n := n + 1;
      end if;
    end loop;
  end loop;

  -- Follow-up pós-proposta: N dias úteis depois de entrar em Apresentação de proposta, uma vez por entrada
  for r in
    select ng.id, ng.responsavel_id, ng.entrou_na_fase_em, e.nome as empresa
    from public.negocios ng join public.fases f on f.id = ng.fase_id join public.empresas e on e.id = ng.empresa_id
    where f.chave = 'proposta' and ng.encerrado_em is null and ng.responsavel_id is not null
      and privado.dia_util((ng.entrou_na_fase_em at time zone 'America/Sao_Paulo')::date + p.follow_up_proposta_dias) <= v_hoje
  loop
    continue when exists (select 1 from public.emails em where em.negocio_id = r.id and em.uso = 'pos_proposta' and em.created_at >= r.entrou_na_fase_em);
    continue when exists (select 1 from public.tarefas t where t.chave = format('pos_proposta:%s:%s', r.id, r.entrou_na_fase_em::date));
    if privado.enfileirar_redacao(r.id, 'pos_proposta', null, null, format('pos_proposta:%s:%s', r.id, r.entrou_na_fase_em::date)) is null then
      perform privado.criar_tarefa(r.responsavel_id, 'Follow-up da proposta · ' || r.empresa, v_hoje, r.id,
        format('pos_proposta:%s:%s', r.id, r.entrou_na_fase_em::date), 'Pergunte se a proposta foi analisada e se há dúvidas.');
    end if;
    n := n + 1;
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

  -- A7 · Organizador do dia: resumo para cada membro do Comercial
  if exists (select 1 from public.agentes where chave = 'organizador_dia' and ativo) then
    for r in
      select m.id,
        (select count(*) from public.tarefas t join public.tarefa_responsaveis tr on tr.tarefa_id = t.id
          where tr.membro_id = m.id and t.status <> 'concluida' and t.prazo <= v_hoje) as tarefas,
        (select count(*) from public.tarefas t join public.tarefa_responsaveis tr on tr.tarefa_id = t.id
          where tr.membro_id = m.id and t.status <> 'concluida' and t.prazo <= v_hoje and (t.chave like 'ligacao:%'
            or exists (select 1 from public.cadencia_passos ps where ps.canal = 'ligacao' and t.chave like 'cadencia:%:' || ps.id))) as ligacoes,
        (select count(*) from public.aprovacoes a where a.responsavel_id = m.id and a.status = 'pendente') as aprovar,
        (select count(*) from public.atividades a where a.responsavel_id = m.id and a.status in ('pendente', 'confirmada')
          and (a.inicio at time zone 'America/Sao_Paulo')::date = v_hoje) as compromissos
      from public.membros m join public.membro_diretorias md on md.membro_id = m.id and md.diretoria = 'comercial'
      where m.ativo
    loop
      continue when r.tarefas + r.aprovar + r.compromissos = 0;
      perform privado.notificar(r.id, 'resumo_dia', 'Seu dia',
        concat_ws(' · ', case when r.tarefas > 0 then r.tarefas || ' tarefa' || case when r.tarefas > 1 then 's' else '' end end,
          case when r.ligacoes > 0 then r.ligacoes || ' ligaç' || case when r.ligacoes > 1 then 'ões' else 'ão' end end,
          case when r.aprovar > 0 then r.aprovar || ' para aprovar' end,
          case when r.compromissos > 0 then r.compromissos || ' compromisso' || case when r.compromissos > 1 then 's' else '' end end),
        '/tarefas', format('resumo_dia:%s:%s', r.id, v_hoje));
    end loop;
  end if;

  return n;
end;
$$;

-- ---------------------------------------------------------------------
-- Indicadores da cadência de e-mail (respeita a RLS de quem consulta)
-- ---------------------------------------------------------------------
create or replace function public.indicadores_email(_de date, _ate date, _responsavel uuid default null)
returns jsonb language sql stable set search_path = '' as $$
  with env as (
    select em.* from public.emails em
    where em.status = 'enviado' and (em.enviado_em at time zone 'America/Sao_Paulo')::date between _de and _ate
      and (_responsavel is null or em.membro_id = _responsavel)
  ), resp as (
    select re.* from public.respostas_email re join env on env.id = re.email_id
  )
  select jsonb_build_object(
    'enviados', (select count(*) from env),
    'respondidos', (select count(distinct email_id) from resp where classificacao is distinct from 'ausencia'),
    'taxaResposta', (select case when count(*) > 0 then (select count(distinct email_id) from resp where classificacao is distinct from 'ausencia')::numeric / count(*) end from env),
    'porClassificacao', (select coalesce(jsonb_agg(jsonb_build_object('classificacao', coalesce(classificacao, 'aguardando'), 'quantidade', qt) order by qt desc), '[]')
                          from (select classificacao, count(*) qt from resp group by 1) x),
    'porCopy', (select coalesce(jsonb_agg(jsonb_build_object('copy_id', c.id, 'versao', c.versao, 'nome', c.nome, 'enviados', x.env, 'respostas', x.resp,
                    'taxa', case when x.env > 0 then x.resp::numeric / x.env end) order by c.versao), '[]')
                 from (select env.copy_id, count(*) env,
                         count(*) filter (where exists (select 1 from resp where resp.email_id = env.id and resp.classificacao is distinct from 'ausencia')) resp
                       from env where env.copy_id is not null group by 1) x
                 join public.copies_email c on c.id = x.copy_id)
  )
$$;
grant execute on function public.indicadores_email(date, date, uuid) to authenticated;

-- ---------------------------------------------------------------------
-- Copies iniciais (o diretor edita em Config. do funil → Copy)
-- ---------------------------------------------------------------------
with c as (
  insert into public.copies_email (versao, nome, uso, regra) values (1, 'Apresentação padrão', 'cadencia', 'qualquer') returning id
)
insert into public.copies_email_mensagens (copy_id, passo_id, assunto, corpo)
select c.id, ps.id, x.assunto, x.corpo
from c, public.cadencia_passos ps
join (values
  (0, '{{empresa}}: {{dor}}',
   E'{{saudacao}}, {{nome_contato}}.\n\nSou {{membro}}, da Aprimora, a consultoria em Engenharia de Produção da UEL. Acompanhamos empresas de {{segmento}} em {{cidade}} e região e percebemos que {{dor}} costuma pesar no resultado.\n\nNosso time trabalha com {{servico}}, com projetos curtos e acompanhamento de perto. {{dado_segmento}}\n\n{{cta}}\n\nAbraço,\n{{membro}}\nAprimora · Consultoria em Engenharia de Produção\n\nSe preferir não receber nossos e-mails, é só responder "remover".'),
  (3, 'Re: {{empresa}}: {{dor}}',
   E'{{saudacao}}, {{nome_contato}}.\n\nVoltando ao meu e-mail: {{dado_segmento}}\n\nSe fizer sentido, consigo mostrar em 20 minutos como o {{servico}} funcionaria na {{empresa}}.\n\n{{cta}}\n\n{{membro}}\nAprimora'),
  (8, 'Re: {{empresa}}: {{dor}}',
   E'{{saudacao}}, {{nome_contato}}.\n\nTentei falar com você por telefone nesta semana. Queria entender rapidamente como a {{empresa}} lida hoje com {{dor}}.\n\n{{cta}}\n\n{{membro}}\nAprimora'),
  (15, 'Re: {{empresa}}: {{dor}}',
   E'{{saudacao}}, {{nome_contato}}.\n\nNão quero tomar mais o seu tempo, então este é meu último e-mail por agora. Se em algum momento {{dor}} virar prioridade, é só responder esta mensagem que retomamos.\n\nObrigado pela atenção,\n{{membro}}\nAprimora')
) as x(dia, assunto, corpo) on x.dia = ps.dia
where ps.diretoria = 'comercial' and ps.canal = 'email';

with c as (insert into public.copies_email (versao, nome, uso, regra) values (2, 'Material pedido na ligação', 'pediu_email', 'qualquer') returning id)
insert into public.copies_email_mensagens (copy_id, passo_id, assunto, corpo)
select id, null, 'Material da Aprimora · {{empresa}}',
  E'{{saudacao}}, {{nome_contato}}.\n\nObrigado pela conversa por telefone. Como combinamos, segue um resumo de como a Aprimora pode ajudar a {{empresa}} com {{dor}}: trabalhamos com {{servico}}, em projetos curtos e com acompanhamento de perto.\n\n{{dado_segmento}}\n\n{{cta}}\n\nAbraço,\n{{membro}}\nAprimora · Consultoria em Engenharia de Produção'
from c;

with c as (insert into public.copies_email (versao, nome, uso, regra) values (3, 'Follow-up da proposta', 'pos_proposta', 'qualquer') returning id)
insert into public.copies_email_mensagens (copy_id, passo_id, assunto, corpo)
select id, null, 'Proposta da Aprimora · {{empresa}}',
  E'{{saudacao}}, {{nome_contato}}.\n\nPassando para saber se vocês conseguiram analisar a proposta de {{servico}} que apresentamos. Fico à disposição para tirar dúvidas ou ajustar o escopo.\n\n{{cta}}\n\nAbraço,\n{{membro}}\nAprimora'
from c;

-- ---------------------------------------------------------------------
-- Aprovação: e-mail aprovado vai para a fila de envio; descartado é cancelado; recusa confirmada encerra o lead
-- ---------------------------------------------------------------------
create or replace function public.aplicar_aprovacao()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  c jsonb := new.conteudo;
  n public.negocios%rowtype;
  v_contato uuid;
  v_emails text[];
  l public.ligacoes%rowtype;
  rl public.resultados_ligacao%rowtype;
  em public.emails%rowtype;
  v_motivo uuid;
  v_fase uuid;
begin
  -- E-mail descartado: o rascunho é cancelado (o toque da cadência não volta)
  if new.tipo = 'email' and new.status = 'descartada' and old.status = 'pendente' then
    update public.emails set status = 'cancelado' where id = new.email_id and status = 'rascunho';
    return null;
  end if;
  if new.status <> 'aprovada' or old.status = 'aprovada' then return null; end if;

  -- E-mail aprovado (com as edições): entra na fila de envio, no mesmo fio do e-mail anterior da cadência
  if new.tipo = 'email' and new.email_id is not null then
    select * into em from public.emails where id = new.email_id;
    if nullif(trim(c ->> 'para'), '') is null or trim(c ->> 'para') !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
      raise exception 'Informe um e-mail de destino válido';
    end if;
    if nullif(trim(c ->> 'corpo'), '') is null then raise exception 'O e-mail está vazio'; end if;
    if c ->> 'corpo' ~ '\{\{' or c ->> 'assunto' ~ '\{\{' then raise exception 'Ainda há variáveis {{ }} sem preencher'; end if;
    update public.emails set status = 'aprovado', aprovado_por = new.decidido_por, para = lower(trim(c ->> 'para')),
      assunto = trim(c ->> 'assunto'), corpo = trim(c ->> 'corpo'),
      responder_a = (select a.gmail_id from public.emails a where a.negocio_id = em.negocio_id and a.status = 'enviado'
                      and a.gmail_id is not null and a.uso = em.uso and a.d0 is not distinct from em.d0 and a.para = lower(trim(c ->> 'para'))
                      order by a.enviado_em desc limit 1)
    where id = em.id returning * into em;
    update public.emails set envio_trabalho_id = privado.enfileirar('redator', 'enviar_email', jsonb_build_object(
        'email_id', em.id, 'para', em.para, 'assunto', em.assunto, 'corpo', em.corpo, 'responder_a', em.responder_a,
        'thread_id', (select a.thread_id from public.emails a where a.gmail_id = em.responder_a limit 1),
        'remetente', (select remetente_nome from public.parametros_comercial where diretoria = 'comercial')),
      em.negocio_id, 'enviar:' || em.id)
    where id = em.id;
    update public.trabalhos set proximo_em = privado.proxima_janela_envio() where chave = 'enviar:' || em.id and status = 'pendente';
    if not found then
      raise exception 'O Redator está desligado: ligue-o em Config. do funil → Agentes para enviar e-mails';
    end if;
  end if;

  -- Recusa ou descadastro por e-mail confirmado: encerra como Lead não qualificado
  if new.tipo = 'resposta_recusa' and new.negocio_id is not null then
    select * into n from public.negocios where id = new.negocio_id;
    if n.encerrado_em is null then
      select m.id into v_motivo from public.motivos m
       where m.diretoria = 'comercial' and m.tipo = 'desqualificacao' and m.ativo
         and (m.chave = trim(c ->> 'motivo') or lower(m.nome) = lower(trim(c ->> 'motivo')))
       limit 1;
      if v_motivo is null then
        select m.id into v_motivo from public.motivos m where m.diretoria = 'comercial' and m.tipo = 'desqualificacao' and m.chave = 'sem_interesse';
      end if;
      select f.id into v_fase from public.fases f where f.funil_id = n.funil_id and f.chave = 'nao_qualificado' and f.excluida_em is null;
      perform set_config('aprimora.comentario_movimento', 'Resposta de e-mail: ' || coalesce(nullif(trim(c ->> 'comentario'), ''), 'recusa'), true);
      update public.negocios set fase_id = v_fase, motivo_id = coalesce(v_motivo, motivo_id),
        motivo_detalhe = nullif(trim(c ->> 'comentario'), '') where id = n.id;
      perform set_config('aprimora.comentario_movimento', '', true);
    end if;
  end if;

  if new.tipo = 'decisor_empresa' and new.negocio_id is not null then
    select * into n from public.negocios where id = new.negocio_id;
    -- Decisor vira contato (ou completa o contato de mesmo nome)
    if nullif(trim(c ->> 'decisor_nome'), '') is not null then
      select id into v_contato from public.contatos
       where empresa_id = n.empresa_id and public.normalizar(nome) = public.normalizar(trim(c ->> 'decisor_nome')) limit 1;
      if v_contato is null then
        insert into public.contatos (empresa_id, nome, cargo, decisor, email, telefone, linkedin, observacoes, criado_por)
        values (n.empresa_id, trim(c ->> 'decisor_nome'), nullif(trim(c ->> 'decisor_cargo'), ''), true,
                nullif(trim(c ->> 'decisor_email'), ''), nullif(trim(c ->> 'decisor_telefone'), ''),
                nullif(trim(c ->> 'decisor_linkedin'), ''), 'Sugerido pelo Enriquecedor e aprovado.', new.decidido_por)
        returning id into v_contato;
      else
        update public.contatos set decisor = true,
          cargo = coalesce(nullif(cargo, ''), nullif(trim(c ->> 'decisor_cargo'), '')),
          email = coalesce(nullif(email, ''), nullif(trim(c ->> 'decisor_email'), '')),
          telefone = coalesce(nullif(telefone, ''), nullif(trim(c ->> 'decisor_telefone'), '')),
          linkedin = coalesce(nullif(linkedin, ''), nullif(trim(c ->> 'decisor_linkedin'), ''))
        where id = v_contato;
      end if;
      update public.negocios set contato_id = coalesce(contato_id, v_contato) where id = n.id;
    end if;
    -- Outros e-mails completam os campos de e-mail vazios da empresa
    select array_agg(x) into v_emails from (
      select trim(x) as x from regexp_split_to_table(coalesce(c ->> 'outros_emails', ''), '[\n,; ]+') x where trim(x) like '%@%') s;
    if v_emails is not null then
      update public.empresas set
        email_principal = coalesce(nullif(email_principal, ''), v_emails[1]),
        email_secundario = coalesce(nullif(email_secundario, ''), case when nullif(email_principal, '') is null then v_emails[2] else v_emails[1] end),
        email_terciario = coalesce(nullif(email_terciario, ''), case when nullif(email_principal, '') is null then v_emails[3] else v_emails[2] end)
      where id = n.empresa_id;
    end if;
    -- Hipóteses de dor entram nas dores do negócio
    if nullif(trim(c ->> 'hipoteses_de_dor'), '') is not null then
      update public.negocios set dores_identificadas = concat_ws(E'\n\n', nullif(dores_identificadas, ''),
        'Hipóteses do Enriquecedor (a confirmar na ligação):' || E'\n' || trim(c ->> 'hipoteses_de_dor'))
      where id = n.id;
    end if;
  end if;

  if new.tipo = 'resultado_ligacao' and new.ligacao_id is not null then
    select * into l from public.ligacoes where id = new.ligacao_id;
    select * into rl from public.resultados_ligacao
     where ativo and (chave = trim(c ->> 'resultado') or lower(nome) = lower(trim(c ->> 'resultado'))) limit 1;
    if not found then raise exception 'Escolha um resultado válido para a ligação'; end if;
    update public.ligacoes set
      resultado_id = rl.id,
      proximo_passo = nullif(trim(c ->> 'proximo_passo'), ''),
      retorno_em = nullif(trim(c ->> 'retorno_em'), '')::date,
      compromisso_em = (nullif(trim(c ->> 'compromisso_em'), '')::timestamp at time zone 'America/Sao_Paulo'),
      decisor_nome = nullif(trim(c ->> 'decisor_nome'), ''),
      decisor_melhor_horario = nullif(trim(c ->> 'decisor_melhor_horario'), ''),
      comentario = nullif(trim(c ->> 'resumo'), '')
    where id = l.id;
    if nullif(trim(c ->> 'dores'), '') is not null then
      update public.negocios set dores_identificadas = concat_ws(E'\n\n', nullif(dores_identificadas, ''),
        'Dores citadas na ligação de ' || to_char(l.inicio at time zone 'America/Sao_Paulo', 'DD/MM/YYYY') || ':' || E'\n' || trim(c ->> 'dores'))
      where id = l.negocio_id;
    end if;
  end if;
  return null;
end;
$$;

-- Redator e Monitor ficam desligados até o fluxo do n8n e a credencial Gmail da comercial@ existirem
-- (enquanto isso, os toques de e-mail continuam como tarefa manual)
update public.agentes set ativo = false where chave in ('redator', 'monitor_respostas');
