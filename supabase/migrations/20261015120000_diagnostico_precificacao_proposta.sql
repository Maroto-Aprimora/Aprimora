-- =====================================================================
-- v2 · Fase 4 — Da oportunidade à venda (PE-PA-002, Seções 5 e 5.2)
-- - Diagnóstico digital: 10 áreas com perguntas (nota 1 a 4 + comentário), editáveis pelo diretor. Ao concluir, a média
--   por área vira o mapa de maturidade e o A9 Assistente de proposta entra na fila.
-- - A9: resumo do diagnóstico, serviços sugeridos, rascunho de escopo e de proposta (o responsável revisa).
-- - Precificação: fatores multiplicativos, horas de consultores e gerentes, custos, margens e imposto (parâmetros do
--   diretor). O banco calcula o preço mínimo e o máximo; só o diretor comercial registra o preço final, que vira o
--   valor do negócio.
-- - A10 Passagem para Projetos: card em Projetos Aprimora → tarefa e aviso para a Diretoria de Projetos com o dossiê.
-- - O A8 Agendador segue desligado (decisão de 13/10/2026).
-- =====================================================================

-- ---------------------------------------------------------------------
-- Diagnóstico
-- ---------------------------------------------------------------------
create table public.diagnostico_areas (
  id uuid primary key default gen_random_uuid(),
  chave text not null unique,
  nome text not null,
  servico_id uuid references public.servicos (id) on delete set null,   -- serviço da Carta que resolve a área
  ordem integer not null default 0,
  ativo boolean not null default true
);
create table public.diagnostico_perguntas (
  id uuid primary key default gen_random_uuid(),
  area_id uuid not null references public.diagnostico_areas (id) on delete cascade,
  texto text not null,
  ordem integer not null default 0,
  ativo boolean not null default true
);
create index diagnostico_perguntas_area_idx on public.diagnostico_perguntas (area_id, ordem);

create table public.diagnosticos (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios (id) on delete cascade,
  realizado_em date not null default privado.hoje(),
  respostas jsonb not null default '{}',      -- { pergunta_id: { "nota": 1..4, "comentario": "..." } }
  observacoes text,
  status text not null default 'rascunho' check (status in ('rascunho', 'concluido')),
  maturidade jsonb,                            -- [{ area_id, chave, nome, media, respondidas, total }] ao concluir
  concluido_em timestamptz,
  concluido_por uuid references public.membros (id) on delete set null,
  analise_status text check (analise_status in ('gerando', 'pronto', 'erro')),
  analise_erro text,
  trabalho_id uuid references public.trabalhos (id) on delete set null,
  criado_por uuid references public.membros (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index diagnosticos_negocio_idx on public.diagnosticos (negocio_id, created_at desc);
create trigger diagnosticos_updated_at before update on public.diagnosticos for each row execute function public.tocar_updated_at();

-- ---------------------------------------------------------------------
-- Proposta (A9 + revisão do responsável)
-- ---------------------------------------------------------------------
create table public.propostas (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null unique references public.negocios (id) on delete cascade,
  diagnostico_id uuid references public.diagnosticos (id) on delete set null,
  resumo_diagnostico text,
  servicos_sugeridos jsonb not null default '[]',   -- [{ servico_id, nome, motivo }]
  escopo text,
  texto text,
  status text not null default 'rascunho' check (status in ('rascunho', 'revisada')),
  gerado_em timestamptz,
  revisado_por uuid references public.membros (id) on delete set null,
  revisado_em timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger propostas_updated_at before update on public.propostas for each row execute function public.tocar_updated_at();

-- ---------------------------------------------------------------------
-- Precificação
-- ---------------------------------------------------------------------
create table public.parametros_precificacao (
  diretoria text primary key references public.diretorias (slug),
  valor_hora_consultor numeric(10,2) not null default 25 check (valor_hora_consultor >= 0),
  valor_hora_gerente numeric(10,2) not null default 40 check (valor_hora_gerente >= 0),
  margem_minima numeric(5,4) not null default 0.20 check (margem_minima >= 0),
  margem_maxima numeric(5,4) not null default 0.50 check (margem_maxima >= 0),
  imposto numeric(5,4) not null default 0.06 check (imposto >= 0 and imposto < 1),
  -- [{ chave, nome, opcoes: [{ rotulo, multiplicador }] }]; a primeira opção é a padrão
  fatores jsonb not null default '[]',
  updated_at timestamptz not null default now()
);
insert into public.parametros_precificacao (diretoria, fatores) values ('comercial', '[
  {"chave":"cliente_recorrente","nome":"Cliente recorrente","opcoes":[{"rotulo":"Não","multiplicador":1},{"rotulo":"Sim","multiplicador":0.9}]},
  {"chave":"prazo","nome":"Prazo","opcoes":[{"rotulo":"Normal","multiplicador":1},{"rotulo":"Curto","multiplicador":1.15},{"rotulo":"Urgente","multiplicador":1.3}]},
  {"chave":"concorrencia","nome":"Concorrência","opcoes":[{"rotulo":"Sem concorrência","multiplicador":1.05},{"rotulo":"Com concorrência","multiplicador":0.95}]},
  {"chave":"fora_do_padrao","nome":"Entregas fora do padrão","opcoes":[{"rotulo":"Não","multiplicador":1},{"rotulo":"Sim","multiplicador":1.15}]},
  {"chave":"complexidade","nome":"Complexidade","opcoes":[{"rotulo":"Média","multiplicador":1},{"rotulo":"Baixa","multiplicador":0.9},{"rotulo":"Alta","multiplicador":1.2}]},
  {"chave":"porte","nome":"Porte do cliente","opcoes":[{"rotulo":"Pequena","multiplicador":1},{"rotulo":"Micro","multiplicador":0.85},{"rotulo":"Média","multiplicador":1.15},{"rotulo":"Grande","multiplicador":1.3}]},
  {"chave":"capacidade","nome":"Capacidade operacional da Aprimora","opcoes":[{"rotulo":"Normal","multiplicador":1},{"rotulo":"Folgada","multiplicador":0.95},{"rotulo":"Apertada","multiplicador":1.1}]}
]');

create table public.precificacoes (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null unique references public.negocios (id) on delete cascade,
  fatores jsonb not null default '{}',              -- { chave_do_fator: rotulo_escolhido }
  horas_consultor numeric(10,2) not null default 0 check (horas_consultor >= 0),
  horas_gerente numeric(10,2) not null default 0 check (horas_gerente >= 0),
  custos jsonb not null default '[]',               -- [{ descricao, valor }]
  multiplicador numeric(10,4),
  custo_base numeric(12,2),
  preco_minimo numeric(12,2),
  preco_maximo numeric(12,2),
  preco_final numeric(12,2) check (preco_final is null or preco_final >= 0),
  definido_por uuid references public.membros (id) on delete set null,
  definido_em timestamptz,
  observacoes text,
  atualizado_por uuid references public.membros (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger precificacoes_updated_at before update on public.precificacoes for each row execute function public.tocar_updated_at();

-- Calcula o preço com os parâmetros do diretor (a tela repete a conta só para mostrar ao vivo)
--   custo base = horas consultor × valor/h + horas gerente × valor/h + custos do projeto
--   multiplicador = produto dos fatores escolhidos
--   preço mínimo = custo base × multiplicador × (1 + margem mínima) ÷ (1 − imposto); máximo com a margem máxima
create or replace function public.calcular_precificacao()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  p public.parametros_precificacao%rowtype;
  f jsonb;
  v_escolha text;
  v_mult numeric := 1;
  v_custos numeric := 0;
  v_base numeric;
begin
  select * into p from public.parametros_precificacao where diretoria = 'comercial';
  for f in select * from jsonb_array_elements(p.fatores) loop
    v_escolha := new.fatores ->> (f ->> 'chave');
    v_mult := v_mult * coalesce(
      (select (o ->> 'multiplicador')::numeric from jsonb_array_elements(f -> 'opcoes') o where o ->> 'rotulo' = v_escolha limit 1),
      (f -> 'opcoes' -> 0 ->> 'multiplicador')::numeric, 1);
  end loop;
  select coalesce(sum(nullif(c ->> 'valor', '')::numeric), 0) into v_custos from jsonb_array_elements(new.custos) c;
  v_base := new.horas_consultor * p.valor_hora_consultor + new.horas_gerente * p.valor_hora_gerente + v_custos;
  new.multiplicador := round(v_mult, 4);
  new.custo_base := round(v_base, 2);
  new.preco_minimo := round(v_base * v_mult * (1 + p.margem_minima) / (1 - p.imposto), 2);
  new.preco_maximo := round(v_base * v_mult * (1 + p.margem_maxima) / (1 - p.imposto), 2);
  -- Preço final: só o diretor comercial registra
  if new.preco_final is distinct from (case when tg_op = 'UPDATE' then old.preco_final end) then
    if (select auth.uid()) is not null and not privado.eh_diretor_de('comercial') then
      raise exception 'Só o Diretor Comercial registra o preço final';
    end if;
    new.definido_por := case when new.preco_final is null then null else (select auth.uid()) end;
    new.definido_em := case when new.preco_final is null then null else now() end;
  end if;
  new.atualizado_por := coalesce((select auth.uid()), new.atualizado_por);
  return new;
end;
$$;
create trigger calcular_precificacao before insert or update on public.precificacoes
  for each row execute function public.calcular_precificacao();

-- Preço final registrado vira o valor do negócio
create or replace function public.preco_final_no_negocio()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.preco_final is not null and new.preco_final is distinct from (case when tg_op = 'UPDATE' then old.preco_final end) then
    update public.negocios set valor = new.preco_final where id = new.negocio_id;
  end if;
  return null;
end;
$$;
create trigger preco_final_no_negocio after insert or update of preco_final on public.precificacoes
  for each row execute function public.preco_final_no_negocio();
revoke all on function public.calcular_precificacao(), public.preco_final_no_negocio() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------
alter table public.diagnostico_areas enable row level security;
alter table public.diagnostico_perguntas enable row level security;
alter table public.diagnosticos enable row level security;
alter table public.propostas enable row level security;
alter table public.parametros_precificacao enable row level security;
alter table public.precificacoes enable row level security;

create policy diag_areas_ler on public.diagnostico_areas for select to authenticated using ((select privado.membro_ativo()));
create policy diag_areas_gerir on public.diagnostico_areas for all to authenticated
  using (privado.eh_diretor_de('comercial')) with check (privado.eh_diretor_de('comercial'));
create policy diag_perguntas_ler on public.diagnostico_perguntas for select to authenticated using ((select privado.membro_ativo()));
create policy diag_perguntas_gerir on public.diagnostico_perguntas for all to authenticated
  using (privado.eh_diretor_de('comercial')) with check (privado.eh_diretor_de('comercial'));

create policy diagnosticos_ler on public.diagnosticos for select to authenticated using ((select privado.membro_ativo()));
create policy diagnosticos_criar on public.diagnosticos for insert to authenticated with check (privado.pode_editar_negocio(negocio_id));
create policy diagnosticos_editar on public.diagnosticos for update to authenticated
  using (privado.pode_editar_negocio(negocio_id)) with check (privado.pode_editar_negocio(negocio_id));
create policy diagnosticos_excluir on public.diagnosticos for delete to authenticated using (privado.eh_diretor_de('comercial'));

create policy propostas_ler on public.propostas for select to authenticated using ((select privado.membro_ativo()));
create policy propostas_criar on public.propostas for insert to authenticated with check (privado.pode_editar_negocio(negocio_id));
create policy propostas_editar on public.propostas for update to authenticated
  using (privado.pode_editar_negocio(negocio_id)) with check (privado.pode_editar_negocio(negocio_id));

create policy param_preco_ler on public.parametros_precificacao for select to authenticated using ((select privado.membro_ativo()));
create policy param_preco_editar on public.parametros_precificacao for update to authenticated
  using (privado.eh_diretor_de('comercial')) with check (privado.eh_diretor_de('comercial'));

create policy precificacoes_ler on public.precificacoes for select to authenticated using ((select privado.membro_ativo()));
create policy precificacoes_criar on public.precificacoes for insert to authenticated with check (privado.pode_editar_negocio(negocio_id));
create policy precificacoes_editar on public.precificacoes for update to authenticated
  using (privado.pode_editar_negocio(negocio_id)) with check (privado.pode_editar_negocio(negocio_id));

revoke all on public.diagnostico_areas, public.diagnostico_perguntas, public.diagnosticos, public.propostas,
  public.parametros_precificacao, public.precificacoes from anon;
-- Colunas preenchidas só pelo banco
revoke update on public.diagnosticos from authenticated;
grant update (respostas, observacoes, realizado_em) on public.diagnosticos to authenticated;
revoke update on public.propostas from authenticated;
grant update (escopo, texto, resumo_diagnostico, status, revisado_por, revisado_em) on public.propostas to authenticated;

-- ---------------------------------------------------------------------
-- Concluir o diagnóstico: mapa de maturidade + fila do A9
-- ---------------------------------------------------------------------
create or replace function public.concluir_diagnostico(_diagnostico uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  d public.diagnosticos%rowtype;
  n public.negocios%rowtype;
  v_mat jsonb;
  v_trab uuid;
begin
  select * into d from public.diagnosticos where id = _diagnostico for update;
  if not found then raise exception 'Diagnóstico não encontrado'; end if;
  if not privado.pode_editar_negocio(d.negocio_id) then raise exception 'Sem permissão'; end if;
  select coalesce(jsonb_agg(x order by x ->> 'ordem'), '[]') into v_mat from (
    select jsonb_build_object('area_id', a.id, 'chave', a.chave, 'nome', a.nome, 'ordem', lpad(a.ordem::text, 4, '0'),
      'servico_id', a.servico_id,
      'media', round(avg((d.respostas -> p.id::text ->> 'nota')::numeric) filter (where (d.respostas -> p.id::text ->> 'nota') ~ '^[1-4]$'), 2),
      'respondidas', count(*) filter (where (d.respostas -> p.id::text ->> 'nota') ~ '^[1-4]$'),
      'total', count(p.id)) x
    from public.diagnostico_areas a join public.diagnostico_perguntas p on p.area_id = a.id and p.ativo
    where a.ativo group by a.id) s;
  if not exists (select 1 from jsonb_array_elements(v_mat) m where (m ->> 'respondidas')::int > 0) then
    raise exception 'Responda ao menos uma pergunta antes de concluir';
  end if;
  update public.diagnosticos set status = 'concluido', maturidade = v_mat, concluido_em = now(), concluido_por = (select auth.uid())
   where id = d.id;
  select * into n from public.negocios where id = d.negocio_id;
  v_trab := privado.enfileirar('assistente_proposta', 'analisar_diagnostico', jsonb_build_object(
    'diagnostico_id', d.id, 'negocio_id', n.id,
    'empresa', (select jsonb_build_object('nome', e.nome, 'cidade', e.cidade, 'porte', e.porte,
                  'segmento', (select s.nome from public.segmentos s where s.id = e.segmento_id), 'resumo', e.enriquecimento ->> 'resumo')
                from public.empresas e where e.id = n.empresa_id),
    'dores', coalesce(n.dores_identificadas, ''),
    'dores_marcadas', (select coalesce(jsonb_agg(s.nome), '[]') from public.negocio_servicos ns join public.servicos s on s.id = ns.servico_id where ns.negocio_id = n.id),
    'servicos', (select jsonb_agg(jsonb_build_object('id', s.id, 'nome', s.nome) order by s.ordem) from public.servicos s where s.ativo and s.diretoria = 'comercial'),
    'maturidade', v_mat,
    'respostas', (select coalesce(jsonb_agg(jsonb_build_object('area', a.nome, 'pergunta', p.texto,
                    'nota', d.respostas -> p.id::text ->> 'nota', 'comentario', d.respostas -> p.id::text ->> 'comentario') order by a.ordem, p.ordem), '[]')
                  from public.diagnostico_perguntas p join public.diagnostico_areas a on a.id = p.area_id
                  where p.ativo and a.ativo and d.respostas ? p.id::text),
    'observacoes', coalesce(d.observacoes, ''),
    'ligacoes', coalesce((select jsonb_agg(coalesce(l.resumo, l.comentario)) from public.ligacoes l
                  where l.negocio_id = n.id and coalesce(l.resumo, l.comentario) is not null), '[]'),
    'hoje', privado.hoje()
  ), n.id, 'analisar:' || d.id || ':' || extract(epoch from now())::bigint);
  update public.diagnosticos set analise_status = case when v_trab is null then null else 'gerando' end, analise_erro = null,
    trabalho_id = v_trab where id = d.id;
  return jsonb_build_object('ok', true, 'assistente', v_trab is not null);
end;
$$;
revoke all on function public.concluir_diagnostico(uuid) from public, anon;
grant execute on function public.concluir_diagnostico(uuid) to authenticated;

-- Reabrir para corrigir (volta a rascunho; a proposta já revisada não é tocada)
create or replace function public.reabrir_diagnostico(_diagnostico uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.diagnosticos d where d.id = _diagnostico and privado.pode_editar_negocio(d.negocio_id)) then
    raise exception 'Sem permissão';
  end if;
  update public.diagnosticos set status = 'rascunho' where id = _diagnostico;
end;
$$;
revoke all on function public.reabrir_diagnostico(uuid) from public, anon;
grant execute on function public.reabrir_diagnostico(uuid) to authenticated;

-- A9: resultado do n8n
create or replace function privado.aplicar_proposta(t public.trabalhos, r jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_diag uuid := (t.payload ->> 'diagnostico_id')::uuid;
  v_neg uuid := (t.payload ->> 'negocio_id')::uuid;
  v_sug jsonb;
  v_empresa text;
begin
  select coalesce(jsonb_agg(jsonb_build_object('servico_id', s.id, 'nome', s.nome, 'motivo', x ->> 'motivo')), '[]') into v_sug
  from jsonb_array_elements(coalesce(r -> 'servicos_sugeridos', '[]')) x
  join public.servicos s on s.id::text = x ->> 'servico_id' or lower(s.nome) = lower(x ->> 'nome');
  insert into public.propostas (negocio_id, diagnostico_id, resumo_diagnostico, servicos_sugeridos, escopo, texto, gerado_em)
  values (v_neg, v_diag, r ->> 'resumo', v_sug, r ->> 'escopo', r ->> 'proposta', now())
  on conflict (negocio_id) do update set
    diagnostico_id = excluded.diagnostico_id, resumo_diagnostico = excluded.resumo_diagnostico,
    servicos_sugeridos = excluded.servicos_sugeridos, gerado_em = now(),
    escopo = case when public.propostas.status = 'rascunho' then excluded.escopo else public.propostas.escopo end,
    texto = case when public.propostas.status = 'rascunho' then excluded.texto else public.propostas.texto end;
  update public.diagnosticos set analise_status = 'pronto', analise_erro = null where id = v_diag;
  select e.nome into v_empresa from public.negocios n join public.empresas e on e.id = n.empresa_id where n.id = v_neg;
  perform privado.notificar(privado.destinatario_negocio(v_neg, null), 'proposta_pronta', 'Rascunho de proposta pronto',
    coalesce(v_empresa, 'Lead') || ': resumo do diagnóstico, serviços sugeridos, escopo e proposta para revisar.',
    '/negocios/' || v_neg || '/proposta', 'proposta:' || t.id);
end;
$$;

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
    when 'assistente_proposta' then perform privado.aplicar_proposta(t, r);
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
    elsif t.agente = 'assistente_proposta' then
      update public.diagnosticos set analise_status = 'erro', analise_erro = v_msg where id = (t.payload ->> 'diagnostico_id')::uuid;
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
-- A10 · Passagem para Projetos (regra, sem IA)
-- ---------------------------------------------------------------------
create or replace function public.passagem_para_projetos()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  n public.negocios%rowtype;
  v_empresa text;
  v_destino uuid;
  v_texto text;
begin
  if not exists (select 1 from public.fases f where f.id = new.fase_destino_id and f.tipo = 'ganho') then return null; end if;
  if not exists (select 1 from public.agentes where chave = 'passagem' and ativo) then return null; end if;
  select * into n from public.negocios where id = new.negocio_id;
  select nome into v_empresa from public.empresas where id = n.empresa_id;
  v_texto := format('Projeto vendido: %s%s. O dossiê com dados, contatos, ligações, diagnóstico, precificação, proposta e anexos está em /negocios/%s/dossie.',
    coalesce(v_empresa, n.titulo), case when n.valor is not null then ' · R$ ' || to_char(n.valor, 'FM999G999G990D00') else '' end, n.id);
  -- Diretoria de Projetos; sem ninguém lá, o diretor comercial recebe
  for v_destino in
    select md.membro_id from public.membro_diretorias md join public.membros m on m.id = md.membro_id and m.ativo
     where md.diretoria = 'projetos' and md.cargo = 'diretor'
    union
    select md.membro_id from public.membro_diretorias md join public.membros m on m.id = md.membro_id and m.ativo
     where md.diretoria = 'comercial' and md.cargo = 'diretor'
       and not exists (select 1 from public.membro_diretorias x where x.diretoria = 'projetos' and x.cargo = 'diretor')
  loop
    perform privado.criar_tarefa(v_destino, 'Receber projeto · ' || coalesce(v_empresa, n.titulo), privado.dia_util(privado.hoje() + 1),
      n.id, format('passagem:%s:%s', n.id, v_destino), v_texto, 'agente', null, 'alta');
  end loop;
  perform privado.notificar(n.responsavel_id, 'passagem', 'Passagem para Projetos', v_texto, '/negocios/' || n.id || '/dossie',
    'passagem:' || n.id);
  return null;
end;
$$;
create trigger passagem_para_projetos after insert on public.negocio_historico
  for each row execute function public.passagem_para_projetos();
revoke all on function public.passagem_para_projetos() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- Áreas e perguntas iniciais (o diretor edita em Config. do funil → Diagnóstico)
-- ---------------------------------------------------------------------
insert into public.diagnostico_areas (chave, nome, servico_id, ordem)
select x.chave, x.nome, (select s.id from public.servicos s where s.diretoria = 'comercial' and s.nome = x.servico), x.ordem
from (values
  ('processos', 'Mapeamento de processos', 'Mapeamento de Processos', 1),
  ('mercado', 'Pesquisa de mercado', 'Pesquisa de Mercado', 2),
  ('custos', 'Gestão de custos', 'Gestão de Custos', 3),
  ('estrategia', 'Planejamento estratégico', 'Planejamento Estratégico', 4),
  ('cronoanalise', 'Cronoanálise', 'Cronoanálise', 5),
  ('estoque', 'Gestão de estoque', 'Gestão de Estoque', 6),
  ('layout', 'Layout e arranjo físico', 'Análise de Layout e Arranjo Físico', 7),
  ('pcp', 'Planejamento e controle da produção (PCP)', 'Planejamento e Controle da Produção (PCP)', 8),
  ('desperdicio', 'Desperdício', 'Gestão de Desperdício', 9),
  ('5s', '5S', 'Aplicação do 5S', 10)
) as x(chave, nome, servico, ordem);

insert into public.diagnostico_perguntas (area_id, texto, ordem)
select a.id, x.texto, x.ordem
from (values
  ('processos', 'Os principais processos estão desenhados (fluxograma ou instrução de trabalho)?', 1),
  ('processos', 'Cada etapa tem responsável definido e todos sabem o que fazer?', 2),
  ('processos', 'O trabalho é feito do mesmo jeito por pessoas e turnos diferentes?', 3),
  ('processos', 'Retrabalho e gargalos são identificados e tratados?', 4),
  ('processos', 'Há indicadores de desempenho dos processos (prazo, qualidade, produtividade)?', 5),
  ('mercado', 'A empresa conhece bem seu público-alvo e por que os clientes compram dela?', 1),
  ('mercado', 'Acompanha preços e diferenciais dos concorrentes?', 2),
  ('mercado', 'Mede a satisfação dos clientes?', 3),
  ('mercado', 'Tem dados sobre o tamanho e o potencial do mercado onde atua?', 4),
  ('mercado', 'Decide novos produtos ou mercados com base em informação, e não só intuição?', 5),
  ('custos', 'Sabe o custo de cada produto ou serviço?', 1),
  ('custos', 'Separa custos fixos e variáveis?', 2),
  ('custos', 'O preço de venda é formado a partir dos custos e da margem desejada?', 3),
  ('custos', 'Tem controle de fluxo de caixa atualizado?', 4),
  ('custos', 'Acompanha a margem de contribuição por produto ou cliente?', 5),
  ('estrategia', 'Missão, visão e objetivos estão definidos e são conhecidos pela equipe?', 1),
  ('estrategia', 'Há metas anuais com responsáveis e prazos?', 2),
  ('estrategia', 'Os resultados são acompanhados com indicadores periodicamente?', 3),
  ('estrategia', 'Já foi feita uma análise de forças, fraquezas, oportunidades e ameaças?', 4),
  ('estrategia', 'As decisões de investimento seguem um plano?', 5),
  ('cronoanalise', 'Os tempos padrão das operações são conhecidos?', 1),
  ('cronoanalise', 'A capacidade produtiva (peças ou serviços por hora) é medida?', 2),
  ('cronoanalise', 'Os prazos prometidos aos clientes se baseiam em tempos medidos?', 3),
  ('cronoanalise', 'A produtividade por posto ou operador é acompanhada?', 4),
  ('cronoanalise', 'Paradas e tempos improdutivos são registrados?', 5),
  ('estoque', 'O estoque é controlado em sistema ou planilha atualizada?', 1),
  ('estoque', 'Há inventário periódico e as diferenças são baixas?', 2),
  ('estoque', 'Existem estoque mínimo e ponto de pedido definidos?', 3),
  ('estoque', 'Falta de material raramente para a produção?', 4),
  ('estoque', 'Itens parados ou obsoletos são identificados e tratados?', 5),
  ('layout', 'O fluxo de materiais segue a sequência do processo, sem idas e vindas?', 1),
  ('layout', 'As distâncias percorridas por pessoas e materiais são pequenas?', 2),
  ('layout', 'Há espaço adequado e organizado para cada posto de trabalho?', 3),
  ('layout', 'O arranjo permite crescer a produção sem grandes reformas?', 4),
  ('layout', 'Segurança e ergonomia foram consideradas no arranjo?', 5),
  ('pcp', 'Existe um programa de produção semanal ou diário?', 1),
  ('pcp', 'A carga de trabalho é comparada com a capacidade antes de aceitar pedidos?', 2),
  ('pcp', 'Os pedidos saem no prazo combinado?', 3),
  ('pcp', 'O andamento das ordens de produção é acompanhado?', 4),
  ('pcp', 'Compras e produção são planejadas juntas?', 5),
  ('desperdicio', 'Perdas de material e refugo são medidas?', 1),
  ('desperdicio', 'Esperas, movimentações e transportes desnecessários são raros?', 2),
  ('desperdicio', 'A produção segue a demanda, sem superprodução nem estoque em processo acumulado?', 3),
  ('desperdicio', 'Defeitos são analisados para não se repetirem?', 4),
  ('desperdicio', 'A equipe sugere melhorias e elas são implantadas?', 5),
  ('5s', 'Só fica no posto o que é necessário para o trabalho (utilização)?', 1),
  ('5s', 'Cada ferramenta e material tem lugar definido e identificado (ordenação)?', 2),
  ('5s', 'O ambiente é limpo e a limpeza tem rotina (limpeza)?', 3),
  ('5s', 'Há padrões visuais e regras de organização (padronização)?', 4),
  ('5s', 'Os padrões são mantidos sem cobrança constante (disciplina)?', 5)
) as x(chave, texto, ordem) join public.diagnostico_areas a on a.chave = x.chave;
