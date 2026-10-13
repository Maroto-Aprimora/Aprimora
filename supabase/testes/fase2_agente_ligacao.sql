-- Roteiro de teste (dados fictícios): A2 Agente de ligação e A3 Avaliador pelo caminho da API4COM e da fila.
\set ON_ERROR_STOP 1
insert into public.pre_cadastros (email, nome) values ('dir@t.com', 'Diretor Teste'), ('ass@t.com', 'Assessor Teste');
insert into public.pre_cadastro_diretorias (pre_cadastro_id, diretoria, cargo)
  select id, 'comercial', case when email like 'dir%' then 'diretor' else 'assessor' end::public.cargo from public.pre_cadastros where email like '%@t.com';
insert into auth.users (id, email) values ('00000000-0000-0000-0000-00000000000d', 'dir@t.com'), ('00000000-0000-0000-0000-00000000000a', 'ass@t.com');
insert into privado.config (chave, valor) values ('n8n_segredo_hash', encode(extensions.digest('s', 'sha256'), 'hex'));
update public.agentes set ativo = true where chave in ('ligacao', 'avaliador');

-- Lead do assessor em Coldcall, com contato pelo celular
insert into public.empresas (id, nome, cidade, telefone) values ('10000000-0000-0000-0000-000000000001', 'Metalúrgica Horizonte', 'Londrina', '(43) 3333-0000');
insert into public.contatos (id, empresa_id, nome, cargo, telefone) values ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Carlos', 'Sócio', '(14) 99715-2660');
insert into public.negocios (id, funil_id, empresa_id, titulo, fase_id, responsavel_id)
select '30000000-0000-0000-0000-000000000001', f.id, '10000000-0000-0000-0000-000000000001', 'Metalúrgica Horizonte',
       (select id from public.fases where chave = 'coldcall_1'), '00000000-0000-0000-0000-00000000000a' from public.funis f where f.chave = 'comercial';
select (select nome from public.fases where id = fase_id) fase_inicial from public.negocios;

-- n8n entrega 3 chamadas: conversa de 3 min, sem atender (5 s) e número desconhecido
select public.n8n_registrar_chamadas('s', '[
 {"id":"c1","call_type":"outbound","started_at":"2026-10-13T13:00:00Z","ended_at":"2026-10-13T13:03:00Z","to":"014997152660","duration":180,"record_url":"https://x/1.mp3","email":"ass@t.com"},
 {"id":"c2","call_type":"outbound","started_at":"2026-10-13T14:00:00Z","ended_at":"2026-10-13T14:00:05Z","to":"04333330000","duration":5,"record_url":null,"hangup_cause":"NO_ANSWER","email":"ASS@t.com"},
 {"id":"c3","call_type":"outbound","started_at":"2026-10-13T15:00:00Z","ended_at":"2026-10-13T15:01:00Z","to":"011988887777","duration":60,"email":"ass@t.com"}]') as resposta;
select externo_id, processado_em is not null processado, erro from public.eventos_integracoes order by id;
select api4com_id, origem, contato_id is not null tem_contato, resultado_id is null sem_resultado from public.ligacoes order by inicio;
select agente, tipo, payload ->> 'gravacao_url' url, jsonb_array_length(payload -> 'rubrica') criterios from public.trabalhos;
select titulo, conteudo ->> 'resultado' resultado, conteudo ->> 'resumo' resumo from public.aprovacoes order by created_at;

-- Repetir a entrega não duplica
select public.n8n_registrar_chamadas('s', '[{"id":"c1","ended_at":"x"}]') ->> 'novas' as novas_na_repeticao;

-- n8n devolve transcrição, sugestão e avaliação
select public.n8n_concluir('s', (public.n8n_reservar('s', 'ligacao', 1) -> 'trabalhos' -> 0 ->> 'id')::uuid, '{
  "transcricao": "Membro: Bom dia... Lead: Podemos conversar na quinta.",
  "resumo": "O sócio aceitou um diagnóstico na quinta às 14h.",
  "resultado": "diagnostico_agendado", "compromisso_em": "2026-10-16 14:00", "proximo_passo": "Diagnóstico na fábrica",
  "dores": ["Atrasos na entrega", "Estoque sem controle"],
  "avaliacao": {"notas": [{"chave":"abertura","nota":4,"comentario":"Clara"},{"chave":"decisor","nota":3},{"chave":"inexistente","nota":2},{"chave":"escuta","nota":9}], "comentario": "Boa ligação."}}') ->> 'ok' as concluiu;
select transcricao is not null tem_transcricao, resumo from public.ligacoes where api4com_id = 'c1';
select conteudo ->> 'resultado' resultado, conteudo ->> 'compromisso_em' compromisso, conteudo ->> 'dores' dores from public.aprovacoes where trabalho_id is not null;
select jsonb_array_length(notas) criterios, media, comentario from public.avaliacoes_ligacao;

-- Assessor confirma: o resultado é aplicado (fase, agenda, tarefas), as dores vão para o negócio
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
update public.aprovacoes set status = 'aprovada' where trabalho_id is not null;
-- "Não atendeu" sem conversa também é confirmado
update public.aprovacoes set status = 'aprovada' where trabalho_id is null;
select count(*) as avaliacoes_que_o_assessor_ve from public.avaliacoes_ligacao;
reset role;
select (select nome from public.fases where id = fase_id) fase_final, dores_identificadas from public.negocios;
select l.api4com_id, r.nome, l.resultado_aplicado_em is not null aplicado from public.ligacoes l join public.resultados_ligacao r on r.id = l.resultado_id order by l.inicio;
select count(*) as compromissos from public.atividades;

-- Resultado que exige data sem a data: a aprovação é recusada
insert into public.ligacoes (negocio_id, membro_id, origem, api4com_id) values ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', 'agente', 'c9') returning id \gset
select privado.aprovacao_resultado_ligacao(:'id', null, '{"resultado":"decisor_indisponivel"}') is not null as criou;
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
do $$ begin update public.aprovacoes set status = 'aprovada' where status = 'pendente'; raise exception 'deveria ter falhado';
exception when others then if sqlerrm like 'deveria%' then raise; end if; raise notice 'OK recusou: %', sqlerrm; end $$;
reset role;

-- Falha 3 vezes: o membro confirma sem a sugestão
select public.n8n_registrar_chamadas('s', '[{"id":"c4","call_type":"outbound","started_at":"2026-10-13T16:00:00Z","ended_at":"2026-10-13T16:02:00Z","to":"(14) 99715-2660","duration":120,"record_url":"https://x/4.mp3","email":"ass@t.com"}]') ->> 'ligacoes' as nova_ligacao;
update public.trabalhos set max_tentativas = 1 where agente = 'ligacao' and status = 'pendente';
select public.n8n_falhar('s', (public.n8n_reservar('s', 'ligacao', 1) -> 'trabalhos' -> 0 ->> 'id')::uuid, 'gemini', 'arquivo grande') ->> 'status' as status;
select conteudo ->> 'resumo' from public.aprovacoes a join public.ligacoes l on l.id = a.ligacao_id where l.api4com_id = 'c4';
