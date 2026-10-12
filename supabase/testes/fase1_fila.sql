-- Roteiro de teste (dados fictícios): fila de trabalhos, segredo do n8n, agentes e Caixa de aprovação.
\set ON_ERROR_STOP 1
insert into public.pre_cadastros (email, nome) values ('dir@t.com', 'Diretor Teste'), ('ass@t.com', 'Assessor Teste'), ('out@t.com', 'Outro Assessor');
insert into public.pre_cadastro_diretorias (pre_cadastro_id, diretoria, cargo)
  select id, 'comercial', case when email like 'dir%' then 'diretor' else 'assessor' end::public.cargo from public.pre_cadastros where email like '%@t.com';
insert into auth.users (id, email) values ('00000000-0000-0000-0000-00000000000d', 'dir@t.com'),
  ('00000000-0000-0000-0000-00000000000a', 'ass@t.com'), ('00000000-0000-0000-0000-00000000000b', 'out@t.com');
insert into public.empresas (id, nome) values ('10000000-0000-0000-0000-000000000001', 'Gráfica Teste');
insert into public.negocios (id, funil_id, empresa_id, titulo, fase_id, responsavel_id)
select '30000000-0000-0000-0000-000000000001', f.id, '10000000-0000-0000-0000-000000000001', 'Negócio 1',
       (select id from public.fases where chave = 'coleta'), '00000000-0000-0000-0000-00000000000a' from public.funis f where f.chave = 'comercial';
insert into privado.config (chave, valor) values ('n8n_segredo_hash', encode(extensions.digest('segredo-de-teste', 'sha256'), 'hex'));

-- Diretor: agente de teste desligado recusa; ligado, enfileira
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000d', false);
do $$ begin perform public.enviar_trabalho_teste(); raise exception 'deveria ter falhado';
exception when others then if sqlerrm like 'deveria%' then raise; end if; raise notice 'OK recusou: %', sqlerrm; end $$;
update public.agentes set ativo = true where chave = 'teste';
select public.enviar_trabalho_teste() is not null as enfileirou;
-- Assessor não envia teste nem liga agentes
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
do $$ begin perform public.enviar_trabalho_teste(); raise exception 'deveria ter falhado';
exception when others then if sqlerrm like 'deveria%' then raise; end if; raise notice 'OK recusou: %', sqlerrm; end $$;
update public.agentes set ativo = true where chave = 'enriquecedor';
select count(*) = 0 as assessor_nao_liga from public.agentes where chave = 'enriquecedor' and ativo;
do $$ begin insert into public.trabalhos (agente, tipo) values ('teste', 'x'); raise exception 'deveria ter falhado';
exception when others then if sqlerrm like 'deveria%' then raise; end if; raise notice 'OK recusou: %', sqlerrm; end $$;
reset role;

-- n8n (anon, sem sessão): segredo errado recusa; certo reserva, conclui
select id as tid from public.trabalhos where agente = 'teste' \gset
set role anon;
select set_config('request.jwt.claim.sub', '', false);
do $$ begin perform public.n8n_reservar('errado'); raise exception 'deveria ter falhado';
exception when others then if sqlerrm like 'deveria%' then raise; end if; raise notice 'OK recusou: %', sqlerrm; end $$;
select jsonb_array_length(public.n8n_reservar('segredo-de-teste', 'teste', 5) -> 'trabalhos') as reservados;
select jsonb_array_length(public.n8n_reservar('segredo-de-teste', 'teste', 5) -> 'trabalhos') as reservados_de_novo_deve_ser_0;
select public.n8n_concluir('segredo-de-teste', :'tid', '{"eco": "Olá, n8n!"}') ->> 'ok' as concluiu;
reset role;

-- Falhas: 3 tentativas e erro, com aviso aos diretores
update public.agentes set ativo = true where chave = 'enriquecedor';
select privado.enfileirar('enriquecedor', 'enriquecer_empresa', '{}', '30000000-0000-0000-0000-000000000001') is not null as enfileirou_enriquecedor;
do $$ declare i int; v uuid; begin
  for i in 1..3 loop
    update public.trabalhos set proximo_em = now() where agente = 'enriquecedor';
    v := (public.n8n_reservar('segredo-de-teste', 'enriquecedor', 1) -> 'trabalhos' -> 0 ->> 'id')::uuid;
    perform public.n8n_falhar('segredo-de-teste', v, 'Gemini', 'limite por minuto excedido');
  end loop; end $$;
select status, tentativas, erro from public.trabalhos where agente = 'enriquecedor';
select count(*) as avisos_diretor from public.notificacoes where tipo = 'agente_erro';

-- Resultado com aprovação: vai para a caixa do responsável do negócio
select privado.enfileirar('enriquecedor', 'enriquecer_empresa', '{}', '30000000-0000-0000-0000-000000000001', 'enr:2') is not null;
set role anon;
select public.n8n_concluir('segredo-de-teste', (public.n8n_reservar('segredo-de-teste', 'enriquecedor', 1) -> 'trabalhos' -> 0 ->> 'id')::uuid,
  '{"aprovacao": {"tipo": "dados_empresa", "titulo": "Confirmar decisor da Gráfica Teste", "conteudo": {"decisor": "Maria Souza", "email": "maria@grafica.com.br"}}}') ->> 'ok';
reset role;
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
select count(*) = 0 as outro_assessor_nao_ve from public.aprovacoes;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
update public.aprovacoes set conteudo = conteudo || '{"decisor": "Maria S. Souza"}', status = 'aprovada';
do $$ begin update public.aprovacoes set status = 'descartada'; raise exception 'deveria ter falhado';
exception when others then if sqlerrm like 'deveria%' then raise; end if; raise notice 'OK recusou: %', sqlerrm; end $$;
reset role;
select titulo, status, conteudo ->> 'decisor' decisor, conteudo_original ->> 'decisor' original, decidido_por is not null decidido from public.aprovacoes;
select count(*) as aviso_aprovacao from public.notificacoes where tipo = 'aprovacao';
select privado.saude_fila();
