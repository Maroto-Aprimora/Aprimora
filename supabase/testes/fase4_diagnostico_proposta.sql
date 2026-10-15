-- Roteiro de teste (dados fictícios): Fase 4 · diagnóstico, A9, precificação e passagem para Projetos
\set ON_ERROR_STOP 1
insert into public.pre_cadastros (email, nome) values ('dir@t.com', 'Diretor Teste'), ('ass@t.com', 'Assessor Teste');
insert into public.pre_cadastro_diretorias (pre_cadastro_id, diretoria, cargo)
  select id, 'comercial', case when email like 'dir%' then 'diretor' else 'assessor' end::public.cargo from public.pre_cadastros where email like '%@t.com';
insert into auth.users (id, email) values ('00000000-0000-0000-0000-00000000000d', 'dir@t.com'), ('00000000-0000-0000-0000-00000000000a', 'ass@t.com');
insert into privado.config (chave, valor) values ('n8n_segredo_hash', encode(extensions.digest('s', 'sha256'), 'hex'));
update public.agentes set ativo = true where chave in ('assistente_proposta', 'passagem');
create function privado.t_reservar(_id uuid) returns uuid language sql as $$
  update public.trabalhos set status = 'processando', reservado_em = now(), tentativas = tentativas + 1 where id = _id returning id $$;

insert into public.empresas (id, nome, cidade) values ('10000000-0000-0000-0000-000000000001', 'Metalúrgica Horizonte', 'Londrina');
insert into public.negocios (id, funil_id, empresa_id, titulo, fase_id, responsavel_id)
select '30000000-0000-0000-0000-000000000001', f.id, '10000000-0000-0000-0000-000000000001', 'Metalúrgica Horizonte',
       (select id from public.fases where chave = 'diagnostico'), '00000000-0000-0000-0000-00000000000a' from public.funis f where f.chave = 'comercial';
select count(*) areas, (select count(*) from public.diagnostico_perguntas) perguntas, count(servico_id) com_servico from public.diagnostico_areas;

-- Assessor aplica o diagnóstico
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
insert into public.diagnosticos (negocio_id) values ('30000000-0000-0000-0000-000000000001') returning id as did \gset
update public.diagnosticos set respostas = (
  select jsonb_object_agg(p.id, jsonb_build_object('nota', case a.chave when 'estoque' then 1 when 'pcp' then 2 else 3 end, 'comentario', 'ok'))
  from public.diagnostico_perguntas p join public.diagnostico_areas a on a.id = p.area_id where a.chave in ('estoque', 'pcp', '5s')) where id = :'did';
do $$ begin update public.diagnosticos set status = 'concluido'; raise exception 'deveria ter falhado';
exception when others then if sqlerrm like 'deveria%' then raise; end if; raise notice 'OK recusou: %', sqlerrm; end $$;
reset role;
-- Sem nenhuma resposta não conclui
insert into public.diagnosticos (negocio_id) values ('30000000-0000-0000-0000-000000000001') returning id as vazio \gset
do $$ begin perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false); end $$;
set role authenticated;
do $$ begin perform public.concluir_diagnostico((select id from public.diagnosticos where respostas = '{}' limit 1)); raise exception 'deveria ter falhado';
exception when others then if sqlerrm like 'deveria%' then raise; end if; raise notice 'OK recusou: %', sqlerrm; end $$;
select public.concluir_diagnostico(:'did') concluiu;
reset role;
select status, analise_status, (select string_agg((m ->> 'nome') || '=' || coalesce(m ->> 'media', '-'), ', ') from jsonb_array_elements(maturidade) m where (m ->> 'respondidas')::int > 0) mapa
from public.diagnosticos where id = :'did';
select agente, tipo, jsonb_array_length(payload -> 'respostas') respostas from public.trabalhos;

-- n8n devolve o A9: proposta em rascunho, aviso ao responsável
select public.n8n_concluir('s', privado.t_reservar(id), jsonb_build_object(
  'resumo', 'Estoque sem controle e PCP informal.',
  'servicos_sugeridos', jsonb_build_array(jsonb_build_object('nome', 'Gestão de Estoque', 'motivo', 'nota 1'), jsonb_build_object('nome', 'Inexistente', 'motivo', 'x')),
  'escopo', 'Fase 1: inventário...', 'proposta', 'Prezado...')) ->> 'ok'
from public.trabalhos where agente = 'assistente_proposta';
select status, resumo_diagnostico, jsonb_array_length(servicos_sugeridos) sugeridos, escopo from public.propostas;
select analise_status from public.diagnosticos where id = :'did';
select tipo, titulo from public.notificacoes where tipo = 'proposta_pronta';

-- Precificação: o banco calcula; o assessor não registra preço final; o diretor sim, e vira o valor do negócio
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
insert into public.precificacoes (negocio_id, fatores, horas_consultor, horas_gerente, custos)
values ('30000000-0000-0000-0000-000000000001', '{"prazo":"Curto","porte":"Média"}', 100, 20, '[{"descricao":"Deslocamento","valor":300}]');
select multiplicador, custo_base, preco_minimo, preco_maximo from public.precificacoes;
do $$ begin update public.precificacoes set preco_final = 9000; raise exception 'deveria ter falhado';
exception when others then if sqlerrm like 'deveria%' then raise; end if; raise notice 'OK recusou: %', sqlerrm; end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000d', false);
update public.precificacoes set preco_final = 9000;
reset role;
select valor from public.negocios;

-- Passagem para Projetos ao ganhar: tarefa para o diretor (não há diretor de Projetos) e aviso ao responsável
update public.negocios set campos = (select jsonb_object_agg(chave, '2026-10-15') from public.fase_campos where obrigatorio);
update public.negocios set fase_id = (select id from public.fases where chave = 'ganho');
select t.titulo, t.prioridade, m.email from public.tarefas t join public.tarefa_responsaveis r on r.tarefa_id = t.id join public.membros m on m.id = r.membro_id where t.chave like 'passagem:%';
select tipo, titulo from public.notificacoes where tipo = 'passagem';
drop function privado.t_reservar(uuid);
