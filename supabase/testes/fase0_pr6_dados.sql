-- Dados fictícios para comparar os indicadores antigos (TypeScript) e novos (SQL). Rode depois de recriar.sh.
\set ON_ERROR_STOP 1
insert into public.pre_cadastros (email, nome, data_entrada) values
  ('dir@t.com', 'Diretor Teste', '2025-01-10'), ('ana@t.com', 'Ana Assessora', '2025-03-01'),
  ('bruno@t.com', 'Bruno Assessor', '2026-06-01'), ('carla@t.com', 'Carla Trainee', '2026-06-01');
insert into public.pre_cadastro_diretorias (pre_cadastro_id, diretoria, cargo)
  select id, 'comercial', case when email like 'dir%' then 'diretor' when email like 'carla%' then 'trainee' else 'assessor' end::public.cargo
  from public.pre_cadastros where email like '%@t.com';
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000d', 'dir@t.com'), ('00000000-0000-0000-0000-0000000000a1', 'ana@t.com'),
  ('00000000-0000-0000-0000-0000000000b2', 'bruno@t.com'), ('00000000-0000-0000-0000-0000000000c3', 'carla@t.com');
insert into public.processos_seletivos (nome, data) values ('2026/1', '2026-05-31') on conflict do nothing;

\i supabase/dados/dados_ficticios.sql
-- Distribui os responsáveis antes de reconstruir o histórico (sem transferências depois)
update public.negocios n set responsavel_id = (array['00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b2',
  '00000000-0000-0000-0000-0000000000c3', null])[1 + (abs(hashtext(n.id::text)) % 4)]::uuid where n.ficticio;
\i supabase/dados/historico_ficticio.sql
-- Como a migração fez com os registros antigos: o responsável da época = o responsável atual (sem transferências)
update public.negocio_historico h set responsavel_id = n.responsavel_id from public.negocios n where n.id = h.negocio_id;

-- Atividades no ano (realizadas, agendadas, canceladas e uma proposta remarcada)
insert into public.atividades (tipo_id, titulo, inicio, negocio_id, responsavel_id, status)
select t.id, t.nome || ' ' || g, timestamptz '2026-01-05 10:00-03' + make_interval(days => g * 4), n.id, n.responsavel_id,
       (array['realizada', 'pendente', 'cancelada', 'confirmada', 'realizada'])[1 + g % 5]::public.status_atividade
from generate_series(1, 80) g
join public.tipos_atividade t on t.chave = (array['diagnostico', 'coldcall', 'prospectday', 'apresentacao_proposta'])[1 + g % 4]
join lateral (select id, responsavel_id from public.negocios where ficticio order by md5(id::text || g) limit 1) n on true;
update public.atividades set status = 'remarcada' where id = (select a.id from public.atividades a join public.tipos_atividade t on t.id = a.tipo_id
  where t.chave = 'apresentacao_proposta' and a.status = 'pendente' order by a.inicio limit 1);
