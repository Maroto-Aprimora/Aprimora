-- =====================================================================
-- v2 · Fase 2 · 2.1 e 2.2 — A1 Enriquecedor e A4 Analista gerencial (PE-PA-002, Seção 5)
-- A1: card entra em Enriquecimento → trabalho na fila → n8n (Gemini com busca + BrasilAPI) → dados públicos entram
--     direto na empresa (só campos vazios); decisor, e-mails e hipóteses de dor vão para a Caixa de aprovação;
--     o que faltar vira a tarefa "Completar dados".
-- A4: botão do diretor → relatório da R.I com os números calculados no banco → n8n (Gemini) escreve destaques,
--     pontos de atenção e o rascunho do plano de melhoria por membro → diretor revisa antes de compartilhar.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Empresa: registro do enriquecimento
-- ---------------------------------------------------------------------
alter table public.empresas
  add column enriquecido_em timestamptz,
  add column enriquecimento jsonb,          -- resultado completo do agente (dados públicos, fontes, sócios)
  add column porte text,
  add column cnae text,
  add column situacao_cadastral text;

-- Quem recebe o que o agente prepara: o responsável do negócio, senão quem criou, senão os diretores comerciais
create or replace function privado.destinatario_negocio(_negocio uuid, _fallback uuid default null)
returns uuid language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select n.responsavel_id from public.negocios n join public.membros m on m.id = n.responsavel_id and m.ativo where n.id = _negocio),
    (select m.id from public.membros m where m.id = _fallback and m.ativo),
    (select md.membro_id from public.membro_diretorias md join public.membros m on m.id = md.membro_id and m.ativo
      where md.diretoria = 'comercial' and md.cargo = 'diretor' order by m.nome limit 1))
$$;

-- ---------------------------------------------------------------------
-- A1 · Enfileirar o enriquecimento de um negócio
-- ---------------------------------------------------------------------
create or replace function privado.enfileirar_enriquecimento(_negocio uuid, _chave text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  n public.negocios%rowtype;
  e public.empresas%rowtype;
begin
  select * into n from public.negocios where id = _negocio;
  if not found then return null; end if;
  select * into e from public.empresas where id = n.empresa_id;
  return privado.enfileirar('enriquecedor', 'enriquecer_empresa', jsonb_build_object(
    'negocio_id', n.id,
    'empresa', jsonb_build_object('id', e.id, 'nome', e.nome, 'razao_social', e.razao_social, 'cnpj', e.cnpj_digitos,
      'site', e.site, 'telefone', e.telefone, 'email', e.email_principal, 'cidade', e.cidade, 'uf', e.uf,
      'segmento', (select s.nome from public.segmentos s where s.id = e.segmento_id)),
    'contatos', coalesce((select jsonb_agg(jsonb_build_object('nome', c.nome, 'cargo', c.cargo, 'email', c.email, 'decisor', c.decisor))
                          from public.contatos c where c.empresa_id = e.id), '[]'),
    'segmentos', (select jsonb_agg(s.nome order by s.nome) from public.segmentos s where s.ativo and s.diretoria = 'comercial'),
    'servicos', (select jsonb_agg(s.nome order by s.ordem) from public.servicos s where s.ativo and s.diretoria = 'comercial')
  ), n.id, _chave);
end;
$$;

-- Entrou em Enriquecimento: enfileira (se o agente estiver ligado)
create or replace function public.agentes_ao_mudar_fase()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.fases f where f.id = new.fase_destino_id and f.chave = 'enriquecimento') then
    perform privado.enfileirar_enriquecimento(new.negocio_id, format('enriquecer:%s:%s', new.negocio_id, new.id));
  end if;
  return null;
end;
$$;
create trigger agentes_ao_mudar_fase after insert on public.negocio_historico
  for each row execute function public.agentes_ao_mudar_fase();
revoke all on function public.agentes_ao_mudar_fase() from public, anon, authenticated;

-- Botão "Enriquecer agora" no negócio (quem pode editar o negócio)
create or replace function public.enriquecer_negocio(_negocio uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v uuid;
begin
  if not privado.pode_editar_negocio(_negocio) then raise exception 'Sem permissão para este negócio'; end if;
  if not exists (select 1 from public.agentes where chave = 'enriquecedor' and ativo) then
    raise exception 'O Enriquecedor está desligado (Config. do funil → Agentes e fila)';
  end if;
  if exists (select 1 from public.trabalhos where negocio_id = _negocio and agente = 'enriquecedor' and status in ('pendente', 'processando')) then
    raise exception 'Este negócio já está na fila do Enriquecedor';
  end if;
  v := privado.enfileirar_enriquecimento(_negocio, format('enriquecer:%s:manual:%s', _negocio, extract(epoch from now())::bigint));
  return v;
end;
$$;
revoke all on function public.enriquecer_negocio(uuid) from public, anon;
grant execute on function public.enriquecer_negocio(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- A1 · Aplicar o resultado
-- resultado = { dados_publicos: {cnpj, razao_social, nome_fantasia, telefone, email, site, endereco, cidade, uf,
--               cnae, porte, situacao}, segmento, decisor: {nome, cargo, email, telefone, linkedin},
--               emails: [], hipoteses_dor: [], resumo, fontes: [] }
-- ---------------------------------------------------------------------
create or replace function privado.aplicar_enriquecimento(t public.trabalhos, r jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare
  n public.negocios%rowtype;
  e public.empresas%rowtype;
  d jsonb := coalesce(r -> 'dados_publicos', '{}');
  dec jsonb := coalesce(r -> 'decisor', '{}');
  v_dest uuid;
  v_emails text;
  v_dores text;
  v_falta text[] := '{}';
  txt text;
begin
  select * into n from public.negocios where id = t.negocio_id;
  if not found then return; end if;
  select * into e from public.empresas where id = n.empresa_id;

  -- Dados públicos: preenchem só o que está vazio (o que o time digitou nunca é sobrescrito)
  update public.empresas set
    cnpj = coalesce(nullif(cnpj, ''), nullif(d ->> 'cnpj', '')),
    razao_social = coalesce(nullif(razao_social, ''), nullif(d ->> 'razao_social', '')),
    telefone = coalesce(nullif(telefone, ''), nullif(d ->> 'telefone', '')),
    email_principal = coalesce(nullif(email_principal, ''), nullif(d ->> 'email', '')),
    site = coalesce(nullif(site, ''), nullif(d ->> 'site', '')),
    endereco = coalesce(nullif(endereco, ''), nullif(d ->> 'endereco', '')),
    cidade = coalesce(nullif(cidade, ''), nullif(d ->> 'cidade', '')),
    uf = coalesce(nullif(uf, ''), nullif(upper(left(d ->> 'uf', 2)), '')),
    cnae = coalesce(nullif(d ->> 'cnae', ''), cnae),
    porte = coalesce(nullif(d ->> 'porte', ''), porte),
    situacao_cadastral = coalesce(nullif(d ->> 'situacao', ''), situacao_cadastral),
    segmento_id = coalesce(segmento_id, (select s.id from public.segmentos s
                    where s.ativo and s.diretoria = 'comercial' and lower(s.nome) = lower(r ->> 'segmento') limit 1)),
    enriquecido_em = now(),
    enriquecimento = r
  where id = e.id
  returning * into e;

  v_dest := privado.destinatario_negocio(n.id, t.criado_por);

  -- Decisor, e-mails e hipóteses de dor: o responsável confirma na Caixa de aprovação
  select string_agg(x, E'\n') into v_emails from jsonb_array_elements_text(coalesce(r -> 'emails', '[]')) x where nullif(trim(x), '') is not null;
  select string_agg('• ' || x, E'\n') into v_dores from jsonb_array_elements_text(coalesce(r -> 'hipoteses_dor', '[]')) x where nullif(trim(x), '') is not null;
  if nullif(dec ->> 'nome', '') is not null or v_emails is not null or v_dores is not null then
    insert into public.aprovacoes (agente, tipo, trabalho_id, negocio_id, responsavel_id, titulo, resumo, conteudo, conteudo_original)
    select t.agente, 'decisor_empresa', t.id, n.id, v_dest, 'Confirmar decisor e e-mails · ' || e.nome,
      concat_ws(' ', nullif(r ->> 'resumo', ''),
        case when jsonb_array_length(coalesce(r -> 'fontes', '[]')) > 0
             then 'Fontes: ' || (select string_agg(f, ', ') from jsonb_array_elements_text(r -> 'fontes') f) end),
      c, c
    from (select jsonb_build_object(
      'decisor_nome', coalesce(dec ->> 'nome', ''), 'decisor_cargo', coalesce(dec ->> 'cargo', ''),
      'decisor_email', coalesce(dec ->> 'email', ''), 'decisor_telefone', coalesce(dec ->> 'telefone', ''),
      'decisor_linkedin', coalesce(dec ->> 'linkedin', ''),
      'outros_emails', coalesce(v_emails, ''), 'hipoteses_de_dor', coalesce(v_dores, '')) as c) x;
  end if;

  -- O que faltou vira tarefa
  if coalesce(e.cnpj, '') = '' then v_falta := v_falta || 'CNPJ'; end if;
  if coalesce(e.telefone, '') = '' then v_falta := v_falta || 'telefone'; end if;
  if coalesce(e.email_principal, '') = '' and v_emails is null and coalesce(dec ->> 'email', '') = '' then v_falta := v_falta || 'e-mail'; end if;
  if nullif(dec ->> 'nome', '') is null and not exists (select 1 from public.contatos c where c.empresa_id = e.id and c.decisor) then
    v_falta := v_falta || 'decisor';
  end if;
  if array_length(v_falta, 1) > 0 then
    txt := array_to_string(v_falta, ', ');
    perform privado.criar_tarefa(v_dest, 'Completar dados do lead · ' || e.nome, privado.dia_util(privado.hoje() + 1), n.id,
      format('completar_dados:%s:%s', n.id, t.id), 'O Enriquecedor não encontrou: ' || txt || '.', 'agente');
  end if;
end;
$$;

-- ---------------------------------------------------------------------
-- Aprovação: o que acontece quando o responsável aprova
-- ---------------------------------------------------------------------
create or replace function public.aplicar_aprovacao()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  c jsonb := new.conteudo;
  n public.negocios%rowtype;
  v_contato uuid;
  v_emails text[];
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
  return null;
end;
$$;
create trigger aplicar_aprovacao after update of status on public.aprovacoes
  for each row execute function public.aplicar_aprovacao();
revoke all on function public.aplicar_aprovacao() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- A4 · Relatórios da R.I
-- ---------------------------------------------------------------------
create type public.status_relatorio as enum ('gerando', 'pronto', 'erro');

create table public.relatorios (
  id uuid primary key default gen_random_uuid(),
  tipo text not null default 'ri',
  de date not null,
  ate date not null,
  dados jsonb not null,                -- números calculados no banco (fonte da verdade)
  analise jsonb,                       -- texto do Analista gerencial (resumo, destaques, atenção, planos por membro)
  texto_revisado text,                 -- versão revisada pelo diretor, pronta para compartilhar
  status public.status_relatorio not null default 'gerando',
  erro text,
  trabalho_id uuid references public.trabalhos (id) on delete set null,
  revisado_por uuid references public.membros (id) on delete set null,
  revisado_em timestamptz,
  criado_por uuid references public.membros (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger relatorios_updated_at before update on public.relatorios for each row execute function public.tocar_updated_at();
alter table public.relatorios enable row level security;
create policy relatorios_ler on public.relatorios for select to authenticated using (privado.eh_diretor_de('comercial'));
create policy relatorios_revisar on public.relatorios for update to authenticated
  using (privado.eh_diretor_de('comercial')) with check (privado.eh_diretor_de('comercial'));
revoke all on public.relatorios from anon;
revoke insert, delete on public.relatorios from authenticated;

-- Números do relatório: semana, trimestre, cada membro, SLA estourado e tarefas atrasadas
create or replace function privado.dados_relatorio_ri(_de date, _ate date)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'periodo', jsonb_build_object('de', _de, 'ate', _ate),
    'semana', public.indicadores_comerciais(_de, _ate),
    'trimestre', public.indicadores_comerciais(date_trunc('quarter', _ate)::date, _ate),
    'membros', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', m.id, 'nome', m.nome, 'cargo', md.cargo,
        'semana', public.indicadores_comerciais(_de, _ate, m.id) -> 'resumo',
        'ligacoes_semana', public.indicadores_comerciais(_de, _ate, m.id) -> 'coldcall',
        'trimestre', public.indicadores_comerciais(date_trunc('quarter', _ate)::date, _ate, m.id) -> 'resumo',
        'tarefas_atrasadas', (select count(*) from public.tarefas t join public.tarefa_responsaveis tr on tr.tarefa_id = t.id
                              where tr.membro_id = m.id and t.status <> 'concluida' and t.prazo < privado.hoje()),
        'negocios_ativos', (select count(*) from public.negocios n where n.responsavel_id = m.id and n.encerrado_em is null)
      ) order by m.nome)
      from public.membro_diretorias md join public.membros m on m.id = md.membro_id and m.ativo
      where md.diretoria = 'comercial'), '[]'),
    'sla_estourado', coalesce((
      select jsonb_agg(x order by x ->> 'dias' desc) from (
        select jsonb_build_object('negocio', n.titulo, 'fase', f.nome, 'sla', f.sla_dias,
          'dias', floor(extract(epoch from now() - n.entrou_na_fase_em) / 86400)::int,
          'responsavel', (select nome from public.membros where id = n.responsavel_id)) x
        from public.negocios n join public.fases f on f.id = n.fase_id
        where n.encerrado_em is null and f.sla_dias is not null
          and n.entrou_na_fase_em < now() - make_interval(days => f.sla_dias)
        order by n.entrou_na_fase_em limit 20) s), '[]')
  )
$$;

-- Botão "Gerar relatório da R.I" (diretor comercial)
create or replace function public.gerar_relatorio_ri(_de date default null, _ate date default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_ate date := coalesce(_ate, privado.hoje());
  v_de date := coalesce(_de, v_ate - 6);
  v_id uuid;
  v_trab uuid;
  v_dados jsonb;
begin
  if not privado.eh_diretor_de('comercial') then raise exception 'Só o Diretor Comercial gera o relatório da R.I'; end if;
  if v_de > v_ate then raise exception 'Período inválido'; end if;
  v_dados := privado.dados_relatorio_ri(v_de, v_ate);
  insert into public.relatorios (tipo, de, ate, dados, status, criado_por)
  values ('ri', v_de, v_ate, v_dados, 'gerando', (select auth.uid())) returning id into v_id;
  v_trab := privado.enfileirar('analista_gerencial', 'relatorio_ri', jsonb_build_object('relatorio_id', v_id, 'dados', v_dados));
  if v_trab is null then
    -- Agente desligado: o relatório sai só com os números
    update public.relatorios set status = 'pronto', erro = 'Analista gerencial desligado: relatório só com os números.' where id = v_id;
  else
    update public.relatorios set trabalho_id = v_trab where id = v_id;
  end if;
  return v_id;
end;
$$;
revoke all on function public.gerar_relatorio_ri(date, date) from public, anon;
grant execute on function public.gerar_relatorio_ri(date, date) to authenticated;

create or replace function privado.aplicar_relatorio(t public.trabalhos, r jsonb)
returns void language sql security definer set search_path = '' as $$
  update public.relatorios set analise = coalesce(r -> 'analise', r), status = 'pronto', erro = null
  where id = (t.payload ->> 'relatorio_id')::uuid
$$;

-- ---------------------------------------------------------------------
-- Despacho por agente: n8n_concluir aplica o resultado; n8n_falhar marca o relatório com erro
-- ---------------------------------------------------------------------
create or replace function privado.aplicar_resultado_agente(t public.trabalhos, r jsonb)
returns void language plpgsql security definer set search_path = '' as $$
begin
  case t.agente
    when 'enriquecedor' then perform privado.aplicar_enriquecimento(t, r);
    when 'analista_gerencial' then perform privado.aplicar_relatorio(t, r);
    else null;
  end case;
end;
$$;

create or replace function public.n8n_concluir(_segredo text, _id uuid, _resultado jsonb default '{}')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  t public.trabalhos%rowtype;
  a jsonb := _resultado -> 'aprovacao';
begin
  if not privado.n8n_autorizado(_segredo) then raise exception 'não autorizado'; end if;
  select * into t from public.trabalhos where id = _id for update;
  if not found then raise exception 'trabalho não encontrado'; end if;
  if t.status <> 'processando' then
    return jsonb_build_object('ok', false, 'motivo', format('trabalho está "%s"', t.status));
  end if;
  update public.trabalhos set status = 'concluido', concluido_em = now(), resultado = coalesce(_resultado, '{}'), erro = null
   where id = _id returning * into t;

  perform privado.aplicar_resultado_agente(t, coalesce(_resultado, '{}'));

  if a is not null and jsonb_typeof(a) = 'object' then
    insert into public.aprovacoes (agente, tipo, trabalho_id, negocio_id, responsavel_id, titulo, resumo, conteudo, conteudo_original)
    values (t.agente, coalesce(a ->> 'tipo', t.tipo), t.id, t.negocio_id,
            coalesce((a ->> 'responsavel_id')::uuid, privado.destinatario_negocio(t.negocio_id, t.criado_por)),
            coalesce(a ->> 'titulo', 'Item para aprovar'), a ->> 'resumo',
            coalesce(a -> 'conteudo', '{}'), coalesce(a -> 'conteudo', '{}'));
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

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
