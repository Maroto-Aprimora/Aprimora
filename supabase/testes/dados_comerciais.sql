-- Monta, para o período :de a :ate, o mesmo objeto que carregarDadosComerciais() montava (para o cálculo antigo).
\set QUIET 1
\pset tuples_only on
\pset format unaligned
select json_build_object(
  'periodo', json_build_object('de', :'de', 'ate', :'ate'),
  'inicio', to_char((:'de'::date)::timestamp at time zone 'America/Sao_Paulo' at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.000"Z"'),
  'fim', to_char(((:'ate'::date) + 1)::timestamp at time zone 'America/Sao_Paulo' at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.000"Z"'),
  'config', json_build_object(
    'fases', (select json_agg(f order by f.ordem) from public.fases f where f.ativa and f.excluida_em is null),
    'origens', (select json_agg(o) from public.origens o where o.ativo)),
  'negocios', (select json_agg(json_build_object('id', n.id, 'titulo', n.titulo, 'created_at', n.created_at, 'fase_id', n.fase_id, 'valor', n.valor,
      'ganho_em', n.ganho_em, 'encerrado_em', n.encerrado_em, 'motivo_id', n.motivo_id, 'origem_id', n.origem_id, 'responsavel_id', n.responsavel_id,
      'empresas', json_build_object('nome', e.nome, 'cidade', e.cidade)) order by n.created_at)
    from public.negocios n join public.empresas e on e.id = n.empresa_id),
  'historico', (select json_agg(json_build_object('negocio_id', h.negocio_id, 'fase_destino_id', h.fase_destino_id, 'created_at', h.created_at)
    order by h.negocio_id, h.created_at, h.id) from public.negocio_historico h),
  'atividades', (select coalesce(json_agg(json_build_object('id', a.id, 'tipo_id', a.tipo_id, 'status', a.status, 'inicio', a.inicio,
      'responsavel_id', a.responsavel_id)), '[]') from public.atividades a
    where a.inicio >= (:'de'::date)::timestamp at time zone 'America/Sao_Paulo' and a.inicio < ((:'ate'::date) + 1)::timestamp at time zone 'America/Sao_Paulo'),
  'tipos', (select json_agg(json_build_object('id', id, 'chave', chave, 'nome', nome)) from public.tipos_atividade),
  'membros', (select json_agg(json_build_object('id', id, 'nome', nome, 'data_entrada', data_entrada)) from public.membros),
  'processos', (select coalesce(json_agg(json_build_object('data', data) order by data), '[]') from public.processos_seletivos),
  'motivos', (select json_agg(json_build_object('id', id, 'nome', nome, 'tipo', tipo)) from public.motivos)
);
