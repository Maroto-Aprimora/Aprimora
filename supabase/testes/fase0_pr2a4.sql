-- Roteiro de teste (dados fictícios): resultados de ligação, motivos e remarcação/valor por serviço.
-- Rode depois de recriar.sh. Cada recusa esperada aparece como "OK recusou".
\set ON_ERROR_STOP 1
-- Membros de teste: diretor e assessor do Comercial
insert into public.pre_cadastros (email, nome) values ('dir@t.com', 'Diretor Teste'), ('ass@t.com', 'Assessor Teste');
insert into public.pre_cadastro_diretorias (pre_cadastro_id, diretoria, cargo)
  select id, 'comercial', case when email like 'dir%' then 'diretor' else 'assessor' end::public.cargo from public.pre_cadastros where email like '%@t.com';
insert into auth.users (id, email) values ('00000000-0000-0000-0000-00000000000d', 'dir@t.com'), ('00000000-0000-0000-0000-00000000000a', 'ass@t.com');
update public.membro_diretorias set participa_rodizio = true where membro_id = '00000000-0000-0000-0000-00000000000a';
insert into public.empresas (id, nome, telefone) values ('10000000-0000-0000-0000-000000000001', 'Metalúrgica Teste', '43 3333-0000');
insert into public.contatos (id, empresa_id, nome, telefone, decisor) values ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Carlos', '43 9999-0000', true);
insert into public.negocios (id, funil_id, empresa_id, contato_id, titulo, fase_id, responsavel_id)
select ('30000000-0000-0000-0000-00000000000' || i)::uuid, f.id, '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'Negócio ' || i,
       (select id from public.fases where chave = 'coldcall_1'), '00000000-0000-0000-0000-00000000000a'
from public.funis f, generate_series(1, 6) i where f.chave = 'comercial';

-- Age como o assessor
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
create function pg_temp.res(c text) returns uuid language sql as $$ select id from public.resultados_ligacao where chave = c $$;

-- 1 Não atendeu: fica na fase, tarefa em 7 dias úteis
insert into public.ligacoes (negocio_id, contato_id, resultado_id, duracao_seg) values ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', pg_temp.res('nao_atendeu'), 20);
-- 2 Decisor indisponível sem data: deve falhar
do $$ begin
  insert into public.ligacoes (negocio_id, resultado_id) values ('30000000-0000-0000-0000-000000000002', pg_temp.res('decisor_indisponivel'));
  raise exception 'deveria ter falhado';
exception when others then if sqlerrm like 'deveria%' then raise; end if; raise notice 'OK recusou: %', sqlerrm; end $$;
insert into public.ligacoes (negocio_id, resultado_id, retorno_em) values ('30000000-0000-0000-0000-000000000002', pg_temp.res('decisor_indisponivel'), '2026-10-17');
-- 3 Sem interesse: vai para Lead não qualificado com motivo
insert into public.ligacoes (negocio_id, resultado_id) values ('30000000-0000-0000-0000-000000000003', pg_temp.res('sem_interesse'));
-- 4 Interessado sem data: Oportunidade + follow-up
insert into public.ligacoes (negocio_id, resultado_id) values ('30000000-0000-0000-0000-000000000004', pg_temp.res('interessado_sem_data'));
-- 5 Diagnóstico agendado: fase, agenda, briefing na véspera
insert into public.ligacoes (negocio_id, resultado_id, compromisso_em) values ('30000000-0000-0000-0000-000000000005', pg_temp.res('diagnostico_agendado'), '2026-10-20 14:00-03');
-- 6 Número errado: telefone inválido no contato
insert into public.ligacoes (negocio_id, contato_id, resultado_id) values ('30000000-0000-0000-0000-000000000006', '20000000-0000-0000-0000-000000000001', pg_temp.res('numero_errado'));
-- Nova ligação no negócio 1 conclui a tarefa anterior
insert into public.ligacoes (negocio_id, resultado_id, decisor_nome, decisor_melhor_horario) values ('30000000-0000-0000-0000-000000000001', pg_temp.res('barrado_secretaria'), 'Ana', 'manhã');
-- Trocar resultado já aplicado: deve falhar
do $$ begin
  update public.ligacoes set resultado_id = pg_temp.res('caixa_postal') where negocio_id = '30000000-0000-0000-0000-000000000003';
  raise exception 'deveria ter falhado';
exception when others then if sqlerrm like 'deveria%' then raise; end if; raise notice 'OK recusou: %', sqlerrm; end $$;

-- PR 3: "Outro" sem comentário falha; "Pediu para não ser contatado" marca o contato
do $$ begin
  perform public.mover_negocio('30000000-0000-0000-0000-000000000002', (select id from public.fases where chave='nao_qualificado'),
    (select id from public.motivos where chave='outro' and tipo='desqualificacao'));
  raise exception 'deveria ter falhado';
exception when others then if sqlerrm like 'deveria%' then raise; end if; raise notice 'OK recusou: %', sqlerrm; end $$;
select public.mover_negocio('30000000-0000-0000-0000-000000000006', (select id from public.fases where chave='nao_qualificado'),
    (select id from public.motivos where chave='nao_contatar'));

-- PR 4: valor por serviço e remarcação
insert into public.negocio_servicos (negocio_id, servico_id, valor) select '30000000-0000-0000-0000-000000000005', id, 1500 from public.servicos where ordem in (1, 2);
select public.remarcar_atividade((select id from public.atividades where negocio_id = '30000000-0000-0000-0000-000000000005'), '2026-10-22 10:00-03');
reset role;

\echo '--- negócios'
select n.titulo, f.nome fase, m.nome motivo, n.retorno_em, n.valor, n.campos->>'data_marcada' data_marcada from public.negocios n join public.fases f on f.id=n.fase_id left join public.motivos m on m.id=n.motivo_id order by 1;
\echo '--- tarefas'
select t.titulo, t.prazo, t.status, t.origem, (select count(*) from public.tarefa_responsaveis r where r.tarefa_id=t.id) resp from public.tarefas t order by t.created_at;
\echo '--- atividades'
select titulo, inicio at time zone 'America/Sao_Paulo', status, remarcada_de_id is not null nova from public.atividades order by inicio;
\echo '--- contato / notificações / push'
select nome, telefone_invalido, nao_contatar from public.contatos;
select tipo, titulo, mensagem from public.notificacoes where tipo = 'tarefa_nova' order by created_at;
