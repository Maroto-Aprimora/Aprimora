-- Roteiro de teste (dados fictícios): tarefas pessoais, cadência, D21 → Reciclagem, Oportunidade e compromissos.
-- Rode depois de recriar.sh (independe do roteiro do PR 2 a 4).
\set ON_ERROR_STOP 1
insert into public.pre_cadastros (email, nome) values ('dir@t.com', 'Diretor Teste'), ('ass@t.com', 'Assessor Teste'), ('ass2@t.com', 'Outro Assessor');
insert into public.pre_cadastro_diretorias (pre_cadastro_id, diretoria, cargo)
  select id, 'comercial', case when email like 'dir%' then 'diretor' else 'assessor' end::public.cargo from public.pre_cadastros where email like '%@t.com';
insert into auth.users (id, email) values ('00000000-0000-0000-0000-00000000000d', 'dir@t.com'),
  ('00000000-0000-0000-0000-00000000000a', 'ass@t.com'), ('00000000-0000-0000-0000-00000000000b', 'ass2@t.com');
insert into public.empresas (id, nome) values ('10000000-0000-0000-0000-000000000001', 'Têxtil Teste');
-- Três negócios em E-mail, com D0 há 0, 7 e 25 dias (via histórico)
insert into public.negocios (id, funil_id, empresa_id, titulo, fase_id, responsavel_id)
select ('30000000-0000-0000-0000-00000000000' || i)::uuid, f.id, '10000000-0000-0000-0000-000000000001', 'Negócio ' || i,
       (select id from public.fases where chave = 'email'), '00000000-0000-0000-0000-00000000000a'
from public.funis f, generate_series(1, 3) i where f.chave = 'comercial';
update public.negocio_historico h set created_at = now() - make_interval(days => case n.titulo when 'Negócio 2' then 7 when 'Negócio 3' then 25 else 0 end)
  from public.negocios n where n.id = h.negocio_id;

-- Hoje é feriado (12/10): o job não roda. Simula um dia útil trocando "hoje".
create or replace function privado.hoje() returns date language sql stable set search_path = '' as $$ select date '2026-10-13' $$;
update public.negocio_historico h set created_at = timestamptz '2026-10-13 12:00-03' - make_interval(days => case n.titulo when 'Negócio 2' then 7 when 'Negócio 3' then 25 else 0 end)
  from public.negocios n where n.id = h.negocio_id;
select privado.gerar_tarefas_diarias() as criadas;
select privado.gerar_tarefas_diarias() as criadas_de_novo_deve_ser_0;

-- Assessor: tarefa pessoal sim; para outro membro, não
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
insert into public.tarefas (id, diretoria, titulo, origem, criado_por) values ('40000000-0000-0000-0000-000000000001', 'comercial', 'Minha tarefa', 'manual', '00000000-0000-0000-0000-00000000000a');
insert into public.tarefa_responsaveis (tarefa_id, membro_id) values ('40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a');
update public.tarefas set titulo = 'Minha tarefa (editada)' where id = '40000000-0000-0000-0000-000000000001';
do $$ begin
  insert into public.tarefa_responsaveis (tarefa_id, membro_id) values ('40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b');
  raise exception 'deveria ter falhado';
exception when others then if sqlerrm like 'deveria%' then raise; end if; raise notice 'OK recusou: %', sqlerrm; end $$;
do $$ begin
  update public.tarefas set titulo = 'x' where chave like 'cadencia:%';
  if exists (select 1 from public.tarefas where titulo = 'x') then raise exception 'deveria ter falhado'; end if;
  raise notice 'OK sem efeito em tarefa do sistema';
exception when others then if sqlerrm like 'deveria%' then raise; end if; raise notice 'OK recusou: %', sqlerrm; end $$;
-- Ligação "Interessado, sem data" leva para Oportunidade e a tarefa nasce da entrada na fase
insert into public.ligacoes (negocio_id, resultado_id) values ('30000000-0000-0000-0000-000000000002', (select id from public.resultados_ligacao where chave = 'interessado_sem_data'));
-- Diagnóstico agendado para hoje
insert into public.ligacoes (negocio_id, resultado_id, compromisso_em) values ('30000000-0000-0000-0000-000000000001', (select id from public.resultados_ligacao where chave = 'diagnostico_agendado'), '2026-10-13 15:00-03');
reset role;
select privado.gerar_tarefas_diarias() as compromissos_criados;
update public.atividades set status = 'realizada';

\echo '--- negócios'
select n.titulo, f.nome fase, n.retorno_em from public.negocios n join public.fases f on f.id = n.fase_id order by 1;
\echo '--- tarefas'
select t.titulo, t.prazo, t.status, t.origem, split_part(t.chave, ':', 1) regra, (select count(*) from public.notificacoes x where x.chave = 'tarefa_nova:' || t.id) avisos
from public.tarefas t order by t.created_at, t.titulo;
