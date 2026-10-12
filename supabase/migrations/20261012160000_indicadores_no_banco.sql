-- =====================================================================
-- v2 · Fase 0 · PR 6 — Indicadores no banco (PE-PA-002, Seção 7)
-- - negocio_historico grava o responsável da época; o desempenho por membro usa esse campo
-- - indicadores_comerciais(): os mesmos números de src/lib/indicadores.ts, calculados no Postgres,
--   mais os novos (propostas remarcadas, ticket por solução, pipeline ponderado, % no SLA e destinos
--   de saída, motivos por fase e por membro, coldcall)
-- - valor_indicador_meta(): metas automáticas
-- Regra geral (igual à anterior): um negócio "chegou" a uma fase no período quando há registro de
-- entrada nela dentro do período, contando uma vez por fase.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Responsável da época em cada movimentação
-- ---------------------------------------------------------------------
alter table public.negocio_historico add column responsavel_id uuid references public.membros (id) on delete set null;
update public.negocio_historico h set responsavel_id = n.responsavel_id from public.negocios n where n.id = h.negocio_id;

create or replace function public.depois_de_salvar_negocio()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_auto uuid;
  v_flag text := coalesce(current_setting('aprimora.movimento_automatico', true), '');
  v_coment text := coalesce(current_setting('aprimora.comentario_movimento', true), '');
begin
  if tg_op = 'INSERT' or new.fase_id is distinct from old.fase_id then
    insert into public.negocio_historico (negocio_id, fase_origem_id, fase_destino_id, autor_id, automatico, motivo_id, comentario, responsavel_id)
    values (
      new.id,
      case when tg_op = 'UPDATE' then old.fase_id end,
      new.fase_id,
      (select auth.uid()),
      coalesce(current_setting('aprimora.movimento_automatico', true), '') <> '',
      new.motivo_id,
      nullif(current_setting('aprimora.comentario_movimento', true), ''),
      new.responsavel_id
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

-- ---------------------------------------------------------------------
-- Eventos do funil com o responsável da época (base dos indicadores)
-- ---------------------------------------------------------------------
-- Negócios do funil comercial com o responsável de cada marco:
--   lead     = primeiro responsável que o negócio teve (o rodízio só atribui em E-mail)
--   desfecho = responsável na última entrada na fase de ganho/perda atual
create or replace function privado.negocios_comerciais()
returns table (id uuid, created_at timestamptz, fase_id uuid, fase_chave text, valor numeric, ganho_em timestamptz,
               encerrado_em timestamptz, motivo_id uuid, origem_id uuid, cidade text, resp_lead uuid, resp_desfecho uuid,
               fase_saida_id uuid)
language sql stable security invoker set search_path = '' as $$
  select n.id, n.created_at, n.fase_id, f.chave, n.valor, n.ganho_em, n.encerrado_em, n.motivo_id, n.origem_id, e.cidade,
    coalesce((select h.responsavel_id from public.negocio_historico h
               where h.negocio_id = n.id and h.responsavel_id is not null order by h.created_at, h.id limit 1), n.responsavel_id),
    coalesce(d.responsavel_id, n.responsavel_id),
    d.fase_origem_id
  from public.negocios n
  join public.funis fu on fu.id = n.funil_id and fu.diretoria = 'comercial' and fu.chave = 'comercial'
  left join public.fases f on f.id = n.fase_id and f.ativa and f.excluida_em is null
  left join public.empresas e on e.id = n.empresa_id
  left join lateral (
    select h.responsavel_id, h.fase_origem_id from public.negocio_historico h
    where h.negocio_id = n.id and h.fase_destino_id = n.fase_id order by h.created_at desc, h.id desc limit 1
  ) d on n.encerrado_em is not null
$$;

-- Movimentações do funil comercial, com a próxima movimentação do mesmo negócio
create or replace function privado.historico_comercial()
returns table (negocio_id uuid, fase_destino_id uuid, created_at timestamptz, resp uuid, prox_em timestamptz, prox_fase uuid)
language sql stable security invoker set search_path = '' as $$
  select h.negocio_id, h.fase_destino_id, h.created_at, h.responsavel_id,
    lead(h.created_at) over w, lead(h.fase_destino_id) over w
  from public.negocio_historico h
  join public.negocios n on n.id = h.negocio_id
  join public.funis fu on fu.id = n.funil_id and fu.diretoria = 'comercial' and fu.chave = 'comercial'
  window w as (partition by h.negocio_id order by h.created_at, h.id)
$$;

-- ---------------------------------------------------------------------
-- Indicadores do período (dias de Brasília, inclusive). _responsavel filtra pelo responsável da época.
-- ---------------------------------------------------------------------
create or replace function public.indicadores_comerciais(_de date, _ate date, _responsavel uuid default null)
returns jsonb language sql stable security invoker set search_path = '' as $$
with
lim as (
  select (_de::timestamp at time zone 'America/Sao_Paulo') as ini, ((_ate + 1)::timestamp at time zone 'America/Sao_Paulo') as fim
),
fases as (
  select f.* from public.fases f join public.funis fu on fu.id = f.funil_id
  where fu.diretoria = 'comercial' and fu.chave = 'comercial' and f.ativa and f.excluida_em is null
),
neg as (select * from privado.negocios_comerciais()),
hist as (select * from privado.historico_comercial()),
-- Mesmo negócio pode entrar duas vezes com responsáveis diferentes: conta uma vez, pelo primeiro
entradas_unicas as (
  select distinct on (h.negocio_id, f.chave) h.negocio_id, f.chave, h.resp
  from hist h join fases f on f.id = h.fase_destino_id, lim
  where h.created_at >= lim.ini and h.created_at < lim.fim and (_responsavel is null or h.resp = _responsavel)
  order by h.negocio_id, f.chave, h.created_at
),
leads as (
  select n.* from neg n, lim where n.created_at >= lim.ini and n.created_at < lim.fim
    and (_responsavel is null or n.resp_lead = _responsavel)
),
ganhos as (
  select n.* from neg n, lim where n.ganho_em >= lim.ini and n.ganho_em < lim.fim
    and (_responsavel is null or n.resp_desfecho = _responsavel)
),
encerrados as (
  select n.* from neg n, lim where n.encerrado_em >= lim.ini and n.encerrado_em < lim.fim
    and n.fase_chave in ('nao_vendido', 'nao_qualificado') and (_responsavel is null or n.resp_desfecho = _responsavel)
),
contagem as (
  select
    (select count(*) from leads) as entrada,
    (select count(distinct negocio_id) from entradas_unicas where chave in ('email', 'coldcall_1')) as email,
    (select count(*) from entradas_unicas where chave = 'oportunidade') as oportunidade,
    (select count(*) from entradas_unicas where chave = 'diagnostico') as diagnostico,
    (select count(*) from entradas_unicas where chave = 'proposta') as proposta,
    (select count(*) from ganhos) as ganho,
    (select coalesce(sum(coalesce(valor, 0)), 0) from ganhos) as faturamento,
    (select count(*) from encerrados where fase_chave = 'nao_vendido') as perdidos,
    (select count(*) from encerrados where fase_chave = 'nao_qualificado') as desqualificados
),
etapas as (
  select e.ordem, e.chave, e.rotulo,
    case e.chave when 'entrada' then c.entrada when 'email' then c.email when 'oportunidade' then c.oportunidade
                 when 'diagnostico' then c.diagnostico when 'proposta' then c.proposta else c.ganho end as quantidade
  from contagem c, (values (1, 'entrada', 'Leads'), (2, 'email', 'Em cadência (e-mail/coldcall)'), (3, 'oportunidade', 'Oportunidade'),
    (4, 'diagnostico', 'Diagnóstico agendado'), (5, 'proposta', 'Proposta apresentada'), (6, 'ganho', 'Contrato fechado')) as e(ordem, chave, rotulo)
),
-- Permanência em cada fase: da entrada até a movimentação seguinte, para saídas no período
estadias as (
  select h.fase_destino_id as fase_id, extract(epoch from (h.prox_em - h.created_at)) / 86400.0 as dias, h.prox_fase
  from hist h, lim
  where h.prox_em >= lim.ini and h.prox_em < lim.fim and (_responsavel is null or h.resp = _responsavel)
),
atividades as (
  select a.*, t.nome as tipo_nome, t.chave as tipo_chave from public.atividades a
  left join public.tipos_atividade t on t.id = a.tipo_id, lim
  where a.inicio >= lim.ini and a.inicio < lim.fim and (_responsavel is null or a.responsavel_id = _responsavel)
),
ligacoes as (
  select l.*, r.nome as resultado, r.chave as resultado_chave from public.ligacoes l
  left join public.resultados_ligacao r on r.id = l.resultado_id, lim
  where l.inicio >= lim.ini and l.inicio < lim.fim and (_responsavel is null or l.membro_id = _responsavel)
),
-- Desempenho por pessoa (responsável da época de cada evento)
eventos_pessoa as (
  select resp_lead as pessoa, 1 as leads, 0 as diag, 0 as prop, 0 as contr, 0::numeric as fat, 0 as ativ, 0 as lig from leads
  union all select resp, 0, 1, 0, 0, 0, 0, 0 from entradas_unicas where chave = 'diagnostico'
  union all select resp, 0, 0, 1, 0, 0, 0, 0 from entradas_unicas where chave = 'proposta'
  union all select resp_desfecho, 0, 0, 0, 1, coalesce(valor, 0), 0, 0 from ganhos
  union all select responsavel_id, 0, 0, 0, 0, 0, 1, 0 from atividades where status = 'realizada'
  union all select membro_id, 0, 0, 0, 0, 0, 0, 1 from ligacoes
),
pessoas as (
  select e.pessoa, coalesce(m.nome, case when e.pessoa is null then 'Sem responsável' else '—' end) as nome,
    sum(leads) leads, sum(diag) diagnosticos, sum(prop) propostas, sum(contr) contratos, sum(fat) faturamento, sum(ativ) atividades, sum(lig) ligacoes
  from eventos_pessoa e left join public.membros m on m.id = e.pessoa
  group by e.pessoa, m.nome
),
origens as (
  select coalesce(o.nome, 'Sem origem') as origem, sum(x.leads) leads, sum(x.diag) diagnosticos, sum(x.contr) contratos, sum(x.fat) faturamento
  from (
    select origem_id, 1 leads, 0 diag, 0 contr, 0::numeric fat from leads
    union all select n.origem_id, 0, 1, 0, 0 from entradas_unicas e join neg n on n.id = e.negocio_id where e.chave = 'diagnostico'
    union all select origem_id, 0, 0, 1, coalesce(valor, 0) from ganhos
  ) x left join public.origens o on o.id = x.origem_id
  group by coalesce(o.nome, 'Sem origem')
),
motivos as (
  select e.fase_chave, coalesce(m.nome, 'Sem motivo') as motivo, coalesce(fs.nome, '—') as fase_saida,
    coalesce(mb.nome, 'Sem responsável') as membro
  from encerrados e left join public.motivos m on m.id = e.motivo_id
  left join public.fases fs on fs.id = e.fase_saida_id left join public.membros mb on mb.id = e.resp_desfecho
),
ticket_solucao as (
  select s.nome as servico, count(distinct g.id) as contratos, count(ns.valor) as com_valor, sum(ns.valor) as soma
  from ganhos g join public.negocio_servicos ns on ns.negocio_id = g.id join public.servicos s on s.id = ns.servico_id
  group by s.nome
),
pipeline as (
  select count(*) as ativos, coalesce(sum(coalesce(n.valor, 0) * coalesce(f.probabilidade, 0)), 0) as ponderado
  from public.negocios n
  join public.funis fu on fu.id = n.funil_id and fu.diretoria = 'comercial' and fu.chave = 'comercial'
  left join fases f on f.id = n.fase_id
  where n.encerrado_em is null and (_responsavel is null or n.responsavel_id = _responsavel)
)
select jsonb_build_object(
  'resumo', (select jsonb_build_object(
    'leadsNovos', c.entrada, 'oportunidades', c.oportunidade, 'diagnosticos', c.diagnostico, 'propostas', c.proposta,
    'contratos', c.ganho, 'faturamento', c.faturamento,
    'ticketMedio', case when c.ganho > 0 then c.faturamento / c.ganho end,
    'taxaGanho', case when c.ganho + c.perdidos > 0 then c.ganho::numeric / (c.ganho + c.perdidos) end,
    'conversaoLeadContrato', case when c.entrada > 0 then c.ganho::numeric / c.entrada end,
    'cicloDias', (select avg(extract(epoch from (ganho_em - created_at)) / 86400.0) from ganhos),
    'perdidos', c.perdidos, 'desqualificados', c.desqualificados,
    'propostasRemarcadas', (select count(*) from atividades where tipo_chave = 'apresentacao_proposta' and status = 'remarcada'),
    'pipelinePonderado', (select ponderado from pipeline), 'negociosAtivos', (select ativos from pipeline)
  ) from contagem c),
  'funil', (select jsonb_agg(jsonb_build_object('chave', e.chave, 'rotulo', e.rotulo, 'quantidade', e.quantidade,
      'conversao', case when e.ordem = 1 then null when a.quantidade > 0 then e.quantidade::numeric / a.quantidade end) order by e.ordem)
    from etapas e left join etapas a on a.ordem = e.ordem - 1),
  'tempoPorFase', (select coalesce(jsonb_agg(jsonb_build_object(
      'fase', f.nome, 'sla', f.sla_dias,
      'mediaDias', (select avg(dias) from estadias s where s.fase_id = f.id),
      'amostras', (select count(*) from estadias s where s.fase_id = f.id),
      'dentroSla', case when f.sla_dias is not null and exists (select 1 from estadias s where s.fase_id = f.id) then
        (select avg(case when s.dias <= f.sla_dias then 1.0 else 0.0 end) from estadias s where s.fase_id = f.id) end,
      'saidas', (select coalesce(jsonb_agg(jsonb_build_object('destino', d.nome, 'quantidade', d.qt) order by d.qt desc, d.nome), '[]'::jsonb)
                 from (select coalesce(fd.nome, '—') nome, count(*) qt from estadias s left join public.fases fd on fd.id = s.prox_fase
                       where s.fase_id = f.id group by fd.nome) d)
    ) order by f.ordem), '[]'::jsonb) from fases f where f.tipo = 'aberta' and f.chave <> 'entrada'),
  'pessoas', (select coalesce(jsonb_agg(jsonb_build_object(
      'id', coalesce(p.pessoa::text, 'sem'), 'nome', p.nome, 'leads', p.leads, 'diagnosticos', p.diagnosticos, 'propostas', p.propostas,
      'contratos', p.contratos, 'faturamento', p.faturamento, 'atividades', p.atividades, 'ligacoes', p.ligacoes)
    order by p.faturamento desc, p.contratos desc, p.diagnosticos desc, p.nome), '[]'::jsonb) from pessoas p),
  'origens', (select coalesce(jsonb_agg(jsonb_build_object('origem', o.origem, 'leads', o.leads, 'diagnosticos', o.diagnosticos,
      'contratos', o.contratos, 'faturamento', o.faturamento) order by o.leads desc, o.origem), '[]'::jsonb) from origens o),
  'motivosPerda', (select coalesce(jsonb_agg(jsonb_build_object('motivo', x.motivo, 'quantidade', x.qt) order by x.qt desc, x.motivo), '[]'::jsonb)
    from (select motivo, count(*) qt from motivos where fase_chave = 'nao_vendido' group by motivo) x),
  'motivosDesqualificacao', (select coalesce(jsonb_agg(jsonb_build_object('motivo', x.motivo, 'quantidade', x.qt) order by x.qt desc, x.motivo), '[]'::jsonb)
    from (select motivo, count(*) qt from motivos where fase_chave = 'nao_qualificado' group by motivo) x),
  'motivosPorFase', (select coalesce(jsonb_agg(jsonb_build_object('tipo', x.fase_chave, 'fase', x.fase_saida, 'motivo', x.motivo, 'quantidade', x.qt)
      order by x.qt desc, x.fase_saida, x.motivo), '[]'::jsonb)
    from (select fase_chave, fase_saida, motivo, count(*) qt from motivos group by 1, 2, 3) x),
  'motivosPorMembro', (select coalesce(jsonb_agg(jsonb_build_object('membro', x.membro, 'motivo', x.motivo, 'quantidade', x.qt)
      order by x.membro, x.qt desc, x.motivo), '[]'::jsonb)
    from (select membro, motivo, count(*) qt from motivos group by 1, 2) x),
  'atividadesPorTipo', (select coalesce(jsonb_agg(jsonb_build_object('tipo', x.tipo, 'realizadas', x.realizadas, 'agendadas', x.agendadas,
      'canceladas', x.canceladas) order by x.realizadas desc, x.tipo), '[]'::jsonb)
    from (select coalesce(tipo_nome, 'Outro') tipo, count(*) filter (where status = 'realizada') realizadas,
            count(*) filter (where status in ('pendente', 'confirmada')) agendadas, count(*) filter (where status = 'cancelada') canceladas
          from atividades where status <> 'remarcada' group by 1) x),
  'ticketPorSolucao', (select coalesce(jsonb_agg(jsonb_build_object('servico', t.servico, 'contratos', t.contratos, 'comValor', t.com_valor,
      'soma', t.soma, 'ticket', case when t.com_valor > 0 then t.soma / t.com_valor end) order by t.soma desc nulls last, t.servico), '[]'::jsonb)
    from ticket_solucao t),
  'coldcall', jsonb_build_object(
    'ligacoes', (select count(*) from ligacoes),
    'negocios', (select count(distinct negocio_id) from ligacoes),
    'diagnosticos', (select count(*) from ligacoes where resultado_chave = 'diagnostico_agendado'),
    'pctDiagnostico', (select case when count(*) > 0 then count(*) filter (where resultado_chave = 'diagnostico_agendado')::numeric / count(*) end from ligacoes),
    'duracaoMediaMin', (select avg(duracao_seg) / 60.0 from ligacoes where duracao_seg is not null),
    'notaMedia', null,
    'porResultado', (select coalesce(jsonb_agg(jsonb_build_object('resultado', x.resultado, 'quantidade', x.qt, 'pct', x.qt::numeric / x.total)
        order by x.qt desc, x.resultado), '[]'::jsonb)
      from (select coalesce(resultado, 'Aguardando resultado') resultado, count(*) qt, sum(count(*)) over () total from ligacoes group by 1) x)
  )
)
$$;
grant execute on function public.indicadores_comerciais(date, date, uuid) to authenticated;
revoke all on function public.indicadores_comerciais(date, date, uuid) from anon;

-- ---------------------------------------------------------------------
-- Metas automáticas (catálogo em src/lib/indicadores-catalogo.ts)
-- ---------------------------------------------------------------------
create or replace function public.valor_indicador_meta(_chave text, _de date, _ate date, _membro uuid default null)
returns numeric language sql stable security invoker set search_path = '' as $$
with
lim as (
  select (_de::timestamp at time zone 'America/Sao_Paulo') as ini, ((_ate + 1)::timestamp at time zone 'America/Sao_Paulo') as fim
),
neg as (select * from privado.negocios_comerciais()),
entraram as (
  select distinct on (h.negocio_id, f.chave) h.negocio_id, f.chave, h.resp
  from privado.historico_comercial() h join public.fases f on f.id = h.fase_destino_id and f.ativa and f.excluida_em is null, lim
  where h.created_at >= lim.ini and h.created_at < lim.fim and (_membro is null or h.resp = _membro)
  order by h.negocio_id, f.chave, h.created_at
),
ganhos as (
  select n.* from neg n, lim where n.ganho_em >= lim.ini and n.ganho_em < lim.fim and (_membro is null or n.resp_desfecho = _membro)
),
ativ as (
  select a.status, t.chave from public.atividades a join public.tipos_atividade t on t.id = a.tipo_id, lim
  where a.inicio >= lim.ini and a.inicio < lim.fim and (_membro is null or a.responsavel_id = _membro)
),
ultimo_processo as (select max(data) as data from public.processos_seletivos where data <= _ate)
select case _chave
  when 'faturamento' then (select coalesce(sum(coalesce(valor, 0)), 0) from ganhos)
  when 'contratos' then (select count(*) from ganhos)
  when 'propostas' then (select count(*) from entraram where chave = 'proposta')
  when 'diagnosticos' then (select count(*) from entraram where chave = 'diagnostico')
  when 'oportunidades' then (select count(*) from entraram where chave = 'oportunidade')
  when 'diagnosticos_fora_londrina' then (select count(*) from entraram e join neg n on n.id = e.negocio_id
    where e.chave = 'diagnostico' and nullif(n.cidade, '') is not null and trim(public.normalizar(n.cidade)) <> 'londrina')
  when 'diagnosticos_pos_venda' then (select count(*) from entraram e join neg n on n.id = e.negocio_id join public.origens o on o.id = n.origem_id
    where e.chave = 'diagnostico' and (trim(public.normalizar(o.nome)) like 'pos-venda%' or trim(public.normalizar(o.nome)) like 'pos venda%'))
  when 'diagnosticos_membros_novos' then (select count(*) from entraram e join public.membros m on m.id = e.resp, ultimo_processo u
    where e.chave = 'diagnostico' and u.data is not null and m.data_entrada >= u.data)
  when 'leads_novos' then (select count(*) from neg n, lim where n.created_at >= lim.ini and n.created_at < lim.fim
    and (_membro is null or n.resp_lead = _membro))
  when 'prospectday' then (select count(*) from ativ where chave = 'prospectday' and status not in ('cancelada', 'remarcada'))
  when 'coldcalls' then (select count(*) from ativ where chave = 'coldcall' and status = 'realizada')
end
$$;
grant execute on function public.valor_indicador_meta(text, date, date, uuid) to authenticated;
revoke all on function public.valor_indicador_meta(text, date, date, uuid) from anon;
