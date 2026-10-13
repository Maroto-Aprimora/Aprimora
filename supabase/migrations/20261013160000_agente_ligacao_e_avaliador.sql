-- =====================================================================
-- v2 · Fase 2 · 2.3 — A2 Agente de ligação e A3 Avaliador de ligações (PE-PA-002, Seções 3.1, 5 e 5.1)
-- Chamada da API4COM (webhook ou consulta do n8n) → ligação no negócio certo (telefone + e-mail do membro)
-- → n8n baixa a gravação pelo link da API4COM → Gemini transcreve, resume, sugere o resultado (lista 3.1),
-- dores e próximo passo, e avalia pela rubrica → o membro confirma o resultado na Caixa de aprovação
-- (o resultado aplicado move o card e cria as tarefas, como no registro manual). A avaliação é só leitura.
-- Ligação sem conversa (sem gravação ou com menos de 15 s) não gasta IA: vai direto como "Não atendeu".
-- =====================================================================

-- Rubrica do Avaliador (configurável pelo diretor)
create table public.rubrica_criterios (
  id uuid primary key default gen_random_uuid(),
  chave text not null unique,
  nome text not null,
  descricao text not null,
  ordem int not null default 0,
  ativo boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.rubrica_criterios enable row level security;
create policy rubrica_ler on public.rubrica_criterios for select to authenticated using ((select privado.membro_ativo()));
create policy rubrica_gerir on public.rubrica_criterios for all to authenticated
  using (privado.eh_diretor_de('comercial')) with check (privado.eh_diretor_de('comercial'));
revoke all on public.rubrica_criterios from anon;
insert into public.rubrica_criterios (chave, nome, descricao, ordem) values
  ('abertura', 'Abertura', 'Apresentação clara da Aprimora e do motivo da ligação nos primeiros 40 segundos.', 1),
  ('decisor', 'Decisor', 'Chegou ou tentou chegar a quem decide.', 2),
  ('descoberta', 'Descoberta', 'Perguntas sobre a operação e as dores do lead.', 3),
  ('proposta_valor', 'Proposta de valor', 'Ligou a dor do lead a um serviço da Aprimora.', 4),
  ('objecoes', 'Objeções', 'Respondeu sem encerrar a conversa.', 5),
  ('proximo_passo', 'Próximo passo', 'Saiu com uma data, um e-mail ou um retorno combinado.', 6),
  ('escuta', 'Escuta', 'Proporção de fala entre membro e lead.', 7);

-- Avaliação de cada ligação (A3): membro vê as suas; diretor vê todas; ninguém escreve pela API
create table public.avaliacoes_ligacao (
  id uuid primary key default gen_random_uuid(),
  ligacao_id uuid not null unique references public.ligacoes (id) on delete cascade,
  membro_id uuid not null references public.membros (id) on delete cascade,
  notas jsonb not null default '[]',      -- [{chave, nome, nota 1–4, comentario}]
  media numeric(3, 2),
  comentario text,
  created_at timestamptz not null default now()
);
create index avaliacoes_ligacao_membro_idx on public.avaliacoes_ligacao (membro_id, created_at desc);
alter table public.avaliacoes_ligacao enable row level security;
create policy avaliacoes_ler on public.avaliacoes_ligacao for select to authenticated
  using (membro_id = (select auth.uid()) or privado.eh_diretor_de('comercial'));
revoke all on public.avaliacoes_ligacao from anon;
revoke insert, update, delete on public.avaliacoes_ligacao from authenticated;

-- A aprovação do resultado aponta para a ligação
alter table public.aprovacoes add column ligacao_id uuid references public.ligacoes (id) on delete cascade;
create index aprovacoes_ligacao_idx on public.aprovacoes (ligacao_id) where ligacao_id is not null;

-- ---------------------------------------------------------------------
-- Aprovação "Confirmar resultado da ligação" para quem ligou
-- ---------------------------------------------------------------------
create or replace function privado.aprovacao_resultado_ligacao(_ligacao uuid, _trabalho uuid, _s jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  l public.ligacoes%rowtype;
  v_empresa text;
  v_id uuid;
  v_dores text;
  v_res text;
  c jsonb;
begin
  select * into l from public.ligacoes where id = _ligacao;
  if not found or l.resultado_id is not null then return null; end if;
  if exists (select 1 from public.aprovacoes where ligacao_id = l.id and status = 'pendente') then return null; end if;
  select e.nome into v_empresa from public.negocios n join public.empresas e on e.id = n.empresa_id where n.id = l.negocio_id;
  select string_agg('• ' || x, E'\n') into v_dores from jsonb_array_elements_text(coalesce(_s -> 'dores', '[]')) x where nullif(trim(x), '') is not null;
  select chave into v_res from public.resultados_ligacao where ativo and chave = _s ->> 'resultado';
  c := jsonb_build_object(
    'resultado', coalesce(v_res, ''),
    'proximo_passo', coalesce(_s ->> 'proximo_passo', ''),
    'retorno_em', coalesce(_s ->> 'retorno_em', ''),
    'compromisso_em', coalesce(_s ->> 'compromisso_em', ''),
    'decisor_nome', coalesce(_s ->> 'decisor_nome', ''),
    'decisor_melhor_horario', coalesce(_s ->> 'decisor_melhor_horario', ''),
    'dores', coalesce(v_dores, ''),
    'resumo', coalesce(_s ->> 'resumo', ''));
  insert into public.aprovacoes (agente, tipo, trabalho_id, negocio_id, ligacao_id, responsavel_id, titulo, resumo, conteudo, conteudo_original)
  values ('ligacao', 'resultado_ligacao', _trabalho, l.negocio_id, l.id, l.membro_id,
          'Confirmar resultado da ligação · ' || coalesce(v_empresa, 'lead'),
          format('Ligação de %s, %s min.', to_char(l.inicio at time zone 'America/Sao_Paulo', 'DD/MM HH24:MI'),
                 greatest(1, round(coalesce(l.duracao_seg, 0) / 60.0))),
          c, c)
  returning id into v_id;
  return v_id;
end;
$$;

-- ---------------------------------------------------------------------
-- Eventos da API4COM → ligações (formato de GET /api/v1/calls; o do webhook fica guardado)
-- Telefone: últimos 10 dígitos do número discado contra contatos e empresas; negócio aberto da empresa,
-- de preferência do próprio membro. Sem negócio: o evento espera (até 7 dias) e é tentado de novo.
-- ---------------------------------------------------------------------
create or replace function privado.processar_eventos_api4com()
returns int language plpgsql security definer set search_path = '' as $$
declare
  ev public.eventos_integracoes%rowtype;
  p jsonb;
  v_membro uuid;
  v_num text;
  v_contato uuid;
  v_empresa uuid;
  v_negocio uuid;
  v_lig uuid;
  v_dur int;
  v_trab uuid;
  v_feitas int := 0;
  n public.negocios%rowtype;
begin
  for ev in
    select * from public.eventos_integracoes
     where origem = 'api4com' and processado_em is null and payload ? 'ended_at' and recebido_em > now() - interval '7 days'
     order by id
     for update skip locked
  loop
    p := ev.payload;
    select m.id into v_membro from public.membros m where m.ativo and lower(m.email) = lower(p ->> 'email');
    if v_membro is null then
      update public.eventos_integracoes set erro = format('Nenhum membro ativo com o e-mail %s', p ->> 'email') where id = ev.id;
      continue;
    end if;
    v_num := right(public.so_digitos(case when p ->> 'call_type' = 'inbound' then p ->> 'from' else p ->> 'to' end), 10);
    if coalesce(length(v_num), 0) < 10 then
      update public.eventos_integracoes set erro = 'Número da ligação incompleto', processado_em = now() where id = ev.id;
      continue;
    end if;
    v_contato := null; v_empresa := null; v_negocio := null;
    select c.id, c.empresa_id into v_contato, v_empresa from public.contatos c
     where right(public.so_digitos(c.telefone), 10) = v_num limit 1;
    if v_empresa is null then
      select e.id into v_empresa from public.empresas e where right(e.telefone_digitos, 10) = v_num limit 1;
    end if;
    if v_empresa is not null then
      select x.id into v_negocio from public.negocios x
       where x.empresa_id = v_empresa and x.encerrado_em is null
       order by (x.responsavel_id = v_membro) desc nulls last, x.updated_at desc limit 1;
    end if;
    if v_negocio is null then
      update public.eventos_integracoes set erro = format('Nenhum negócio aberto com o telefone %s', v_num) where id = ev.id;
      continue;
    end if;

    v_dur := coalesce((p ->> 'duration')::int, 0);
    insert into public.ligacoes (negocio_id, contato_id, membro_id, inicio, duracao_seg, telefone, origem, api4com_id, gravacao_url, criado_por)
    values (v_negocio, v_contato, v_membro, coalesce((p ->> 'started_at')::timestamptz, ev.recebido_em), v_dur,
            p ->> case when p ->> 'call_type' = 'inbound' then 'from' else 'to' end, 'agente', p ->> 'id', nullif(p ->> 'record_url', ''), null)
    on conflict (api4com_id) do nothing
    returning id into v_lig;
    if v_lig is null then
      select id into v_lig from public.ligacoes where api4com_id = p ->> 'id';
      update public.eventos_integracoes set processado_em = now(), ligacao_id = v_lig, erro = null where id = ev.id;
      continue;
    end if;
    update public.eventos_integracoes set processado_em = now(), ligacao_id = v_lig, erro = null where id = ev.id;
    v_feitas := v_feitas + 1;

    v_trab := null;
    if nullif(p ->> 'record_url', '') is not null and v_dur >= 15 then
      select * into n from public.negocios where id = v_negocio;
      v_trab := privado.enfileirar('ligacao', 'transcrever_ligacao', jsonb_build_object(
        'ligacao_id', v_lig,
        'gravacao_url', p ->> 'record_url',
        'duracao_seg', v_dur,
        'membro', (select nome from public.membros where id = v_membro),
        'empresa', (select jsonb_build_object('nome', e.nome, 'segmento', (select s.nome from public.segmentos s where s.id = e.segmento_id))
                      from public.empresas e where e.id = n.empresa_id),
        'contato', (select jsonb_build_object('nome', c.nome, 'cargo', c.cargo) from public.contatos c where c.id = v_contato),
        'fase', (select f.nome from public.fases f where f.id = n.fase_id),
        'dores_atuais', coalesce(n.dores_identificadas, ''),
        'hoje', privado.hoje(),
        'resultados', (select jsonb_agg(jsonb_build_object('chave', r.chave, 'nome', r.nome) order by r.ordem)
                         from public.resultados_ligacao r where r.ativo),
        'servicos', (select jsonb_agg(s.nome order by s.ordem) from public.servicos s where s.ativo and s.diretoria = 'comercial'),
        'rubrica', case when exists (select 1 from public.agentes where chave = 'avaliador' and ativo)
                        then (select jsonb_agg(jsonb_build_object('chave', r.chave, 'nome', r.nome, 'descricao', r.descricao) order by r.ordem)
                                from public.rubrica_criterios r where r.ativo) end
      ), v_negocio, 'ligacao:' || v_lig);
    end if;
    if v_trab is null then
      -- Sem conversa (ou Agente de ligação desligado): sugere pelo que a API4COM informa
      perform privado.aprovacao_resultado_ligacao(v_lig, null, jsonb_build_object(
        'resultado', case when v_dur < 15 then 'nao_atendeu' else '' end,
        'resumo', case when v_dur < 15 then format('Ligação sem conversa (%s s, %s).', v_dur, coalesce(p ->> 'hangup_cause', 'sem motivo'))
                       else 'Agente de ligação desligado: confira o resultado.' end));
    end if;
  end loop;
  return v_feitas;
end;
$$;

-- Webhook e consulta processam na hora
create or replace function public.n8n_registrar_chamadas(_segredo text, _chamadas jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_novas int;
begin
  if not privado.n8n_autorizado(_segredo) then raise exception 'não autorizado'; end if;
  if jsonb_typeof(_chamadas) is distinct from 'array' then raise exception 'chamadas deve ser uma lista'; end if;
  with ins as (
    insert into public.eventos_integracoes (origem, payload, externo_id)
    select 'api4com', jsonb_set(c, '{_fonte}', '"consulta"'), c ->> 'id'
    from jsonb_array_elements(_chamadas) c
    where nullif(c ->> 'id', '') is not null
    on conflict (origem, externo_id) where externo_id is not null do nothing
    returning 1)
  select count(*) into v_novas from ins;
  return jsonb_build_object('ok', true, 'recebidas', jsonb_array_length(_chamadas), 'novas', v_novas,
    'ligacoes', privado.processar_eventos_api4com());
end;
$$;

-- ---------------------------------------------------------------------
-- Resultado do Agente de ligação (+ Avaliador)
-- resultado = { transcricao, resumo, resultado (chave da lista 3.1), proximo_passo, retorno_em, compromisso_em,
--               decisor_nome, decisor_melhor_horario, dores: [], avaliacao: { notas: [{chave, nota, comentario}], comentario } }
-- ---------------------------------------------------------------------
create or replace function privado.aplicar_ligacao(t public.trabalhos, r jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare
  l public.ligacoes%rowtype;
  v_notas jsonb;
  v_media numeric;
begin
  select * into l from public.ligacoes where id = (t.payload ->> 'ligacao_id')::uuid;
  if not found then return; end if;
  update public.ligacoes set transcricao = nullif(r ->> 'transcricao', ''), resumo = nullif(r ->> 'resumo', '') where id = l.id;
  perform privado.aprovacao_resultado_ligacao(l.id, t.id, r);

  if jsonb_typeof(r -> 'avaliacao' -> 'notas') = 'array' and exists (select 1 from public.agentes where chave = 'avaliador' and ativo) then
    select jsonb_agg(jsonb_build_object('chave', rc.chave, 'nome', rc.nome,
             'nota', least(4, greatest(1, (x ->> 'nota')::int)), 'comentario', coalesce(x ->> 'comentario', '')) order by rc.ordem),
           avg(least(4, greatest(1, (x ->> 'nota')::int)))
      into v_notas, v_media
      from jsonb_array_elements(r -> 'avaliacao' -> 'notas') x
      join public.rubrica_criterios rc on rc.chave = x ->> 'chave'
     where (x ->> 'nota') ~ '^[0-9]+$';
    if v_notas is not null then
      insert into public.avaliacoes_ligacao (ligacao_id, membro_id, notas, media, comentario)
      values (l.id, l.membro_id, v_notas, round(v_media, 2), nullif(r -> 'avaliacao' ->> 'comentario', ''))
      on conflict (ligacao_id) do update set notas = excluded.notas, media = excluded.media, comentario = excluded.comentario;
    end if;
  end if;
end;
$$;

create or replace function privado.aplicar_resultado_agente(t public.trabalhos, r jsonb)
returns void language plpgsql security definer set search_path = '' as $$
begin
  case t.agente
    when 'enriquecedor' then perform privado.aplicar_enriquecimento(t, r);
    when 'analista_gerencial' then perform privado.aplicar_relatorio(t, r);
    when 'ligacao' then perform privado.aplicar_ligacao(t, r);
    else null;
  end case;
end;
$$;

-- Agente de ligação falhou 3 vezes: o membro confirma o resultado sem a sugestão
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
    if t.agente = 'analista_gerencial' then
      update public.relatorios set status = 'erro', erro = v_msg where id = (t.payload ->> 'relatorio_id')::uuid;
    elsif t.agente = 'ligacao' then
      perform privado.aprovacao_resultado_ligacao((t.payload ->> 'ligacao_id')::uuid, t.id,
        jsonb_build_object('resumo', 'O Agente de ligação não conseguiu ouvir a gravação: confira o resultado.'));
    end if;
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

-- Aprovação: agora também confirma o resultado da ligação (o resultado aplicado move o card e cria as tarefas)
create or replace function public.aplicar_aprovacao()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  c jsonb := new.conteudo;
  n public.negocios%rowtype;
  v_contato uuid;
  v_emails text[];
  l public.ligacoes%rowtype;
  rl public.resultados_ligacao%rowtype;
begin
  if new.status <> 'aprovada' or old.status = 'aprovada' then return null; end if;

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
